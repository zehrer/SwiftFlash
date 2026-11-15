import CryptoKit
import Foundation

public struct AppConfig: Codable, Equatable, Sendable {
    public var mediaTypes: [MediaTypeDefinition]
    public var rememberedImages: [RememberedImage]
    public var knownPhysicalDevices: [KnownPhysicalDevice]
    public var knownFlashMedia: [KnownFlashMedia]
    public var flashHistory: [FlashHistoryEntry]
    public var trashedDownloads: [TrashedDownload]
    public var imageSources: [ImageSource]
    public var settings: AppSettings

    public init(
        mediaTypes: [MediaTypeDefinition] = MediaTypeDefinition.preconfiguredDefaults(),
        rememberedImages: [RememberedImage] = [],
        knownPhysicalDevices: [KnownPhysicalDevice] = [],
        knownFlashMedia: [KnownFlashMedia] = [],
        flashHistory: [FlashHistoryEntry] = [],
        trashedDownloads: [TrashedDownload] = [],
        imageSources: [ImageSource] = [],
        settings: AppSettings = AppSettings()
    ) {
        self.mediaTypes = mediaTypes
        self.rememberedImages = rememberedImages
        self.knownPhysicalDevices = knownPhysicalDevices
        self.knownFlashMedia = knownFlashMedia
        self.flashHistory = flashHistory
        self.trashedDownloads = trashedDownloads
        self.imageSources = imageSources
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case mediaTypes
        case rememberedImages
        case knownPhysicalDevices
        case knownFlashMedia
        case flashHistory
        case trashedDownloads
        case imageSources
        case settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mediaTypes = try container.decodeIfPresent([MediaTypeDefinition].self, forKey: .mediaTypes)
            ?? MediaTypeDefinition.preconfiguredDefaults()
        rememberedImages = try container.decodeIfPresent([RememberedImage].self, forKey: .rememberedImages) ?? []
        knownPhysicalDevices = try container.decodeIfPresent([KnownPhysicalDevice].self, forKey: .knownPhysicalDevices) ?? []
        knownFlashMedia = try container.decodeIfPresent([KnownFlashMedia].self, forKey: .knownFlashMedia) ?? []
        flashHistory = try container.decodeIfPresent([FlashHistoryEntry].self, forKey: .flashHistory) ?? []
        trashedDownloads = try container.decodeIfPresent([TrashedDownload].self, forKey: .trashedDownloads) ?? []
        imageSources = try container.decodeIfPresent([ImageSource].self, forKey: .imageSources) ?? []
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mediaTypes, forKey: .mediaTypes)
        try container.encode(rememberedImages, forKey: .rememberedImages)
        try container.encode(knownPhysicalDevices, forKey: .knownPhysicalDevices)
        try container.encode(knownFlashMedia, forKey: .knownFlashMedia)
        try container.encode(flashHistory, forKey: .flashHistory)
        try container.encode(trashedDownloads, forKey: .trashedDownloads)
        try container.encode(imageSources, forKey: .imageSources)
        try container.encode(settings, forKey: .settings)
    }
}

/// Whether to verify the medium after writing.
public enum VerifyMode: String, Codable, CaseIterable, Sendable {
    case ask
    case always
    case never
}

/// User settings, kept separately for direct commands (`swiftflash …`) and the interactive shell.
public struct AppSettings: Codable, Equatable, Sendable {
    /// Verification after a direct `swiftflash …` flash when neither `-v` nor `--no-verify` is given.
    public var verifyConsole: VerifyMode
    /// Verification after a flash started in the interactive shell.
    public var verifyInteractive: VerifyMode
    /// Raspberry Pi board (`pi5`, `pi4`, …) used to filter the `rpi` image list; nil shows all images.
    public var rpiModel: String?

    public init(verifyConsole: VerifyMode = .never, verifyInteractive: VerifyMode = .ask, rpiModel: String? = nil) {
        self.verifyConsole = verifyConsole
        self.verifyInteractive = verifyInteractive
        self.rpiModel = rpiModel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        // Unknown values (e.g. from a newer version) fall back to the default instead of failing.
        verifyConsole = (try? container.decodeIfPresent(VerifyMode.self, forKey: .verifyConsole)) ?? defaults.verifyConsole
        verifyInteractive = (try? container.decodeIfPresent(VerifyMode.self, forKey: .verifyInteractive))
            ?? defaults.verifyInteractive
        rpiModel = try? container.decodeIfPresent(String.self, forKey: .rpiModel)
    }

