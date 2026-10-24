//
//  FlashHelperProtocol.swift
//  SwiftFlash
//
//  Shared between the app target and the privileged helper target (SwiftFlashHelper).
//  Keep this file free of app-only dependencies.
//

import Foundation

/// Names and identity requirements shared by the app and the privileged helper.
nonisolated enum FlashHelperConstants {
    /// Launchd label, Mach service name and bundle identifier of the helper daemon.
    static let helperIdentifier = "xyz.zehrer.SwiftFlash.helper"

    /// File name of the launchd plist inside `Contents/Library/LaunchDaemons`.
    static let daemonPlistName = "xyz.zehrer.SwiftFlash.helper.plist"

    static let appIdentifier = "xyz.zehrer.SwiftFlash"
    static let teamIdentifier = "NV9LC295QZ"

    /// Code signing requirement the helper enforces on connecting clients.
    static let clientRequirement =
        "anchor apple generic and identifier \"\(appIdentifier)\" "
        + "and certificate leaf[subject.OU] = \"\(teamIdentifier)\""

    /// Code signing requirement the app enforces on the helper it connects to.
    static let helperRequirement =
        "anchor apple generic and identifier \"\(helperIdentifier)\" "
        + "and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
}

/// Interface exported by the root helper. All replies deliver `nil` on success
/// or a human-readable error message on failure.
@objc nonisolated protocol FlashHelperProtocol {
    /// Unmounts the target disk and writes `imageSize` bytes read from `image`
    /// to the raw device (e.g. `/dev/rdisk4`). Progress is reported through the
    /// connection's `FlashProgressReceiverProtocol`.
    func writeImage(
        _ image: FileHandle,
        imageSize: Int64,
        toDevice devicePath: String,
        reply: @escaping (String?) -> Void)

    /// Reads the raw device back and compares it byte for byte with `image`.
    func verifyImage(
        _ image: FileHandle,
        imageSize: Int64,
        onDevice devicePath: String,
        reply: @escaping (String?) -> Void)

    /// Requests cancellation of the running write or verify operation.
    func cancelOperation(reply: @escaping () -> Void)
}

/// Interface exported by the app so the helper can report progress.
@objc nonisolated protocol FlashProgressReceiverProtocol {
    func flashProgress(bytesDone: Int64, bytesTotal: Int64)
}
