import Foundation
import Testing
@testable import SwiftFlashCore

struct SettingsTests {
    @Test
    func flashParsesVerifyFlags() throws {
        #expect(try CLIParser.parse(arguments: ["swiftflash", "a.img", "-v"])
            == .flash(imagePath: "a.img", devicePath: nil, skipConfirmation: false, verify: true))
        #expect(try CLIParser.parse(arguments: ["swiftflash", "flash", "--verify", "a.img", "/dev/disk4", "--yes"])
            == .flash(imagePath: "a.img", devicePath: "/dev/disk4", skipConfirmation: true, verify: true))
        #expect(try CLIParser.parse(arguments: ["swiftflash", "a.img", "--no-verify"])
            == .flash(imagePath: "a.img", devicePath: nil, skipConfirmation: false, verify: false))
        #expect(throws: FlashError.self) { try CLIParser.parse(arguments: ["swiftflash", "a.img", "-v", "--no-verify"]) }
        #expect(throws: FlashError.self) { try CLIParser.parse(arguments: ["swiftflash", "a.img", "--verfy"]) }
    }

    @Test
    func settingsAreOnlyAvailableInTheInteractiveShell() throws {
        #expect(throws: FlashError.self) { try CLIParser.parse(arguments: ["swiftflash", "settings"]) }
        #expect(try CLIParser.parseInteractive(line: "settings") == .command(.settings))
        #expect(try CLIParser.parseInteractive(line: "settings verify-console always")
            == .command(.settingsSet(key: .verifyConsole, value: "always")))
        #expect(throws: FlashError.self) { try CLIParser.parseInteractive(line: "settings verify maybe") }
    }

    @Test
    func verifyModeResolution() {
        let defaults = AppSettings()
        #expect(defaults.verifyMode(interactive: false, flag: nil, skipConfirmation: false) == .never)
        #expect(defaults.verifyMode(interactive: true, flag: nil, skipConfirmation: false) == .ask)
        #expect(defaults.verifyMode(interactive: true, flag: nil, skipConfirmation: true) == .never)
        #expect(defaults.verifyMode(interactive: false, flag: true, skipConfirmation: true) == .always)
        #expect(defaults.verifyMode(interactive: true, flag: false, skipConfirmation: false) == .never)
        let always = AppSettings(verifyConsole: .always, verifyInteractive: .never)
        #expect(always.verifyMode(interactive: false, flag: nil, skipConfirmation: true) == .always)
        #expect(always.verifyMode(interactive: true, flag: nil, skipConfirmation: false) == .never)
    }

    @Test
    func settingsArePersistedAndOldConfigsGetDefaults() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"imageSources": []}"#.utf8).write(to: url)

        let store = SettingsStore(configStore: try AppConfigStore(configURL: url))
        #expect(store.settings == AppSettings())
        try store.set(.verifyConsole, to: .always)
        try store.set(.verify, to: .never)

        let reloaded = SettingsStore(configStore: try AppConfigStore(configURL: url))
        #expect(reloaded.settings == AppSettings(verifyConsole: .always, verifyInteractive: .never))
    }
}
