//
//  ImageFile+Compression.swift
//  SwiftFlash
//
//  Support for compressed images (`.img.xz`) without touching the core `ImageFile` model.
//

import Foundation
import os

extension ImageFile {
    /// `true` for `.xz` compressed images; they are decompressed to a temporary file before flashing.
    var isCompressed: Bool {
        URL(fileURLWithPath: path).pathExtension.lowercased() == "xz"
    }

    /// Size after decompression, read from the xz index. `nil` if the file is not a complete
    /// single-stream xz file. Only meaningful for compressed images.
    ///
    /// The result is cached per path and file size, so views can call this on every update.
    func uncompressedSize() -> Int64? {
        guard isCompressed else { return nil }

        let cacheKey = "\(path)|\(size)"
        if let cached = UncompressedSizeCache.value(for: cacheKey) { return cached }

        guard let url = try? getSecureURL() else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let result = XZImageDecompressor.uncompressedSize(of: url) else { return nil }
        UncompressedSizeCache.store(result, for: cacheKey)
        return result
    }

    /// Number of bytes that end up on the device: the uncompressed size for compressed images,
    /// otherwise the file size. Falls back to `size` if the uncompressed size is unknown
    /// (flashing such a file fails later with a clear error).
    func flashSize() -> Int64 {
        uncompressedSize() ?? size
    }

    /// Human-readable `flashSize()`, formatted like `formattedSize`.
    var formattedFlashSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: flashSize())
    }
}

private nonisolated enum UncompressedSizeCache {
    private static let storage = OSAllocatedUnfairLock(initialState: [String: Int64]())

    static func value(for key: String) -> Int64? {
        storage.withLock { $0[key] }
    }

    static func store(_ value: Int64, for key: String) {
        storage.withLock { $0[key] = value }
    }
}