    private enum CodingKeys: String, CodingKey {
        case verifyConsole
        case verifyInteractive
        case rpiModel
    }

    /// The Raspberry Pi model to filter by: `--model` wins over the setting, and `any` means no filter.
    public func rpiModel(flag: String?) -> String? {
        let model = flag ?? rpiModel
        return model == "any" ? nil : model
    }

    /// The mode for one flash: an explicit `-v` / `--no-verify` wins over the stored setting, and `--yes`
    /// (no questions) turns `ask` into `never`.
    public func verifyMode(interactive: Bool, flag: Bool?, skipConfirmation: Bool) -> VerifyMode {
        if let flag {
            return flag ? .always : .never
        }
        let mode = interactive ? verifyInteractive : verifyConsole
        return mode == .ask && skipConfirmation ? .never : mode
    }
}

/// Settings that can be changed with `settings <key> <value>` in the interactive shell.
public enum SettingKey: String, CaseIterable, Sendable {
    case verify
    case verifyConsole = "verify-console"
    case rpiModel = "rpi-model"

    /// Checks and normalizes a value typed for this key; nil means "unset" (`rpi-model any`).
    public func parseValue(_ text: String) throws -> String? {
        let value = text.lowercased()
        switch self {
        case .verify, .verifyConsole:
            guard VerifyMode(rawValue: value) != nil else {
                throw FlashError.usage("Usage: settings \(rawValue) <ask|always|never>")
            }
            return value
        case .rpiModel:
            guard !value.isEmpty, value.allSatisfy({ $0.isLetter || $0.isNumber }) else {
                throw FlashError.usage("Usage: settings rpi-model <pi5|pi4|pi3|pi2|pi1|zero2w|zero|any>")
            }
            return value == "any" ? nil : value
        }
    }
}

public struct MediaTypeDefinition: Codable, Equatable, Sendable {
    public var name: String
    public var isPreconfigured: Bool
    public var createdAt: Date

    public init(name: String, isPreconfigured: Bool, createdAt: Date) {
        self.name = name
        self.isPreconfigured = isPreconfigured
        self.createdAt = createdAt
    }

    public static func preconfiguredDefaults(createdAt: Date = Date()) -> [MediaTypeDefinition] {
        [
            MediaTypeDefinition(name: "USB Stick", isPreconfigured: true, createdAt: createdAt),
            MediaTypeDefinition(name: "SD Card", isPreconfigured: true, createdAt: createdAt),
            MediaTypeDefinition(name: "Micro SD Card", isPreconfigured: true, createdAt: createdAt)
        ]
    }
}

public struct RememberedImage: Codable, Equatable, Sendable {
    public var path: String
    public var displayName: String
    public var size: Int64
    public var sha256: String?
    public var firstSeen: Date
    public var lastUsed: Date

    public init(
        path: String,
        displayName: String,
        size: Int64,
        sha256: String? = nil,
        firstSeen: Date,
        lastUsed: Date
    ) {
        self.path = path
        self.displayName = displayName
        self.size = size
        self.sha256 = sha256
        self.firstSeen = firstSeen
        self.lastUsed = lastUsed
    }
}

public struct KnownPhysicalDevice: Codable, Equatable, Sendable {
    public var deviceUUID: String
    public var customName: String?
    public var mediaTypeName: String?
    public var size: Int64
    public var firstSeen: Date
    public var lastSeen: Date
    public var userDefinedFields: [String: String]

    public init(
        deviceUUID: String,
        customName: String? = nil,
        mediaTypeName: String? = nil,
        vendor: String? = nil,
        model: String? = nil,
        protocolName: String? = nil,
        size: Int64,
        firstSeen: Date,
        lastSeen: Date,
        userDefinedFields: [String: String] = [:]
    ) {
        self.deviceUUID = deviceUUID
        self.customName = customName
        self.mediaTypeName = mediaTypeName
        self.size = size
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.userDefinedFields = userDefinedFields
    }

    public var displayName: String {
        customName ?? deviceUUID
    }

