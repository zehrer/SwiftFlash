//
//  FlashHelperService.swift
//  SwiftFlashHelper
//
//  Implements the privileged disk operations. Runs as root.
//

import DiskArbitration
import Foundation
import os

struct HelperError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

final class FlashHelperService: NSObject, FlashHelperProtocol {
    private weak var connection: NSXPCConnection?
    private let cancelRequested = OSAllocatedUnfairLock(initialState: false)
    private let operationRunning = OSAllocatedUnfairLock(initialState: false)
    private let workQueue = DispatchQueue(
        label: "xyz.zehrer.SwiftFlash.helper.work", qos: .userInitiated)

    /// Raw device I/O must be sector aligned; 4 KiB covers 512e and 4Kn media.
    private let alignment = 4096
    private let chunkSize = 1024 * 1024

    init(connection: NSXPCConnection) {
        self.connection = connection
    }

    // MARK: - FlashHelperProtocol

    func writeImage(
        _ image: FileHandle,
        imageSize: Int64,
        toDevice devicePath: String,
        reply: @escaping (String?) -> Void
    ) {
        runOperation(reply: reply) {
            let bsdName = try self.validateTarget(devicePath: devicePath, imageSize: imageSize)
            try self.unmountDisk(bsdName: bsdName)
            try self.write(image: image, imageSize: imageSize, devicePath: devicePath)
        }
    }

    func verifyImage(
        _ image: FileHandle,
        imageSize: Int64,
        onDevice devicePath: String,
        reply: @escaping (String?) -> Void
    ) {
        runOperation(reply: reply) {
            _ = try self.validateTarget(devicePath: devicePath, imageSize: imageSize)
            try self.verify(image: image, imageSize: imageSize, devicePath: devicePath)
        }
    }

    func cancelOperation(reply: @escaping () -> Void) {
        cancelRequested.withLock { $0 = true }
        reply()
    }

    // MARK: - Operation plumbing

    /// Runs `work` on a background queue (so `cancelOperation` can be served meanwhile)
    /// and converts the outcome into the XPC reply.
    private func runOperation(reply: @escaping (String?) -> Void, work: @escaping () throws -> Void) {
        let claimed = operationRunning.withLock { running -> Bool in
            if running { return false }
            running = true
            return true
        }
        guard claimed else {
            reply("Another flash operation is already running")
            return
        }
        cancelRequested.withLock { $0 = false }

        workQueue.async {
            defer { self.operationRunning.withLock { $0 = false } }
            do {
                try work()
                reply(nil)
            } catch let error as HelperError {
                reply(error.message)
            } catch {
                reply("\(error.localizedDescription)")
            }
        }
    }

    private func reportProgress(done: Int64, total: Int64) {
        let receiver = connection?.remoteObjectProxy as? FlashProgressReceiverProtocol
        receiver?.flashProgress(bytesDone: done, bytesTotal: total)
    }

    private func throwIfCancelled() throws {
        if cancelRequested.withLock({ $0 }) {
            throw HelperError("Flash operation was cancelled")
        }
    }

    // MARK: - Safety checks

    /// Refuses everything that is not an external/removable whole disk large enough for the image.
    /// Returns the BSD name (e.g. `disk4`).
    private func validateTarget(devicePath: String, imageSize: Int64) throws -> String {
        guard devicePath.range(of: #"^/dev/rdisk[0-9]+$"#, options: .regularExpression) != nil
        else {
            throw HelperError("Refusing to write to \(devicePath): not a raw whole-disk device")
        }
        let bsdName = String(devicePath.dropFirst("/dev/r".count))

        guard let session = DASessionCreate(kCFAllocatorDefault),
            let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName),
            let description = DADiskCopyDescription(disk) as? [String: Any]
        else {
            throw HelperError("Could not read disk description for \(bsdName)")
        }

        func flag(_ key: CFString) -> Bool {
            (description[key as String] as? NSNumber)?.boolValue ?? false
        }

        guard flag(kDADiskDescriptionMediaWholeKey) else {
            throw HelperError("\(bsdName) is not a whole disk")
        }
        guard flag(kDADiskDescriptionMediaWritableKey) else {
            throw HelperError("\(bsdName) is read-only")
        }
        // Internal system disks are neither removable nor ejectable.
        guard flag(kDADiskDescriptionMediaRemovableKey) || flag(kDADiskDescriptionMediaEjectableKey)
        else {
            throw HelperError("Refusing to write to \(bsdName): not a removable or ejectable disk")
        }
        let mediaSize =
            (description[kDADiskDescriptionMediaSizeKey as String] as? NSNumber)?.int64Value ?? 0
        guard imageSize > 0, imageSize <= mediaSize else {
            throw HelperError("Image does not fit on \(bsdName)")
        }
        return bsdName
    }

