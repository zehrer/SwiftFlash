//
//  PrivilegedHelperClient.swift
//  SwiftFlash
//
//  App-side access to the root helper daemon (SwiftFlashHelper).
//  Registers the daemon via SMAppService and talks to it over XPC.
//

import Foundation
import ServiceManagement
import os

/// Receives progress callbacks from the helper (called on an XPC queue).
nonisolated final class FlashProgressReceiver: NSObject, FlashProgressReceiverProtocol, @unchecked Sendable {
    private let handler = OSAllocatedUnfairLock<(@Sendable (Int64, Int64) -> Void)?>(initialState: nil)

    func setHandler(_ newHandler: (@Sendable (Int64, Int64) -> Void)?) {
        handler.withLock { $0 = newHandler }
    }

    func flashProgress(bytesDone: Int64, bytesTotal: Int64) {
        let current = handler.withLock { $0 }
        current?(bytesDone, bytesTotal)
    }
}

nonisolated final class PrivilegedHelperClient: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: ConnectionBox())
    private let receiver = FlashProgressReceiver()

    // MARK: - Installation

    /// Makes sure the helper daemon is registered and approved.
    ///
    /// The first call registers the daemon and the user has to allow it once in
    /// System Settings → General → Login Items & Extensions.
    func ensureHelperEnabled() throws {
        let service = SMAppService.daemon(plistName: FlashHelperConstants.daemonPlistName)

        if service.status == .notRegistered || service.status == .notFound {
            do {
                try service.register()
            } catch {
                // `register()` also throws while approval is pending; the status check below decides.
                if service.status != .requiresApproval && service.status != .enabled {
                    throw FlashError.flashFailed(
                        "Could not register the privileged helper: \(error.localizedDescription)")
                }
            }
        }

        switch service.status {
        case .enabled:
            return
        case .requiresApproval:
            SMAppService.openSystemSettingsLoginItems()
            throw FlashError.flashFailed(
                "Allow the SwiftFlash helper in System Settings → General → Login Items & Extensions, then try again."
            )
        case .notFound:
            throw FlashError.flashFailed("The privileged helper is missing from the app bundle")
        case .notRegistered:
            throw FlashError.flashFailed("The privileged helper could not be registered")
        @unknown default:
            throw FlashError.flashFailed("The privileged helper is in an unknown state")
        }
    }

    // MARK: - Operations

    /// Writes `imageHandle` (`imageSize` bytes) to the raw device. `onProgress` receives (done, total) bytes.
    func writeImage(
        _ imageHandle: FileHandle,
        imageSize: Int64,
        devicePath: String,
        onProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        receiver.setHandler(onProgress)
        defer { receiver.setHandler(nil) }
        try await perform { proxy, reply in
            proxy.writeImage(imageHandle, imageSize: imageSize, toDevice: devicePath, reply: reply)
        }
    }

    /// Compares the raw device with `imageHandle`.
    func verifyImage(
        _ imageHandle: FileHandle,
        imageSize: Int64,
        devicePath: String
    ) async throws {
        try await perform { proxy, reply in
            proxy.verifyImage(imageHandle, imageSize: imageSize, onDevice: devicePath, reply: reply)
        }
    }

    /// Asks the helper to stop the running operation.
    func cancel() {
        guard let connection = lock.withLock({ $0 }).connection else { return }
        let proxy = connection.remoteObjectProxy as? FlashHelperProtocol
        proxy?.cancelOperation {}
    }

    // MARK: - XPC plumbing

    private func perform(
        _ call: @escaping @Sendable (FlashHelperProtocol, @escaping (String?) -> Void) -> Void
    ) async throws {
        guard let connection = activeConnection().connection else {
            throw FlashError.flashFailed("Could not connect to the privileged helper")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = OnceGuard()
            let finish: @Sendable (String?, Error?) -> Void = { message, error in
                guard once.claim() else { return }
                if let message {
                    continuation.resume(throwing: FlashError.flashFailed(message))
                } else if let error {
                    continuation.resume(
                        throwing: FlashError.flashFailed(
                            "Lost connection to the privileged helper: \(error.localizedDescription)"))
                } else {
                    continuation.resume()
                }
            }

            guard
                let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                    finish(nil, error)
                }) as? FlashHelperProtocol
            else {
                finish("Could not create the helper proxy", nil)
                return
            }
            call(proxy) { message in finish(message, nil) }
        }
    }

    private func activeConnection() -> ConnectionBox {
        lock.withLock { current -> ConnectionBox in
            if current.connection != nil { return current }

            let connection = NSXPCConnection(
                machServiceName: FlashHelperConstants.helperIdentifier, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: FlashHelperProtocol.self)
            connection.exportedInterface = NSXPCInterface(with: FlashProgressReceiverProtocol.self)
            connection.exportedObject = receiver
            // Only talk to our own, correctly signed helper.
            connection.setCodeSigningRequirement(FlashHelperConstants.helperRequirement)
            connection.invalidationHandler = { [weak self] in self?.forgetConnection() }
            connection.interruptionHandler = { [weak self] in self?.forgetConnection() }
            connection.resume()
            current.connection = connection
            return current
        }
    }

    private func forgetConnection() {
        lock.withLock { $0.connection = nil }
    }
}

/// `NSXPCConnection` is not `Sendable`; access is serialized by the client's lock.
private nonisolated struct ConnectionBox: @unchecked Sendable {
    var connection: NSXPCConnection?
}

/// Guarantees a continuation is resumed exactly once.
private nonisolated final class OnceGuard: @unchecked Sendable {
    private let claimed = OSAllocatedUnfairLock(initialState: false)

    func claim() -> Bool {
        claimed.withLock { done in
            if done { return false }
            done = true
            return true
        }
    }
}