    private enum CodingKeys: String, CodingKey {
        case deviceUUID
        case physicalDeviceID
        case customName
        case mediaTypeName
        case size
        case firstSeen
        case lastSeen
        case userDefinedFields
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceUUID = try container.decodeIfPresent(String.self, forKey: .deviceUUID)
            ?? container.decode(String.self, forKey: .physicalDeviceID)
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        mediaTypeName = try container.decodeIfPresent(String.self, forKey: .mediaTypeName)
        size = try container.decode(Int64.self, forKey: .size)
        firstSeen = try container.decode(Date.self, forKey: .firstSeen)
        lastSeen = try container.decode(Date.self, forKey: .lastSeen)
        userDefinedFields = try container.decodeIfPresent([String: String].self, forKey: .userDefinedFields) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceUUID, forKey: .deviceUUID)
        try container.encodeIfPresent(customName, forKey: .customName)
        try container.encodeIfPresent(mediaTypeName, forKey: .mediaTypeName)
        try container.encode(size, forKey: .size)
        try container.encode(firstSeen, forKey: .firstSeen)
        try container.encode(lastSeen, forKey: .lastSeen)
        try container.encode(userDefinedFields, forKey: .userDefinedFields)
    }
}

public struct KnownFlashMedia: Codable, Equatable, Sendable {
    public var flashUUID: UUID
    public var lastImagePath: String
    public var lastImageName: String
    public var deviceUUID: String
    public var flashedAt: Date
    public var lastSeen: Date

    public init(
        flashUUID: UUID,
        lastImagePath: String,
        lastImageName: String,
        deviceUUID: String,
        flashedAt: Date,
        lastSeen: Date
    ) {
        self.flashUUID = flashUUID
        self.lastImagePath = lastImagePath
        self.lastImageName = lastImageName
        self.deviceUUID = deviceUUID
        self.flashedAt = flashedAt
        self.lastSeen = lastSeen
    }

    private enum CodingKeys: String, CodingKey {
        case flashUUID
        case lastImagePath
        case lastImageName
        case deviceUUID
        case lastPhysicalDeviceID
        case flashedAt
        case lastSeen
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        flashUUID = try container.decode(UUID.self, forKey: .flashUUID)
        lastImagePath = try container.decode(String.self, forKey: .lastImagePath)
        lastImageName = try container.decode(String.self, forKey: .lastImageName)
        deviceUUID = try container.decodeIfPresent(String.self, forKey: .deviceUUID)
            ?? container.decode(String.self, forKey: .lastPhysicalDeviceID)
        flashedAt = try container.decode(Date.self, forKey: .flashedAt)
        lastSeen = try container.decode(Date.self, forKey: .lastSeen)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flashUUID, forKey: .flashUUID)
        try container.encode(lastImagePath, forKey: .lastImagePath)
        try container.encode(lastImageName, forKey: .lastImageName)
        try container.encode(deviceUUID, forKey: .deviceUUID)
        try container.encode(flashedAt, forKey: .flashedAt)
        try container.encode(lastSeen, forKey: .lastSeen)
    }
}

public struct FlashHistoryEntry: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var finishedAt: Date
    public var imagePath: String
    public var imageName: String
    public var deviceUUID: String
    public var previousFlashUUID: UUID?
    public var newFlashUUID: UUID?
    public var uuidWriteSucceeded: Bool
    public var result: String
    public var image: ImageIdentity?

    public init(
        startedAt: Date,
        finishedAt: Date,
        imagePath: String,
        imageName: String,
        deviceUUID: String,
        previousFlashUUID: UUID?,
        newFlashUUID: UUID?,
        uuidWriteSucceeded: Bool,
        result: String,
        image: ImageIdentity? = nil
    ) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.imagePath = imagePath
        self.imageName = imageName
        self.deviceUUID = deviceUUID
        self.previousFlashUUID = previousFlashUUID
        self.newFlashUUID = newFlashUUID
        self.uuidWriteSucceeded = uuidWriteSucceeded
        self.result = result
        self.image = image
    }

    private enum CodingKeys: String, CodingKey {
        case startedAt
        case finishedAt
        case imagePath
        case imageName
        case deviceUUID
        case physicalDeviceID
        case previousFlashUUID
        case newFlashUUID
        case uuidWriteSucceeded
        case result
        case image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        finishedAt = try container.decode(Date.self, forKey: .finishedAt)
        imagePath = try container.decode(String.self, forKey: .imagePath)
        imageName = try container.decode(String.self, forKey: .imageName)
        deviceUUID = try container.decodeIfPresent(String.self, forKey: .deviceUUID)
            ?? container.decode(String.self, forKey: .physicalDeviceID)
        previousFlashUUID = try container.decodeIfPresent(UUID.self, forKey: .previousFlashUUID)
        newFlashUUID = try container.decodeIfPresent(UUID.self, forKey: .newFlashUUID)
        uuidWriteSucceeded = try container.decode(Bool.self, forKey: .uuidWriteSucceeded)
        result = try container.decode(String.self, forKey: .result)
        image = try container.decodeIfPresent(ImageIdentity.self, forKey: .image)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(finishedAt, forKey: .finishedAt)
        try container.encode(imagePath, forKey: .imagePath)
        try container.encode(imageName, forKey: .imageName)
        try container.encode(deviceUUID, forKey: .deviceUUID)
        try container.encodeIfPresent(previousFlashUUID, forKey: .previousFlashUUID)
        try container.encodeIfPresent(newFlashUUID, forKey: .newFlashUUID)
        try container.encode(uuidWriteSucceeded, forKey: .uuidWriteSucceeded)
        try container.encode(result, forKey: .result)
        try container.encodeIfPresent(image, forKey: .image)
    }
}

