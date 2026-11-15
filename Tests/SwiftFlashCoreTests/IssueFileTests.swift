import Foundation
import Testing
@testable import SwiftFlashCore

struct IssueFileTests {
    @Test
    func parsesRaspberryPiOSLite() throws {
        let identity = try #require(IssueFile.parse("""
        Raspberry Pi reference 2026-10-06
        Generated using pi-gen, https://github.com/RPi-Distro/pi-gen, b2cd98a9ee08a31ef7d0110ed09f2492bbd972ec, stage2

        """))

        #expect(identity.displayLabel == "Raspberry Pi OS Lite 2026-10-06")
        #expect(identity.id == "raspberry-pi-os")
        #expect(identity.build == "b2cd98a9ee08")
        #expect(identity.additionalFields["detectedFrom"] == .string("issue.txt"))
        #expect(identity.additionalFields["piGenStage"] == .string("stage2"))
    }

    @Test
    func parsesDesktopAndDerivedImages() throws {
        let desktop = try #require(IssueFile.parse("Raspberry Pi reference 2026-10-06\nGenerated using pi-gen, url, abc, stage4\n"))
        #expect(desktop.displayLabel == "Raspberry Pi OS 2026-10-06")

        let derived = try #require(IssueFile.parse("MyKiosk OS v1.2.3\n"))
        #expect(derived.name == "MyKiosk OS")
        #expect(derived.version == "v1.2.3")
        #expect(derived.id == nil)

        let noVersion = try #require(IssueFile.parse("Custom build\n"))
        #expect(noVersion.displayLabel == "Custom build")
        #expect(IssueFile.parse("\n\n") == nil)
    }

    @Test
    func uuidImageBlockWinsOverIssueFile() throws {
        let mount = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        let partitions = [PartitionVolume(
            bsdName: "disk9s1", mountPoint: mount.path, volumeName: "bootfs",
            volumeKind: "msdos", isMountable: true, isWritable: true
        )]
        let service = UUIDMetadataService()

        try Data("Raspberry Pi reference 2026-10-06\n".utf8).write(to: mount.appendingPathComponent("issue.txt"))
        #expect(service.readImageIdentity(from: partitions)?.displayLabel == "Raspberry Pi OS 2026-10-06")

        try Data(#"{"schemaVersion": 1, "image": {"name": "Redox OS", "version": "0.9.1"}}"#.utf8)
            .write(to: mount.appendingPathComponent(".uuid"))
        #expect(service.readImageIdentity(from: partitions)?.displayLabel == "Redox OS 0.9.1")
    }
}
