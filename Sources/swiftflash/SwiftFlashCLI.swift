import Foundation
import SwiftFlashCore

@main
struct SwiftFlashCLI {
    static func main() async {
        let services: Services
        do {
            let configStore = try AppConfigStore()
            services = Services(
                imageStore: ImageCatalogStore(configStore: configStore),
                deviceStore: DeviceInventoryStore(configStore: configStore),
                historyStore: FlashHistoryStore(configStore: configStore),
                scanner: DeviceScanner(),
                deviceManager: DiskArbitrationManager(),
                prompt: PromptRenderer(),
                uuidService: UUIDMetadataService(),
                imagePreparer: ImagePreparer(trashStore: TrashedDownloadStore(configStore: configStore)),
                sourceStore: ImageSourceStore(configStore: configStore),
                sourceBrowser: ImageSourceBrowser(),
                settingsStore: SettingsStore(configStore: configStore)
            )
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }

        do {
            let command = try CLIParser.parse(arguments: CommandLine.arguments)
            try await execute(command: command, services: services, interactive: false)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    /// `interactive` is true for commands typed in the interactive shell.
    private static func execute(command: FlashCommand, services: Services, interactive: Bool) async throws {
        switch command {
            case .repl:
                try await runREPL(services: services)

            case .flash(let imagePath, let devicePath, let skipConfirmation, let verifyFlag, let modelFlag):
                guard geteuid() == 0 else {
                    throw FlashError.requiresRoot
                }

                // Check for a medium before downloading anything, then prepare the image (download, unpack)
                // in the background while the device is chosen and the erase is confirmed.
                let location = try await selectImage(path: imagePath, modelFlag: modelFlag, services: services)
                try waitForMedium(devicePath: devicePath, mayWait: !skipConfirmation, services: services)
                let progress = PreparationProgress(muted: true)
                if location.needsPreparation {
                    print("Preparing the image in the background…")
                }
                let preparer = services.imagePreparer
                let preparation = Task {
                    try await prepare(location, progress: progress, preparer: preparer)
                }
                let device: DiskCandidate
                do {
                    device = try resolveDevice(path: devicePath, services: services)
                    if !skipConfirmation && !services.prompt.confirmFlash(
                        imageLabel: location.label,
                        imageSize: location.knownSize,
                        device: device,
                        overview: overview(of: device, services: services)
                    ) {
                        throw FlashError.cancelled
                    }
                } catch {
                    preparation.cancel()
                    if let prepared = try? await preparation.value {
                        cleanup(prepared, services: services)
                    }
                    throw error
                }
                progress.unmute()
                let prepared = try await preparation.value
                defer { cleanup(prepared, services: services) }
                reportPreparation(prepared, progress: progress)
                let image = prepared.image

                print("Flashing \(image.name) to \(device.displayName) (\(device.devicePath))")
                let writeProgress = ConsoleProgressRenderer(label: "Flash", totalBytes: image.size)
                let verifyProgress = ConsoleProgressRenderer(label: "Verify", totalBytes: image.size)
                let prompt = services.prompt
                let verifyMode = services.settingsStore.settings.verifyMode(
                    interactive: interactive,
                    flag: verifyFlag,
                    skipConfirmation: skipConfirmation
                )
                let completion = try await services.flashService.flash(
                    image: image,
                    device: device,
                    writeProgress: { progress in
                        writeProgress.update(progress: progress)
                    },
                    promptForVerification: {
                        writeProgress.finish(status: "Flash write complete")
                        switch verifyMode {
                        case .ask: return prompt.confirmVerifyAfterFlash()
                        case .always: return true
                        case .never: return false
                        }
                    },
                    verifyProgress: { progress in
                        verifyProgress.update(progress: progress)
                    }
                )
                writeProgress.finish(status: "Flash write complete")
                verifyProgress.finishIfStarted(status: "Verification complete")
                if verifyMode == .never {
                    print("Not verified (add -v to verify)")
                }
                let deviceUUIDAction = completion.previousIdentity == nil ? "created and written" : "reused and written"
                print("Device UUID \(deviceUUIDAction): \(completion.metadata.deviceUUID)")
                if let flashUUID = completion.metadata.flashUUID {
                    print("Flash UUID written: \(flashUUID.uuidString)")
                }
                if let imageLabel = completion.metadata.image?.displayLabel {
                    print("Image identity kept: \(imageLabel)")
                }
                print("Metadata stored in: \(completion.writeResult.storageDescription)")
                print("Flash completed")
                await unmountForRemoval(device, services: services)

            case .verify(let imagePath, let devicePath):
                guard geteuid() == 0 else {
                    throw FlashError.requiresRoot
                }

                try waitForMedium(devicePath: devicePath, mayWait: true, services: services)
                let location = try await selectImage(path: imagePath, modelFlag: nil, services: services)
                let progress = PreparationProgress(muted: false)
                let prepared = try await prepare(location, progress: progress, preparer: services.imagePreparer)
                reportPreparation(prepared, progress: progress)
                defer { cleanup(prepared, services: services) }
                let image = prepared.image
                let device = try resolveDevice(path: devicePath, services: services)
                let verifyProgress = ConsoleProgressRenderer(label: "Verify", totalBytes: image.size)
                print("Verifying \(image.name) against \(device.displayName) (\(device.devicePath))")
                try await services.flashService.verify(
                    image: image,
                    device: device,
                    progress: { progress in
                        verifyProgress.update(progress: progress)
                    }
                )
                verifyProgress.finish(status: "Verification complete")
                print("Verification successful")
                await unmountForRemoval(device, services: services)

            case .images:
                let images = services.imageStore.allImages()
                if images.isEmpty {
                    print("No remembered images")
                } else {
                    for image in images {
                        print("\(image.displayName)\t\(image.path)")
                    }
                }

            case .imagesClear:
                try services.imageStore.clear()
                print("Cleared remembered images")

            case .imagesRemove(let query):
                let removed = try services.imageStore.remove(matching: query)
                guard removed > 0 else {
                    throw FlashError.usage("No remembered image found for: \(query)")
                }
                print(removed == 1 ? "Removed remembered image" : "Removed \(removed) remembered images")

            case .mediaList:
                try listConnectedMedia(
                    scanner: services.scanner,
                    uuidService: services.uuidService,
                    deviceStore: services.deviceStore,
                    identifyNewMedia: false
                )

            case .mediaKnown:
                let media = services.deviceStore.allDevices()
                if media.isEmpty {
                    print("No remembered media")
                } else {
                    for medium in media {
                        let mediaType = medium.mediaTypeName ?? "-"
                        print("\(medium.displayName)\t\(medium.deviceUUID)\t\(mediaType)")
                    }
                }

            case .mediaInfo(let query):
                try showMediaInfo(
                    query: query,
                    scanner: services.scanner,
                    uuidService: services.uuidService,
                    deviceStore: services.deviceStore
                )

            case .mediaIdentify:
                try listConnectedMedia(
                    scanner: services.scanner,
                    uuidService: services.uuidService,
                    deviceStore: services.deviceStore,
                    identifyNewMedia: true
                )

            case .mediaShow(let devicePath):
                try await showMedia(devicePath: devicePath, services: services)

            case .mediaTypes:
                let mediaTypes = services.deviceStore.allMediaTypes()
                if mediaTypes.isEmpty {
                    print("No configured media types")
                } else {
                    for mediaType in mediaTypes {
                        let source = mediaType.isPreconfigured ? "preconfigured" : "custom"
                        print("\(mediaType.name)\t\(source)")
                    }
                }

            case .mediaTypeAdd(let name):
                try services.deviceStore.addMediaType(name: name)
                print("Added media type")

            case .mediaSetType(let id, let typeName):
                try services.deviceStore.setMediaType(id: id, mediaTypeName: typeName)
                print("Updated media type")

            case .mediaClearType(let id):
                try services.deviceStore.setMediaType(id: id, mediaTypeName: nil)
                print("Cleared media type")

            case .mediaName(let id, let name):
                try services.deviceStore.setCustomName(id: id, name: name)
                print("Updated media name")

            case .mediaClearName(let id):
                try services.deviceStore.setCustomName(id: id, name: nil)
                print("Cleared media name")

            case .history:
                let history = services.historyStore.allHistory()
                if history.isEmpty {
                    print("No flash history")
                } else {
                    for entry in history {
                        let imageLabel = entry.image?.displayLabel ?? "-"
                        print("\(entry.finishedAt.ISO8601Format())\t\(entry.imageName)\t\(imageLabel)\t\(entry.deviceUUID)\t\(entry.result)")
                    }
                }

            case .historyClear:
                try services.historyStore.clear()
                print("Cleared flash history")

            case .version:
                print("swiftflash \(SwiftFlashVersion.current)")

            case .sourceList:
                let sources = services.sourceStore.allSources()
                if sources.isEmpty {
                    print("No image sources. Add one with: swiftflash source add <name> <url>")
                } else {
                    for source in sources {
                        let builtIn = services.sourceStore.isBuiltIn(source) ? "  (built-in)" : ""
                        print("\(source.name)\t\(source.url)\(builtIn)")
                    }
                }

            case .sourceAdd(let name, let url):
                try services.sourceStore.add(ImageSource(name: name, url: url))
                print("Added source \(name). Flash the newest build with: sudo swiftflash \(name):<family>")

            case .sourceRemove(let name):
                guard try services.sourceStore.remove(named: name) else {
                    if let source = services.sourceStore.source(named: name), services.sourceStore.isBuiltIn(source) {
                        throw FlashError.usage("\(name) is built in and cannot be removed")
                    }
                    throw FlashError.usage("No source named \(name)")
                }
                print("Removed source \(name)")

            case .sourceBrowse(let name, let familyQuery, let modelFlag):
                guard let source = services.sourceStore.source(named: name) else {
                    throw FlashError.usage("No source named \(name)")
                }
                let listing = try await sourceListing(source, modelFlag: modelFlag, services: services)
                if let familyQuery {
                    let family = try listing.family(matching: familyQuery)
                    print("\(family.name):")
                    for build in family.builds {
                        print("  \(PromptRenderer.buildLine(build))")
                    }
                } else if listing.families.isEmpty {
                    print("No images found at \(source.url)")
                } else if let list = listing.list {
                    var category: String?
                    for family in listing.families {
                        if let next = family.newest.category, next != category {
                            category = next
                            print("\n\(next):")
                        }
                        print("  " + PromptRenderer.familyLine(family, boards: list.modelSlugs(for: family.newest)))
                    }
                    print("")
                    if let model = listing.model {
                        print("Showing images for \(model.name) (\(model.slug)). Change with `settings rpi-model` or --model.")
                    } else {
                        print("All models. Filter with `settings rpi-model pi5` (interactive shell) or --model pi5.")
                    }
                    if list.unsupportedCount > 0 {
                        print("\(list.unsupportedCount) images in other formats (.bz2, .zst) are not listed.")
                    }
                } else {
                    for family in listing.families {
                        print(PromptRenderer.familyLine(family))
                    }
                }

            case .settings:
                let settings = services.settingsStore.settings
                print("verify          \(settings.verifyInteractive.rawValue)\t(flash in the interactive shell)")
                print("verify-console  \(settings.verifyConsole.rawValue)\t(swiftflash … without -v / --no-verify)")
                print("rpi-model       \(settings.rpiModel ?? "any")\t(Raspberry Pi board for the rpi image list)")

            case .settingsSet(let key, let value):
                try services.settingsStore.set(key, value: value)
                print("\(key.rawValue) = \(value ?? "any")")

            case .help:
                print(HelpRenderer.text)
        }
    }

    private static func runREPL(services: Services) async throws {
        print("SwiftFlash interactive shell")
        print("Type `help` for commands. Type `exit`, `quit`, or `quite` to leave.")

        while true {
            print("swiftflash> ", terminator: "")
            fflush(stdout)

            guard let line = readLine(strippingNewline: true) else {
                print("")
                break
            }

            do {
                switch try CLIParser.parseInteractive(line: line) {
                case .empty:
                    continue
                case .exit:
                    return
                case .command(let command):
                    try await execute(command: command, services: services, interactive: true)
                }
            } catch {
                fputs("\(error.localizedDescription)\n", stderr)
            }
        }
    }

    /// The chosen image before it is prepared: a local path or URL, plus the list entry for `source:` references.
    private struct ImageLocation: Sendable {
        var source: String
        var remote: RemoteImage?

        var label: String {
            remote.map(PromptRenderer.buildLine) ?? source
        }

        /// True if the image must be downloaded or unpacked first.
        var needsPreparation: Bool {
            ImagePreparer.isRemote(source) || ImageSupport.isCompressed(URL(fileURLWithPath: source))
        }

        /// The size of a local, uncompressed image; nil while it is still unknown.
        var knownSize: Int64? {
            guard !needsPreparation,
                  let size = try? FileManager.default.attributesOfItem(atPath: source)[.size] as? NSNumber
            else {
                return nil
            }
            return size.int64Value
        }
    }

    private static func selectImage(path: String?, modelFlag: String?, services: Services) async throws -> ImageLocation {
        let selected = try path ?? services.prompt.selectImage(
            from: services.imageStore.allImages(),
            sources: services.sourceStore.allSources()
        )
        let (resolvedPath, remote) = try await resolveSourceReference(selected, modelFlag: modelFlag, services: services)
        return ImageLocation(source: resolvedPath, remote: remote)
    }

    /// Fails fast (or waits for the user to insert one) when no eligible medium is connected, so nothing is
    /// downloaded for nothing.
    private static func waitForMedium(devicePath: String?, mayWait: Bool, services: Services) throws {
        let canWait = mayWait && isatty(STDIN_FILENO) == 1
        while true {
            let found = try devicePath.map { try services.scanner.findEligibleDevice(at: $0) != nil }
                ?? !services.scanner.scanEligibleDevices().isEmpty
            if found {
                return
            }
            let message = devicePath.map { "\($0) is not an eligible medium" } ?? "No SD card or USB stick found"
            guard canWait, services.prompt.waitForMedium(message) else {
                throw devicePath.map { FlashError.deviceNotFound($0) } ?? FlashError.noEligibleDevices
            }
        }
    }

    private static func prepare(
        _ location: ImageLocation,
        progress: PreparationProgress,
        preparer: ImagePreparer
    ) async throws -> PreparedImage {
        try await preparer.prepare(
            source: location.source,
            expectedImageSHA256: location.remote?.imageSHA256
        ) { update in
            progress.update(update)
        }
    }

    private static func reportPreparation(_ prepared: PreparedImage, progress: PreparationProgress) {
        progress.finish()
        if prepared.checksumVerified {
            print("Checksum verified (SHA-256 from .sha256)")
        }
        if prepared.imageChecksumVerified {
            print("Unpacked image verified (SHA-256 from the image list)")
        }
        if let reuse = prepared.trashReuse {
            let downloadedAt = reuse.download.downloadedAt.formatted(date: .abbreviated, time: .shortened)
            if reuse.verifiedWithServer {
                print("Using unchanged download from Trash (downloaded \(downloadedAt))")
            } else {
                print("Server not reachable, using download from Trash (downloaded \(downloadedAt))")
            }
        }
    }

    /// Turns `source:family` into the URL of the newest build, or lets the user browse for `source:`.
    /// Anything that is not a source reference is returned unchanged.
    private static func resolveSourceReference(
        _ text: String,
        modelFlag: String?,
        services: Services
    ) async throws -> (String, RemoteImage?) {
        guard let reference = ImageSourceReference.parse(text, sources: services.sourceStore.allSources()),
              let source = services.sourceStore.source(named: reference.sourceName)
        else {
            return (text, nil)
        }
        print("Reading images from \(source.url)…")
        let listing = try await sourceListing(source, modelFlag: modelFlag, services: services)
        guard !listing.families.isEmpty else {
            throw FlashError.usage("No images found at \(source.url)")
        }

        let image: RemoteImage
        if reference.family.isEmpty {
            let family = try services.prompt.selectFamily(listing.families, source: source) { image in
                listing.list?.modelSlugs(for: image) ?? []
            }
            image = try services.prompt.selectBuild(of: family)
        } else if let exact = listing.families.flatMap(\.builds).first(where: { $0.fileName == reference.family }) {
            image = exact
        } else {
            image = try listing.family(matching: reference.family).newest
        }
        print("\(text) → \(PromptRenderer.buildLine(image))")
        return (image.url.absoluteString, image)
    }

    /// The families of a source; for a Raspberry Pi Imager list only those for the chosen model.
    private struct SourceListing {
        var families: [RemoteImageFamily]
        var list: RaspberryPiImageList?
        var model: RaspberryPiModel?
        /// All families before filtering by model, to explain why a query does not match.
        var unfiltered: [RemoteImageFamily]

        func family(matching query: String) throws -> RemoteImageFamily {
            do {
                return try RemoteImageNaming.family(matching: query, in: families)
            } catch {
                if let model, (try? RemoteImageNaming.family(matching: query, in: unfiltered)) != nil {
                    throw FlashError.usage("'\(query)' is not listed for \(model.name); use --model any to flash it anyway")
                }
                throw error
            }
        }
    }

    private static func sourceListing(_ source: ImageSource, modelFlag: String?, services: Services) async throws -> SourceListing {
        guard let list = try await services.sourceBrowser.raspberryPiList(in: source) else {
            let families = try await services.sourceBrowser.families(in: source)
            return SourceListing(families: families, unfiltered: families)
        }
        let all = RemoteImageNaming.families(from: list.images)
        guard let slug = services.settingsStore.settings.rpiModel(flag: modelFlag) else {
            return SourceListing(families: all, list: list, unfiltered: all)
        }
        let model = try list.model(named: slug)
        let families = RemoteImageNaming.families(from: list.images.filter(model.supports))
        return SourceListing(families: families, list: list, model: model, unfiltered: all)
    }

    /// Unmounts all partitions so the medium can be pulled out safely. A failure only produces a warning.
    private static func unmountForRemoval(_ device: DiskCandidate, services: Services) async {
        do {
            try await services.deviceManager.unmountWholeDisk(device)
            print("Unmounted \(device.devicePath), the medium can be removed")
        } catch {
            print("Warning: could not unmount \(device.devicePath) (\(error.localizedDescription)); eject it in Finder before removing it")
        }
    }

    private static func cleanup(_ prepared: PreparedImage, services: Services) {
        switch services.imagePreparer.finish(prepared) {
        case .nothingToDo:
            break
        case .removedTemporaryFiles:
            print("Removed temporary image files")
        case .movedDownloadToTrash(let url):
            print("Moved downloaded image to Trash for reuse: \(url.path)")
        case .trashFailed(let reason):
            print("Removed temporary image files (could not move download to Trash: \(reason))")
        }
    }

    /// Shows one progress bar per preparation step (download, unpack) with the bytes downloaded or unpacked so far.
    /// Download / unpack progress. While muted (prompts are shown), updates are only remembered and the
    /// latest one is drawn on `unmute()`.
    private final class PreparationProgress: @unchecked Sendable {
        private let lock = NSLock()
        private var step: ImagePreparationStep?
        private var renderer: ConsoleProgressRenderer?
        private var muted: Bool
        private var latest: ImagePreparationProgress?
        private var finished = false

        init(muted: Bool) {
            self.muted = muted
        }

        func unmute() {
            lock.lock()
            defer { lock.unlock() }
            muted = false
            if let latest, !finished {
                renderLocked(latest)
            }
        }

        func update(_ update: ImagePreparationProgress) {
            lock.lock()
            defer { lock.unlock() }
            latest = update
            if !muted && !finished {
                renderLocked(update)
            }
        }

        private func renderLocked(_ update: ImagePreparationProgress) {
            if update.step != step {
                finishLocked()
                step = update.step
                let label = update.step == .download ? "Download" : "Unpack"
                renderer = ConsoleProgressRenderer(label: label, totalBytes: 0)
            }
            renderer?.update(progress: update.fraction, processedBytes: update.processedBytes)
        }

        func finish() {
            lock.lock()
            defer { lock.unlock() }
            finishLocked()
            finished = true
        }

        private func finishLocked() {
            switch step {
            case .download:
                renderer?.finish(status: "Download complete")
            case .decompress:
                renderer?.finish(status: "Unpack complete")
            case nil:
                break
            }
            renderer = nil
        }
    }

    private static func resolveDevice(path: String?, services: Services) throws -> DiskCandidate {
        if let path {
            if let device = try services.scanner.findEligibleDevice(at: path) {
                return device
            }
            throw FlashError.deviceNotFound(path)
        }
        let devices = try services.scanner.scanEligibleDevices()
        return try services.prompt.selectDevice(from: devices) { device in
            overview(of: device, services: services)
        }
    }

    /// `swiftflash id`: shows what is on the connected media without downloading or writing anything.
    /// Media that are not mounted (e.g. right after flashing) are mounted for reading and unmounted again.
    private static func showMedia(devicePath: String?, services: Services) async throws {
        let devices: [DiskCandidate]
        if let devicePath {
            guard let device = try services.scanner.findEligibleDevice(at: devicePath) else {
                throw FlashError.deviceNotFound(devicePath)
            }
            devices = [device]
        } else {
            devices = try services.scanner.scanEligibleDevices()
        }
        guard !devices.isEmpty else {
            print("No connected eligible flash media")
            return
        }

        for (index, scanned) in devices.enumerated() {
            if index > 0 {
                print("")
            }
            let (device, mountedForReading) = await mountForReading(scanned, services: services)
            let info = overview(of: device, services: services)
            print("\(info.title) (\(device.devicePath), \(device.formattedSize))")
            for line in info.details {
                print("  \(line)")
            }
            let status = services.uuidService.resolveIdentityStatus(for: device)
            let imageIdentity = services.uuidService.readImageIdentity(from: device.partitions)
            for line in DeviceOverview.imageDetails(metadata: status.resolvedIdentity?.metadata, imageIdentity: imageIdentity) {
                print("  \(line)")
            }
            if let deviceUUID = status.resolvedIdentity?.metadata.deviceUUID {
                for line in DeviceOverview.historyLines(services.historyStore.allHistory(), deviceUUID: deviceUUID) {
                    print("  \(line)")
                }
            }
            if !device.partitions.contains(where: { $0.mountPoint != nil }) {
                print("  No mountable filesystem, so /.uuid could not be read")
            }
            if mountedForReading {
                try? await services.deviceManager.unmountWholeDisk(device)
            }
        }
    }

    /// Mounts the partitions of a fully unmounted medium so `/.uuid` can be read. Returns the rescanned
    /// device and whether it was mounted here (and should be unmounted again afterwards).
    private static func mountForReading(_ device: DiskCandidate, services: Services) async -> (DiskCandidate, Bool) {
        let mountable = device.partitions.filter(\.isMountable)
        guard !mountable.isEmpty, !device.partitions.contains(where: { $0.mountPoint != nil }) else {
            return (device, false)
        }
        for partition in mountable {
            try? await services.deviceManager.mountPartition(partition.bsdName)
        }
        for _ in 0..<5 {
            if let rescanned = try? services.scanner.findEligibleDevice(at: device.devicePath),
               rescanned.partitions.contains(where: { $0.mountPoint != nil }) {
                return (rescanned, true)
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return (device, true)
    }

    /// Describes a target medium: remembered name and type, and the image currently on it.
    private static func overview(of device: DiskCandidate, services: Services) -> DeviceOverview {
        let status = services.uuidService.resolveIdentityStatus(for: device)
        let deviceUUID = status.resolvedIdentity?.metadata.deviceUUID
        let knownDevice = deviceUUID.flatMap { uuid in
            services.deviceStore.allDevices().first { $0.deviceUUID == uuid }
        }
        return DeviceOverview.make(
            device: device,
            identityStatus: status,
            knownDevice: knownDevice,
            imageIdentity: services.uuidService.readImageIdentity(from: device.partitions)
        )
    }

    private static func listConnectedMedia(
        scanner: DeviceScanner,
        uuidService: UUIDMetadataService,
        deviceStore: DeviceInventoryStore,
        identifyNewMedia: Bool
    ) throws {
        let scanned = try scanner.scanEligibleDevices()
        if scanned.isEmpty {
            print("No connected eligible flash media")
            return
        }

        let knownByID = Dictionary(uniqueKeysWithValues: deviceStore.allDevices().map { ($0.deviceUUID, $0) })
        for device in scanned {
            let identityStatus = identifyNewMedia
                ? uuidService.ensureDeviceIdentityStatus(for: device)
                : uuidService.resolveIdentityStatus(for: device)
            let metadata = identityStatus.resolvedIdentity?.metadata
            let known = metadata.flatMap { knownByID[$0.deviceUUID] }
            let displayName = known?.customName ?? device.displayName
            let deviceIdentifier = identityStatus.deviceUUIDDisplay
            let mediaType = known?.mediaTypeName ?? "-"
            let rememberedSuffix = known == nil ? "" : " [remembered]"
            let source = identityStatus.sourceDisplay
            let imageLabel = (metadata?.image ?? uuidService.readImageIdentity(from: device.partitions))?.displayLabel ?? "-"
            if let metadata {
                try? deviceStore.upsert(deviceUUID: metadata.deviceUUID, candidate: device)
            }
            print(
                "\(displayName)\t\(device.devicePath)\t\(device.formattedSize)\t\(deviceIdentifier)\ttype:\(mediaType)\timage:\(imageLabel)\tdevice-uuid:\(source)\(rememberedSuffix)"
            )
        }
    }

    private static func showMediaInfo(
        query: String,
        scanner: DeviceScanner,
        uuidService: UUIDMetadataService,
        deviceStore: DeviceInventoryStore
    ) throws {
        guard let medium = deviceStore.findDevice(matching: query) else {
            throw FlashError.usage("No remembered medium found for: \(query)")
        }

        let scannedDevices = try scanner.scanEligibleDevices()
        let statusByDevicePath = Dictionary(
            scannedDevices.map { ($0.devicePath, uuidService.resolveIdentityStatus(for: $0)) },
            uniquingKeysWith: { first, _ in first }
        )
        let connectedDevice = scannedDevices.first { device in
            statusByDevicePath[device.devicePath]?.resolvedIdentity?.metadata.deviceUUID == medium.deviceUUID
        }
        let connectedIdentityStatus = connectedDevice.flatMap { statusByDevicePath[$0.devicePath] }
        let customName = medium.customName ?? "-"
        let identification = connectedIdentityStatus?.sourceDisplay ?? "unknown"
        let mediaType = medium.mediaTypeName ?? "-"

        print("Media: \(medium.displayName)")
        print("Device UUID: \(medium.deviceUUID)")
        print("Custom Name: \(customName)")
        print("Media Type: \(mediaType)")
        print("Size: \(ByteCountFormatter.string(fromByteCount: medium.size, countStyle: .file))")
        print("First Seen: \(medium.firstSeen.ISO8601Format())")
        print("Last Seen: \(medium.lastSeen.ISO8601Format())")
        if let connectedDevice {
            print("Connected: yes")
            print("Current Device: \(connectedDevice.devicePath)")
            print("Identification: \(identification)")
            let image = connectedIdentityStatus?.resolvedIdentity?.metadata.image
            print("Image: \(image?.displayLabel ?? "-")")
            if let build = image?.build {
                print("Image Build: \(build)")
            }
        } else {
            print("Connected: no")
            if scannedDevices.contains(where: { statusByDevicePath[$0.devicePath] == .trailerRequiresSudo }) {
                print("Note: some connected media require sudo to inspect trailer metadata")
            }
        }
        if medium.userDefinedFields.isEmpty {
            print("User Fields: none")
        } else {
            print("User Fields:")
            for key in medium.userDefinedFields.keys.sorted() {
                if let value = medium.userDefinedFields[key] {
                    print("  \(key): \(value)")
                }
            }
        }
    }

    private struct Services {
        let imageStore: ImageCatalogStore
        let deviceStore: DeviceInventoryStore
        let historyStore: FlashHistoryStore
        let scanner: DeviceScanner
        let deviceManager: DiskArbitrationManager
        let prompt: PromptRenderer
        let uuidService: UUIDMetadataService
        let imagePreparer: ImagePreparer
        let sourceStore: ImageSourceStore
        let sourceBrowser: ImageSourceBrowser
        let settingsStore: SettingsStore

        var flashService: FlashService {
            FlashService(
                scanner: scanner,
                deviceManager: deviceManager,
                writer: FlashWriter(),
                verifier: FlashVerifier(),
                uuidService: uuidService,
                imageStore: imageStore,
                deviceStore: deviceStore,
                historyStore: historyStore
            )
        }
    }
}