public struct FlashUUIDMetadata: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var flashUUID: UUID?
    public var deviceUUID: String
    public var deviceName: String?
    public var imagePath: String
    public var imageName: String
    public var imageSHA256: String?
    public var flashedAt: Date
    /// Identification provided by the image itself; copied unchanged from the image's `/.uuid`.
    public var image: ImageIdentity?

    public init(
        schemaVersion: Int = 1,
        flashUUID: UUID?,
        deviceUUID: String,
        deviceName: String?,
        imagePath: String,
        imageName: String,
        imageSHA256: String?,
        flashedAt: Date,
        image: ImageIdentity? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.flashUUID = flashUUID
        self.deviceUUID = deviceUUID
        self.deviceName = deviceName
        self.imagePath = imagePath
        self.imageName = imageName
        self.imageSHA256 = imageSHA256
        self.flashedAt = flashedAt
        self.image = image
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case flashUUID
        case deviceUUID
        case physicalDeviceID
        case deviceName
        case physicalDeviceName
        case imagePath
        case imageName
        case imageSHA256
        case flashedAt
        case image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        flashUUID = try container.decodeIfPresent(UUID.self, forKey: .flashUUID)
        deviceUUID = try container.decodeIfPresent(String.self, forKey: .deviceUUID)
            ?? container.decode(String.self, forKey: .physicalDeviceID)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            ?? container.decodeIfPresent(String.self, forKey: .physicalDeviceName)
        imagePath = try container.decode(String.self, forKey: .imagePath)
        imageName = try container.decode(String.self, forKey: .imageName)
        imageSHA256 = try container.decodeIfPresent(String.self, forKey: .imageSHA256)
        flashedAt = try container.decode(Date.self, forKey: .flashedAt)
        image = try container.decodeIfPresent(ImageIdentity.self, forKey: .image)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(flashUUID, forKey: .flashUUID)
        try container.encode(deviceUUID, forKey: .deviceUUID)
        try container.encodeIfPresent(deviceName, forKey: .deviceName)
        try container.encode(imagePath, forKey: .imagePath)
        try container.encode(imageName, forKey: .imageName)
        try container.encodeIfPresent(imageSHA256, forKey: .imageSHA256)
        try container.encode(flashedAt, forKey: .flashedAt)
        try container.encodeIfPresent(image, forKey: .image)
    }
}

public enum DeviceIdentitySource: String, Equatable, Sendable {
    case file
    case trailer
    case created

    public var displayLabel: String {
        switch self {
        case .file:
            return "reused(.uuid)"
        case .trailer:
            return "reused(trailer)"
        case .created:
            return "created(.uuid)"
        }
    }
}

public struct ResolvedDeviceIdentity: Equatable, Sendable {
    public var metadata: FlashUUIDMetadata
    public var source: DeviceIdentitySource

    public init(metadata: FlashUUIDMetadata, source: DeviceIdentitySource) {
        self.metadata = metadata
        self.source = source
    }
}

public enum DeviceIdentityStatus: Equatable, Sendable {
    case identified(ResolvedDeviceIdentity)
    case unassigned
    case trailerRequiresSudo

    public var resolvedIdentity: ResolvedDeviceIdentity? {
        switch self {
        case .identified(let identity):
            return identity
        case .unassigned, .trailerRequiresSudo:
            return nil
        }
    }

    public var deviceUUIDDisplay: String {
        switch self {
        case .identified(let identity):
            return identity.metadata.deviceUUID
        case .unassigned:
            return "unassigned"
        case .trailerRequiresSudo:
            return "unknown"
        }
    }

    public var sourceDisplay: String {
        switch self {
        case .identified(let identity):
            return identity.source.displayLabel
        case .unassigned:
            return "unassigned"
        case .trailerRequiresSudo:
            return "unknown (sudo required for trailer)"
        }
    }
}

