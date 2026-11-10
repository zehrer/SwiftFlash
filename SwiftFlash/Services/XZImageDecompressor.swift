//
//  XZImageDecompressor.swift
//  SwiftFlash
//
//  Decompresses `.xz` disk images (e.g. `raspios.img.xz`) with the system Compression
//  framework, so no external `xz` tool is needed.
//

import Compression
import Foundation

nonisolated enum XZImageDecompressor {
    enum Failure: LocalizedError {
        case cancelled
        case corrupt(String)

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Flash operation was cancelled"
            case .corrupt(let reason):
                return reason
            }
        }
    }

    static func isXZ(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "xz"
    }

    // MARK: - Uncompressed size

    /// Total uncompressed size, read from the xz index at the end of the file (no decompression).
    ///
    /// Returns `nil` if the file is not a single, complete xz stream, e.g. when the download
    /// was truncated (no stream footer) or several streams were concatenated.
    static func uncompressedSize(of url: URL) -> Int64? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let footerSize: UInt64 = 12
        guard let end = try? handle.seekToEnd(), end >= footerSize + 24 else { return nil }

        // Stream footer: CRC32 (4) | backward size (4) | stream flags (2) | magic "YZ" (2)
        guard (try? handle.seek(toOffset: end - footerSize)) != nil,
            let footerData = try? handle.read(upToCount: Int(footerSize)),
            footerData.count == Int(footerSize)
        else { return nil }
        let footer = [UInt8](footerData)
        guard footer[10] == 0x59, footer[11] == 0x5A else { return nil }

        let backwardSize = UInt64(footer[4]) | UInt64(footer[5]) << 8
            | UInt64(footer[6]) << 16 | UInt64(footer[7]) << 24
        let indexSize = (backwardSize + 1) * 4
        guard indexSize <= 64 * 1024 * 1024, indexSize + footerSize <= end else { return nil }

        guard (try? handle.seek(toOffset: end - footerSize - indexSize)) != nil,
            let indexData = try? handle.read(upToCount: Int(indexSize)),
            indexData.count == Int(indexSize)
        else { return nil }
        let index = [UInt8](indexData)

        // Index: 0x00 | record count | (unpadded size, uncompressed size)* | padding | CRC32
        guard index.first == 0x00 else { return nil }
        var position = 1
        guard let recordCount = readVarint(index, &position) else { return nil }

        var total: UInt64 = 0
        for _ in 0..<recordCount {
            guard readVarint(index, &position) != nil,
                let uncompressed = readVarint(index, &position)
            else { return nil }
            let (sum, overflow) = total.addingReportingOverflow(uncompressed)
            guard !overflow else { return nil }
            total = sum
        }
        return Int64(exactly: total)
    }

    /// xz variable-length integer: 7 bits per byte, little endian, high bit = more bytes.
    private static func readVarint(_ bytes: [UInt8], _ position: inout Int) -> UInt64? {
        var value: UInt64 = 0
        for shift in stride(from: 0, to: 63, by: 7) {
            guard position < bytes.count else { return nil }
            let byte = bytes[position]
            position += 1
            value |= UInt64(byte & 0x7F) << UInt64(shift)
            if byte & 0x80 == 0 { return value }
        }
        return nil
    }

    // MARK: - Decompression

    /// Decompresses `source` into `destination` and returns the number of bytes written.
    ///
    /// - Parameters:
    ///   - progress: Called with a fraction (0…1) of the compressed input consumed, at most once per percent.
    ///   - isCancelled: Polled between chunks.
    /// - Throws: `Failure` for cancellation and corrupt or truncated input, or I/O errors.
    static func decompress(
        from source: URL,
        to destination: URL,
        progress: @Sendable (Double) -> Void,
        isCancelled: @Sendable () -> Bool
    ) throws -> Int64 {
        // Also rejects truncated downloads: the footer/index is missing, so the size is unknown.
        guard let expectedSize = uncompressedSize(of: source) else {
            throw Failure.corrupt(
                "The .xz file is incomplete or damaged (stream index not found). Download it again.")
        }

        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let compressedSize = Double(try input.seekToEnd())
        try input.seek(toOffset: 0)

        guard
            FileManager.default.createFile(
                atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600])
        else {
            throw Failure.corrupt("Could not create a temporary file for the decompressed image")
        }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        var written: Int64 = 0
        var lastPercent = -1

        do {
            let filter = try InputFilter(.decompress, using: .lzma) { length -> Data? in
                try input.read(upToCount: length)
            }
            while let chunk = try filter.readData(ofLength: 4 * 1024 * 1024), !chunk.isEmpty {
                if isCancelled() { throw Failure.cancelled }
                try output.write(contentsOf: chunk)
                written += Int64(chunk.count)

                let consumed = Double((try? input.offset()) ?? 0)
                let percent = compressedSize > 0 ? Int(min(consumed / compressedSize, 1.0) * 100) : 0
                if percent != lastPercent {
                    lastPercent = percent
                    progress(Double(percent) / 100)
                }
            }
        } catch let failure as Failure {
            throw failure
        } catch let error as CocoaError where error.code == .fileWriteOutOfSpace {
            throw error
        } catch {
            throw Failure.corrupt("The .xz file is damaged: \(error.localizedDescription)")
        }

        guard written == expectedSize else {
            throw Failure.corrupt(
                "The .xz file is damaged: expected \(expectedSize) bytes, got \(written)")
        }
        progress(1.0)
        return written
    }
}
