//
//  ImageFile+Compression.swift
//  SwiftFlash
//
//  Support for compressed images (`.img.xz`) without touching the core `ImageFile` model.
//

import Foundation

extension ImageFile {
    /// `true` for `.xz` compressed images; they are decompressed to a temporary file before flashing.
    var isCompressed: Bool {
        URL(fileURLWithPath: path).pathExtension.lowercased() == "xz"
    }

    /// Number of bytes that end up on the device: the uncompressed size for compressed images
    /// (read from the xz index), otherwise the file size. Falls back to `size` if unknown.
    func flashSize() -> Int64 {
        guard isCompressed, let url = try? getSecureURL() else { return size }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return XZImageDecompressor.uncompressedSize(of: url) ?? size
    }
}