public struct FlashCompletion: Equatable, Sendable {
    public var previousIdentity: ResolvedDeviceIdentity?
    public var metadata: FlashUUIDMetadata
    public var writeResult: MetadataWriteResult
    public var verified: Bool

    public init(
        previousIdentity: ResolvedDeviceIdentity?,
        metadata: FlashUUIDMetadata,
        writeResult: MetadataWriteResult,
        verified: Bool
    ) {
        self.previousIdentity = previousIdentity
        self.metadata = metadata
        self.writeResult = writeResult
        self.verified = verified
    }
}

public struct PartitionVolume: Equatable, Sendable {
    public var bsdName: String
    public var mountPoint: String?
    public var volumeName: String?
    public var volumeKind: String?
    public var isMountable: Bool
    public var isWritable: Bool

    public init(
        bsdName: String,
        mountPoint: String?,
        volumeName: String?,
        volumeKind: String?,
        isMountable: Bool,
        isWritable: Bool
    ) {
        self.bsdName = bsdName
        self.mountPoint = mountPoint
        self.volumeName = volumeName
        self.volumeKind = volumeKind
        self.isMountable = isMountable
        self.isWritable = isWritable
    }
}

public struct DiskCandidate: Equatable, Sendable {
    public var devicePath: String
    public var rawDevicePath: String
    public var bsdName: String
    public var physicalDeviceID: String
    public var name: String
    public var vendor: String?
    public var model: String?
    public var protocolName: String?
    public var serialNumber: String?
    public var size: Int64
    public var isInternal: Bool
    public var isRemovable: Bool
    public var isEjectable: Bool
    public var isWritable: Bool
    public var isWhole: Bool
    public var mediaUUID: String?
    public var mediaKind: String?
    public var partitions: [PartitionVolume]

    public init(
        devicePath: String,
        rawDevicePath: String,
        bsdName: String,
        physicalDeviceID: String,
        name: String,
        vendor: String?,
        model: String?,
        protocolName: String?,
        serialNumber: String?,
        size: Int64,
        isInternal: Bool,
        isRemovable: Bool,
        isEjectable: Bool,
        isWritable: Bool,
        isWhole: Bool,
        mediaUUID: String?,
        mediaKind: String?,
        partitions: [PartitionVolume]
    ) {
        self.devicePath = devicePath
        self.rawDevicePath = rawDevicePath
        self.bsdName = bsdName
        self.physicalDeviceID = physicalDeviceID
        self.name = name
        self.vendor = vendor
        self.model = model
        self.protocolName = protocolName
        self.serialNumber = serialNumber
        self.size = size
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.isWritable = isWritable
        self.isWhole = isWhole
        self.mediaUUID = mediaUUID
        self.mediaKind = mediaKind
        self.partitions = partitions
    }

    public var displayName: String {
        name.isEmpty ? bsdName : name
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    public var isDiskImage: Bool {
        if let mediaKind, mediaKind.localizedCaseInsensitiveContains("disk image") {
            return true
        }
        if model?.localizedCaseInsensitiveContains("disk image") == true {
            return true
        }
        return name.localizedCaseInsensitiveContains("disk image")
    }
}

public struct RawDiskSnapshot: Equatable, Sendable {
    public var devicePath: String
    public var bsdName: String
    public var name: String
    public var vendor: String?
    public var model: String?
    public var protocolName: String?
    public var serialNumber: String?
    public var size: Int64
    public var isInternal: Bool
    public var isRemovable: Bool
    public var isEjectable: Bool
    public var isWritable: Bool
    public var isWhole: Bool
    public var mediaUUID: String?
    public var mediaKind: String?
    public var partitions: [PartitionVolume]

    public init(
        devicePath: String,
        bsdName: String,
        name: String,
        vendor: String? = nil,
        model: String? = nil,
        protocolName: String? = nil,
        serialNumber: String? = nil,
        size: Int64,
        isInternal: Bool,
        isRemovable: Bool,
        isEjectable: Bool,
        isWritable: Bool,
        isWhole: Bool,
        mediaUUID: String? = nil,
        mediaKind: String? = nil,
        partitions: [PartitionVolume] = []
    ) {
        self.devicePath = devicePath
        self.bsdName = bsdName
        self.name = name
        self.vendor = vendor
        self.model = model
        self.protocolName = protocolName
        self.serialNumber = serialNumber
        self.size = size
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.isWritable = isWritable
        self.isWhole = isWhole
        self.mediaUUID = mediaUUID
        self.mediaKind = mediaKind
        self.partitions = partitions
    }
}

public struct ImageDescriptor: Equatable, Sendable {
    public var url: URL
    public var size: Int64
    public var checksum: String?
    /// Where the image originally came from (remote URL or compressed file) when `url` is a temporary copy.
    public var sourceLocation: String?