    private func unmountDisk(bsdName: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmountDisk", "force", "/dev/\(bsdName)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw HelperError("Could not run diskutil: \(error.localizedDescription)")
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw HelperError("Failed to unmount /dev/\(bsdName)")
        }
    }

    // MARK: - Write / verify

    private func write(image: FileHandle, imageSize: Int64, devicePath: String) throws {
        let imageFD = image.fileDescriptor
        guard lseek(imageFD, 0, SEEK_SET) == 0 else {
            throw HelperError("Cannot rewind image file: \(errnoMessage())")
        }

        let deviceFD = open(devicePath, O_RDWR)
        guard deviceFD >= 0 else {
            throw HelperError("Cannot open \(devicePath) for writing: \(errnoMessage())")
        }
        defer { close(deviceFD) }
        _ = fcntl(deviceFD, F_NOCACHE, 1)

        let buffer = try AlignedBuffer(size: chunkSize, alignment: alignment)
        var done: Int64 = 0
        var lastReport = ContinuousClock.now
        reportProgress(done: 0, total: imageSize)

        while done < imageSize {
            try throwIfCancelled()

            let want = Int(min(Int64(chunkSize), imageSize - done))
            let got = try readFully(fd: imageFD, into: buffer.pointer, count: want)
            guard got == want else {
                throw HelperError("Image file ended unexpectedly")
            }

            // Pad the final chunk with zeros up to the next sector boundary.
            let padded = (want + alignment - 1) / alignment * alignment
            if padded > want {
                memset(buffer.pointer + want, 0, padded - want)
            }
            try writeFully(fd: deviceFD, from: buffer.pointer, count: padded)

            done += Int64(want)
            if ContinuousClock.now - lastReport >= .milliseconds(250) {
                reportProgress(done: done, total: imageSize)
                lastReport = .now
            }
        }

        _ = fcntl(deviceFD, F_FULLFSYNC)
        reportProgress(done: imageSize, total: imageSize)
    }

    private func verify(image: FileHandle, imageSize: Int64, devicePath: String) throws {
        let imageFD = image.fileDescriptor
        guard lseek(imageFD, 0, SEEK_SET) == 0 else {
            throw HelperError("Cannot rewind image file: \(errnoMessage())")
        }

        let deviceFD = open(devicePath, O_RDONLY)
        guard deviceFD >= 0 else {
            throw HelperError("Cannot open \(devicePath) for reading: \(errnoMessage())")
        }
        defer { close(deviceFD) }
        _ = fcntl(deviceFD, F_NOCACHE, 1)

        let imageBuffer = try AlignedBuffer(size: chunkSize, alignment: alignment)
        let deviceBuffer = try AlignedBuffer(size: chunkSize, alignment: alignment)
        var done: Int64 = 0
        var lastReport = ContinuousClock.now

        while done < imageSize {
            try throwIfCancelled()

            let want = Int(min(Int64(chunkSize), imageSize - done))
            guard try readFully(fd: imageFD, into: imageBuffer.pointer, count: want) == want else {
                throw HelperError("Image file ended unexpectedly")
            }
            let padded = (want + alignment - 1) / alignment * alignment
            guard try readFully(fd: deviceFD, into: deviceBuffer.pointer, count: padded) >= want
            else {
                throw HelperError("Device returned less data than expected")
            }
            guard memcmp(imageBuffer.pointer, deviceBuffer.pointer, want) == 0 else {
                throw HelperError("Verification failed: data mismatch near byte \(done)")
            }

            done += Int64(want)
            if ContinuousClock.now - lastReport >= .milliseconds(250) {
                reportProgress(done: done, total: imageSize)
                lastReport = .now
            }
        }
        reportProgress(done: imageSize, total: imageSize)
    }

    // MARK: - POSIX helpers

    private func errnoMessage() -> String {
        String(cString: strerror(errno))
    }

    /// Reads until `count` bytes arrived or EOF. Returns the number of bytes read.
    private func readFully(fd: Int32, into pointer: UnsafeMutableRawPointer, count: Int) throws -> Int {
        var total = 0
        while total < count {
            let n = read(fd, pointer + total, count - total)
            if n < 0 {
                if errno == EINTR { continue }
                throw HelperError("Read failed: \(errnoMessage())")
            }
            if n == 0 { break }
            total += n
        }
        return total
    }

    private func writeFully(fd: Int32, from pointer: UnsafeRawPointer, count: Int) throws {
        var total = 0
        while total < count {
            let n = Foundation.write(fd, pointer + total, count - total)
            if n < 0 {
                if errno == EINTR { continue }
                throw HelperError("Write failed: \(errnoMessage())")
            }
            total += n
        }
    }
}

/// Page-aligned heap buffer, required for raw device I/O.
private final class AlignedBuffer {
    let pointer: UnsafeMutableRawPointer

    init(size: Int, alignment: Int) throws {
        var raw: UnsafeMutableRawPointer?
        guard posix_memalign(&raw, alignment, size) == 0, let raw else {
            throw HelperError("Out of memory")
        }
        pointer = raw
    }

    deinit { free(pointer) }
}
