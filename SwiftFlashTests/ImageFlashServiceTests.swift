//
//  ImageFlashServiceTests.swift
//  SwiftFlashTests
//
//  Created by AI Assistant on 08.08.25.
//

import Testing
@testable import SwiftFlash

/// Test suite for the flash error messages and the contract with the privileged helper.
///
/// Writing to a real device needs the root helper daemon and user approval in
/// System Settings, so those paths are verified manually, not in unit tests.
struct ImageFlashServiceTests {

    // MARK: - FlashError

    @Test func testFlashErrorDescriptions() {
        #expect(FlashError.authenticationFailed.description == "Touch ID authentication failed")
        #expect(FlashError.authorizationDenied.description == "Root privileges denied")
        #expect(FlashError.insufficientPermissions.description == "Insufficient permissions to write to device")
        #expect(FlashError.flashFailed("boom").description == "Flash failed: boom")
    }

    // MARK: - Helper contract

    /// The launchd label, Mach service name and code signing identifier must stay identical.
    @Test func testHelperIdentifiersAreConsistent() {
        #expect(FlashHelperConstants.helperIdentifier == "xyz.zehrer.SwiftFlash.helper")
        #expect(FlashHelperConstants.daemonPlistName == "\(FlashHelperConstants.helperIdentifier).plist")
    }

    /// Each side only trusts the other if identifier and team match.
    @Test func testSigningRequirementsPinIdentityAndTeam() {
        let client = FlashHelperConstants.clientRequirement
        #expect(client.contains("identifier \"\(FlashHelperConstants.appIdentifier)\""))
        #expect(client.contains(FlashHelperConstants.teamIdentifier))

        let helper = FlashHelperConstants.helperRequirement
        #expect(helper.contains("identifier \"\(FlashHelperConstants.helperIdentifier)\""))
        #expect(helper.contains(FlashHelperConstants.teamIdentifier))
    }
}
