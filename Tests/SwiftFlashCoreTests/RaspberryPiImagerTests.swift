import Foundation
import Testing
@testable import SwiftFlashCore

struct RaspberryPiImagerTests {
    static let sample = Data("""
    {
      "imager": {
        "devices": [
          {"name": "Raspberry Pi 5", "tags": ["pi5-64bit", "pi5-32bit"], "matching_type": "exclusive"},
          {"name": "Raspberry Pi 4", "tags": ["pi4-64bit", "pi4-32bit"], "matching_type": "inclusive"},
          {"name": "Raspberry Pi Zero 2 W", "tags": ["pi3-64bit", "pi3-32bit"], "matching_type": "inclusive"},
          {"name": "No filtering", "tags": [], "matching_type": "inclusive"}
        ]
      },
      "os_list": [
        {"name": "Raspberry Pi OS (64-bit)", "url": "https://x/a/2026-10-06-raspios-trixie-arm64.img.xz",
         "release_date": "2026-10-06", "extract_sha256": "ABC", "devices": ["pi5-64bit", "pi4-64bit", "pi3-64bit"]},
        {"name": "Raspberry Pi OS (other)", "subitems": [
          {"name": "Raspberry Pi OS Lite (64-bit)", "url": "https://x/b/lite.img.xz", "release_date": "2026-10-06",
           "devices": ["pi4-64bit"]},
          {"name": "Raspberry Pi OS (64-bit)", "url": "https://x/a/2026-10-06-raspios-trixie-arm64.img.xz"}
        ]},
        {"name": "Media", "subitems": [
          {"name": "Untagged OS", "url": "https://x/c/untagged.img.xz"},
          {"name": "Zipped OS", "url": "https://x/d/zipped.zip"},
          {"name": "Gzipped OS", "url": "https://x/e/gz.img.gz"}
        ]}
      ]
    }
    """.utf8)

    @Test
    func parsesImagesModelsAndCategories() throws {
        let list = try #require(RaspberryPiImageList.parse(Self.sample))

        #expect(list.models.map(\.slug) == ["pi5", "pi4", "zero2w"])
        #expect(list.images.map(\.family) == ["raspberry-pi-os-64-bit", "raspberry-pi-os-lite-64-bit", "untagged-os"])
        #expect(list.unsupportedCount == 2)

        let first = list.images[0]
        #expect(first.title == "Raspberry Pi OS (64-bit)")
        #expect(first.category == nil)
        #expect(first.version == "2026-10-06")
        #expect(first.imageSHA256 == "abc")
        #expect(list.images[1].category == "Raspberry Pi OS (other)")
        #expect(list.modelSlugs(for: first) == ["pi5", "pi4", "zero2w"])
        #expect(list.modelSlugs(for: list.images[2]).isEmpty)
    }

    @Test
    func modelFilterFollowsImagerMatching() throws {
        let list = try #require(RaspberryPiImageList.parse(Self.sample))
        let pi5 = try list.model(named: "PI5")
        let pi4 = try list.model(named: "pi4")
        let families = { (model: RaspberryPiModel) in list.images.filter(model.supports).map(\.family) }

        // pi5 is exclusive: untagged images are not offered.
        #expect(families(pi5) == ["raspberry-pi-os-64-bit"])
        #expect(families(pi4) == ["raspberry-pi-os-64-bit", "raspberry-pi-os-lite-64-bit", "untagged-os"])
        #expect(throws: FlashError.self) { try list.model(named: "pi9") }
    }

    @Test
    func listKeepsItsOrderAndShortFormsWork() throws {
        let list = try #require(RaspberryPiImageList.parse(Self.sample))
        let families = RemoteImageNaming.families(from: list.images)
        #expect(families.map(\.name) == ["raspberry-pi-os-64-bit", "raspberry-pi-os-lite-64-bit", "untagged-os"])
        #expect(try RemoteImageNaming.family(matching: "lite-64", in: families).name == "raspberry-pi-os-lite-64-bit")
        #expect(RaspberryPiModel.slug(for: "Raspberry Pi Zero") == "zero")
        #expect(RaspberryPiImageList.isListURL(RaspberryPiImageList.officialURL))
        #expect(!RaspberryPiImageList.isListURL("http://homenodellm:8080/sdcard/"))
    }

    @Test
    func rpiIsBuiltInAndCanBeOverridden() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ImageSourceStore(configStore: try AppConfigStore(configURL: url))

        #expect(store.source(named: "rpi")?.url == RaspberryPiImageList.officialURL)
        #expect(try store.remove(named: "rpi") == false)
        try store.add(ImageSource(name: "rpi", url: "https://mirror.example/os_list.json"))
        #expect(store.source(named: "rpi")?.url == "https://mirror.example/os_list.json")
        #expect(store.allSources().filter { $0.name == "rpi" }.count == 1)
    }

    @Test
    func modelOptionAndSetting() throws {
        #expect(try CLIParser.parse(arguments: ["swiftflash", "rpi:lite-64", "--model", "pi4"])
            == .flash(imagePath: "rpi:lite-64", devicePath: nil, skipConfirmation: false, model: "pi4"))
        #expect(try CLIParser.parse(arguments: ["swiftflash", "source", "browse", "rpi", "--model", "any"])
            == .sourceBrowse(name: "rpi", family: nil, model: "any"))
        #expect(throws: FlashError.self) { try CLIParser.parse(arguments: ["swiftflash", "a.img", "--model"]) }
        #expect(try CLIParser.parseInteractive(line: "settings rpi-model pi5")
            == .command(.settingsSet(key: .rpiModel, value: "pi5")))
        #expect(try CLIParser.parseInteractive(line: "settings rpi-model any")
            == .command(.settingsSet(key: .rpiModel, value: nil)))

        let settings = AppSettings(rpiModel: "pi5")
        #expect(settings.rpiModel(flag: nil) == "pi5")
        #expect(settings.rpiModel(flag: "pi4") == "pi4")
        #expect(settings.rpiModel(flag: "any") == nil)
    }

    @Test
    func unpackedImageIsCheckedAgainstExpectedSHA256() async throws {
        let directory = try ImagePreparer.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = directory.appendingPathComponent("plain.img")
        try Data(count: 1024 * 1024).write(to: image)
        let sha256 = try ImageSupport.calculateSHA256(for: image)

        let preparer = ImagePreparer()
        let ok = try await preparer.prepare(source: image.path, expectedImageSHA256: sha256.uppercased()) { _ in }
        #expect(ok.imageChecksumVerified)
        await #expect(throws: FlashError.self) {
            _ = try await preparer.prepare(source: image.path, expectedImageSHA256: String(repeating: "0", count: 64)) { _ in }
        }
    }

    /// Against the real Raspberry Pi list: set SWIFTFLASH_TEST_RPI=1 (downloads ~33 MB).
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTFLASH_TEST_RPI"] != nil))
    func smallestRealImageMatchesItsExtractSHA256() async throws {
        let source = try #require(ImageSource.builtIn.first { $0.name == "rpi" })
        let list = try #require(try await ImageSourceBrowser().raspberryPiList(in: source))
        #expect(list.images.count > 20)
        let image = try #require(list.images.first { $0.title?.contains("Yellow") == true && $0.imageSHA256 != nil })

        let prepared = try await ImagePreparer().prepare(
            source: image.url.absoluteString,
            expectedImageSHA256: image.imageSHA256
        ) { _ in }
        defer { prepared.cleanup() }
        #expect(prepared.imageChecksumVerified)
    }
}