    public init(url: URL, size: Int64, checksum: String?, sourceLocation: String? = nil) {
        self.url = url
        self.size = size
        self.checksum = checksum
        self.sourceLocation = sourceLocation
    }

    public var name: String {
        url.lastPathComponent
    }

    /// The location to remember and record: the original source if there is one, otherwise the file path.
    public var sourcePath: String {
        sourceLocation ?? url.path
    }
}

public enum PartitionScheme: String, Equatable, Sendable {
    case mbr = "MBR"
    case gpt = "GPT"
    case unknown = "Unknown"
}

public enum FlashCommand: Equatable, Sendable {
    case repl
    /// `verify`: true for `-v` / `--verify`, false for `--no-verify`, nil to use the stored setting.
    /// `model`: Raspberry Pi board for the `rpi` list (`--model`), nil to use the stored setting.
    case flash(imagePath: String?, devicePath: String?, skipConfirmation: Bool, verify: Bool? = nil, model: String? = nil)
    case verify(imagePath: String?, devicePath: String?)
    case images
    case imagesClear
    case imagesRemove(query: String)
    case mediaList
    case mediaKnown
    case mediaInfo(query: String)
    case mediaIdentify
    case mediaShow(devicePath: String?)
    case mediaTypes
    case mediaTypeAdd(name: String)
    case mediaSetType(id: String, typeName: String)
    case mediaClearType(id: String)
    case mediaName(id: String, name: String)
    case mediaClearName(id: String)
    case history
    case historyClear
    case version
    case sourceList
    case sourceAdd(name: String, url: String)
    case sourceRemove(name: String)
    case sourceBrowse(name: String, family: String?, model: String? = nil)
    case settings
    /// `value` nil clears the setting.
    case settingsSet(key: SettingKey, value: String?)
    case help
}

public enum InteractiveInput: Equatable, Sendable {
    case empty
    case exit
    case command(FlashCommand)
}

public enum FlashError: LocalizedError, Equatable {
    case usage(String)
    case requiresRoot
    case imageNotFound(String)
    case invalidImage(String)
    case imageTooLarge(imageSize: Int64, deviceSize: Int64)
    case deviceNotFound(String)
    case noEligibleDevices
    case cancelled
    case unmountFailed(String)
    case mountFailed(String)
    case rawWriteFailed(String)
    case verificationFailed(String)
    case persistenceFailed(String)
    case ioFailed(String)

    public var errorDescription: String? {
        switch self {
        case .usage(let message):
            message
        case .requiresRoot:
            "Please run with sudo"
        case .imageNotFound(let path):
            "Image file not found: \(path)"
        case .invalidImage(let reason):
            reason
        case .imageTooLarge(let imageSize, let deviceSize):
            "Image is too large for the selected device (\(imageSize) > \(deviceSize))"
        case .deviceNotFound(let path):
            "Device not found or not eligible: \(path)"
        case .noEligibleDevices:
            "No external physical devices are available"
        case .cancelled:
            "Operation cancelled"
        case .unmountFailed(let reason):
            "Failed to unmount device: \(reason)"
        case .mountFailed(let reason):
            "Failed to mount volume: \(reason)"
        case .rawWriteFailed(let reason):
            "Flash write failed: \(reason)"
        case .verificationFailed(let reason):
            "Verification failed: \(reason)"
        case .persistenceFailed(let reason):
            "Failed to persist config: \(reason)"
        case .ioFailed(let reason):
            "I/O failure: \(reason)"
        }
    }
}

enum JSONCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum Hashing {
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public struct MetadataWriteResult: Equatable, Sendable {
    public var fileWritten: Bool
    public var trailerWritten: Bool

    public init(fileWritten: Bool, trailerWritten: Bool) {
        self.fileWritten = fileWritten
        self.trailerWritten = trailerWritten
    }

    public var anyWritten: Bool {
        fileWritten || trailerWritten
    }

    public var storageDescription: String {
        switch (fileWritten, trailerWritten) {
        case (true, true):
            return ".uuid file + trailer"
        case (true, false):
            return ".uuid file"
        case (false, true):
            return "trailer"
        case (false, false):
            return "none"
        }
    }
}
