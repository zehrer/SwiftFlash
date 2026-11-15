import Foundation
import Testing
@testable import SwiftFlashCore

struct DeviceOverviewTests {
    private let flashedAt = Date(timeIntervalSince1970: 1_793_000_000)

    @Test
    func knownMediumShowsNameTypeAndCurrentImage() {
        let metadata = FlashUUIDMetadata(
            flashUUID: UUID(),
            deviceUUID: "0F9A6091",
            deviceName: "Generic MassStorageClass Media",
            imagePath: "http://host/sdcard-redox.img.xz",
            imageName: "sdcard-redox.img",
            imageSHA256: nil,
            flashedAt: flashedAt,
            image: ImageIdentity(name: "Redox OS", version: "0.9.1")
        )
        let known = KnownPhysicalDevice(
            deviceUUID: "0F9A6091",
            customName: "Redox SD",
            mediaTypeName: "SD Card",
            size: 32,
            firstSeen: flashedAt,
            lastSeen: flashedAt
        )

        let overview = DeviceOverview.make(
            device: device(volumes: ["BOOT"]),
            identityStatus: .identified(ResolvedDeviceIdentity(metadata: metadata, source: .file)),
            knownDevice: known,
            imageIdentity: nil,
            formatDate: { _ in "26 Oct 2026" }
        )

        #expect(overview.title == "Redox SD")
        #expect(overview.details == [
            "Known medium: Redox SD [SD Card], device-uuid 0F9A6091",
            "Currently on it: Redox OS 0.9.1 (sdcard-redox.img), flashed 26 Oct 2026",
        ])
        #expect(overview.currentContent == "Redox OS 0.9.1 (sdcard-redox.img), flashed 26 Oct 2026")
    }

    @Test
    func imageDetailsListIdentityFileSourceAndFlash() {
        let flashUUID = UUID()
        let metadata = FlashUUIDMetadata(
            flashUUID: flashUUID,
            deviceUUID: "0F9A6091",
            deviceName: nil,
            imagePath: "http://host/redox-rpi-t18-direct-v0.4.0.img.xz",
            imageName: "redox-rpi-t18-direct-v0.4.0.img",
            imageSHA256: "abc",
            flashedAt: flashedAt,
            image: ImageIdentity(
                id: "redox-rpi-t18-direct",
                name: "Redox OS",
                version: "v0.4.0",
                build: "2026-11-02T20:50:32Z",
                additionalFields: ["commit": .string("1107e5f7"), "board": .object([:])]
            )
        )

        let lines = DeviceOverview.imageDetails(metadata: metadata, imageIdentity: nil, formatDate: { _ in "2 Nov 2026" })

        #expect(lines == [
            "Image:        Redox OS v0.4.0",
            "Image id:     redox-rpi-t18-direct",
            "Image build:  2026-11-02T20:50:32Z",
            "commit:       1107e5f7",
            "Image file:   redox-rpi-t18-direct-v0.4.0.img",
            "Source:       http://host/redox-rpi-t18-direct-v0.4.0.img.xz",
            "SHA-256:      abc",
            "Flashed:      2 Nov 2026",
            "Flash UUID:   \(flashUUID.uuidString)",
        ])
    }

    @Test
    func historyLinesShowEarlierFlashesOfThisMediumOnly() {
        func entry(_ name: String, _ device: String, _ offset: TimeInterval, result: String = "success_metadata_file_only") -> FlashHistoryEntry {
            FlashHistoryEntry(
                startedAt: flashedAt.addingTimeInterval(offset),
                finishedAt: flashedAt.addingTimeInterval(offset),
                imagePath: name,
                imageName: name,
                deviceUUID: device,
                previousFlashUUID: nil,
                newFlashUUID: nil,
                uuidWriteSucceeded: true,
                result: result,
                image: name == "b.img" ? ImageIdentity(name: "Redox OS", version: "0.9.1") : nil
            )
        }
        let history = [entry("a.img", "card", 0), entry("other.img", "other", 50), entry("b.img", "card", 100),
                       entry("c.img", "card", 200, result: "failed: write error")]

        let lines = DeviceOverview.historyLines(history, deviceUUID: "card", limit: 2, formatDate: { _ in "d" })

        #expect(lines == [
            "History on this Mac (3 flashes):",
            "  d  c.img  [failed]",
            "  d  Redox OS 0.9.1 (b.img)",
            "  … 1 more, see `swiftflash history`",
        ])
        #expect(DeviceOverview.historyLines(history, deviceUUID: "unknown").isEmpty)
    }

    @Test
    func imageDetailsForImageShippedFileOnly() {
        let lines = DeviceOverview.imageDetails(metadata: nil, imageIdentity: ImageIdentity(id: "sdcard-redox", version: "0.9.0"))
        #expect(lines == ["Image:        sdcard-redox 0.9.0"])
        #expect(DeviceOverview.imageDetails(metadata: nil, imageIdentity: nil).isEmpty)
    }

    @Test
    func knownMediumWithoutCustomNameKeepsDeviceName() {
        let metadata = FlashUUIDMetadata(
            flashUUID: nil,
            deviceUUID: "ABC",
            deviceName: nil,
            imagePath: "",
            imageName: "",
            imageSHA256: nil,
            flashedAt: flashedAt
        )
        let known = KnownPhysicalDevice(deviceUUID: "ABC", size: 32, firstSeen: flashedAt, lastSeen: flashedAt)

        let overview = DeviceOverview.make(
            device: device(volumes: ["UNTITLED"]),
            identityStatus: .identified(ResolvedDeviceIdentity(metadata: metadata, source: .file)),
            knownDevice: known,
            imageIdentity: nil
        )

        #expect(overview.title == "Generic Media")
        #expect(overview.details == [
            "Known medium: unnamed, device-uuid ABC",
            "Currently on it: volumes UNTITLED",
        ])
    }

    @Test
    func unknownMediumShowsImageShippedOnIt() {
        let overview = DeviceOverview.make(
            device: device(volumes: ["BOOT"]),
            identityStatus: .unassigned,
            knownDevice: nil,
            imageIdentity: ImageIdentity(id: "sdcard-redox", version: "0.9.0")
        )

        #expect(overview.details == ["Unknown medium", "Currently on it: sdcard-redox 0.9.0"])
    }

    @Test
    func emptyUnknownMediumHasNoContentLine() {
        let overview = DeviceOverview.make(
            device: device(volumes: []),
            identityStatus: .trailerRequiresSudo,
            knownDevice: nil,
            imageIdentity: nil
        )

        #expect(overview.details == ["Unknown medium (sudo required to read trailer metadata)"])
        #expect(overview.currentContent == nil)
    }

    private func device(volumes: [String]) -> DiskCandidate {
        DiskCandidate(
            devicePath: "/dev/disk6",
            rawDevicePath: "/dev/rdisk6",
            bsdName: "disk6",
            physicalDeviceID: "scan-hint",
            name: "Generic Media",
            vendor: nil,
            model: nil,
            protocolName: nil,
            serialNumber: nil,
            size: 32 * 1024 * 1024 * 1024,
            isInternal: false,
            isRemovable: true,
            isEjectable: true,
            isWritable: true,
            isWhole: true,
            mediaUUID: nil,
            mediaKind: nil,
            partitions: volumes.enumerated().map { index, name in
                PartitionVolume(
                    bsdName: "disk6s\(index + 1)",
                    mountPoint: nil,
                    volumeName: name,
                    volumeKind: "msdos",
                    isMountable: true,
                    isWritable: true
                )
            }
        )
    }
}
