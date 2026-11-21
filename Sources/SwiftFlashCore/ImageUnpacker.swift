import Compression
import CryptoKit
import Foundation

/// Unpacks compressed images (`.xz`, `.gz`, `.zip`) with the `Compression` framework, streaming in 4 MiB chunks.
/// The SHA-256 of the unpacked image is computed on the way, so a published checksum costs no extra pass.
enum ImageUnpacker {
    typealias Progress = (_ consumedBytes: Int64, _ totalBytes: Int64, _ producedBytes: Int64) -> Void

    struct Result {
        var url: URL
        /// SHA-256 (hex) of the unpacked image.
        var sha256: String
    }

    static let chunkSize = 4 * 1024 * 1024

    /// Unpacks `source` into `directory`; the file name comes from the archive (`disk.img.gz` → `disk.img`).
    static func unpack(_ source: URL, into directory: URL, progress: Progress) throws -> Result {
        switch source.pathExtension.lowercased() {
        case "xz":
            let destination = directory.appendingPathComponent(unpackedName(for: source))
            return Result(url: destination, sha256: try unxz(source, to: destination, progress: progress))
        case "gz":
            let destination = directory.appendingPathComponent(unpackedName(for: source))
            return Result(url: destination, sha256: try gunzip(source, to: destination, progress: progress))
        case "zip":
            return try unzip(source, into: directory, progress: progress)
        default:
            throw FlashError.invalidImage("Unsupported compression: \(source.lastPathComponent)")
        }
    }

    /// `disk.img.xz` → `disk.img`; a name without image extension gets `.img`.
    static func unpackedName(for source: URL) -> String {
        let base = source.deletingPathExtension()
        return ImageSupport.supportedExtensions.contains(base.pathExtension.lowercased())
            ? base.lastPathComponent
            : base.lastPathComponent + ".img"
    }

    // MARK: - xz

    static func unxz(_ source: URL, to destination: URL, progress: Progress) throws -> String {
        let reader = try ChunkReader(url: source)
        // xz carries its own integrity checks, which the decoder verifies.
        let sink = try OutputSink(url: destination, computeCRC: false)
        try decode(COMPRESSION_LZMA, from: reader, limit: nil, into: sink, name: source.lastPathComponent) {
            progress(reader.consumed, reader.totalSize, sink.produced)
        }
        progress(reader.totalSize, reader.totalSize, sink.produced)
        return sink.finish()
    }

    // MARK: - gzip (RFC 1952)

    static func gunzip(_ source: URL, to destination: URL, progress: Progress) throws -> String {
        let reader = try ChunkReader(url: source)
        let sink = try OutputSink(url: destination)
        let name = source.lastPathComponent

        guard try reader.read(exactly: 2) == Data([0x1F, 0x8B]) else {
            throw FlashError.invalidImage("Not a gzip file: \(name)")
        }
        try skipGzipHeader(reader, name: name)
        // The decoder also swallows bytes after the end of the deflate data, so it only gets the data up to the
        // 8-byte trailer (CRC-32 and size), which is read from the end of the file.
        let deflateLength = reader.totalSize - reader.consumed - 8
        guard deflateLength > 0 else {
            throw FlashError.invalidImage("Compressed image is truncated: \(name)")
        }
        try decode(COMPRESSION_ZLIB, from: reader, limit: deflateLength, into: sink, name: name) {
            progress(reader.consumed, reader.totalSize, sink.produced)
        }
        try reader.seek(to: UInt64(reader.totalSize - 8))
        let trailer = try reader.read(exactly: 8)
        guard sink.crc?.value == trailer.littleEndian(UInt32.self, at: 0),
              UInt32(truncatingIfNeeded: sink.produced) == trailer.littleEndian(UInt32.self, at: 4)
        else {
            throw FlashError.invalidImage(
                "gzip checksum mismatch in \(name) (damaged, or several gzip members, which are not supported)"
            )
        }
        progress(reader.totalSize, reader.totalSize, sink.produced)
        return sink.finish()
    }

    private static func skipGzipHeader(_ reader: ChunkReader, name: String) throws {
        let header = try reader.read(exactly: 8) // method, flags, mtime(4), xfl, os
        guard header[0] == 8 else {
            throw FlashError.invalidImage("Unsupported gzip compression method in \(name)")
        }
        let flags = header[1]
        if flags & 0x04 != 0 { // FEXTRA
            let length = try reader.read(exactly: 2).littleEndian(UInt16.self, at: 0)
            _ = try reader.read(exactly: Int(length))
        }
        if flags & 0x08 != 0 { try reader.skipZeroTerminated() } // FNAME
        if flags & 0x10 != 0 { try reader.skipZeroTerminated() } // FCOMMENT
        if flags & 0x02 != 0 { _ = try reader.read(exactly: 2) } // FHCRC
    }

    // MARK: - zip (single image entry, Zip64 aware)

    struct ZipEntry: Equatable {
        var name: String
        var method: UInt16
        var crc32: UInt32
        var compressedSize: UInt64
        var uncompressedSize: UInt64
        var localHeaderOffset: UInt64
    }

    static func unzip(_ source: URL, into directory: URL, progress: Progress) throws -> Result {
        let name = source.lastPathComponent
        let entries = try zipEntries(of: source)
        let entry = try imageEntry(in: entries, archiveName: name)
        guard entry.method == 0 || entry.method == 8 else {
            throw FlashError.invalidImage("Unsupported zip compression (method \(entry.method)) in \(name)")
        }

        let reader = try ChunkReader(url: source)
        try reader.seek(to: entry.localHeaderOffset)
        let local = try reader.read(exactly: 30)
        guard local.littleEndian(UInt32.self, at: 0) == 0x0403_4B50 else {
            throw FlashError.invalidImage("Damaged zip file: \(name)")
        }
        let nameLength = Int(local.littleEndian(UInt16.self, at: 26))
        let extraLength = Int(local.littleEndian(UInt16.self, at: 28))
        _ = try reader.read(exactly: nameLength + extraLength)

        let entryFileName = URL(fileURLWithPath: entry.name).lastPathComponent
        let outputName = ImageSupport.supportedExtensions.contains(URL(fileURLWithPath: entryFileName).pathExtension.lowercased())
            ? entryFileName
            : unpackedName(for: source)
        let destination = directory.appendingPathComponent(outputName)
        let sink = try OutputSink(url: destination)
        func report() { progress(reader.consumed, reader.totalSize, sink.produced) }
        if entry.method == 8 {
            try decode(COMPRESSION_ZLIB, from: reader, limit: Int64(entry.compressedSize), into: sink, name: name, onChunk: report)
        } else {
            var remaining = Int64(entry.compressedSize)
            while remaining > 0 {
                let chunk = try reader.read(upTo: Int(min(remaining, Int64(chunkSize))))
                guard !chunk.isEmpty else {
                    throw FlashError.invalidImage("zip file is truncated: \(name)")
                }
                try sink.write(chunk)
                remaining -= Int64(chunk.count)
                report()
            }
        }
        guard UInt64(sink.produced) == entry.uncompressedSize, sink.crc?.value == entry.crc32 else {
            throw FlashError.invalidImage("zip checksum mismatch for \(entry.name) in \(name)")
        }
        progress(reader.totalSize, reader.totalSize, sink.produced)
        return Result(url: destination, sha256: sink.finish())
    }

    /// The entry to flash: the only `.img`/`.iso` file, or the only file at all.
    static func imageEntry(in entries: [ZipEntry], archiveName: String) throws -> ZipEntry {
        let files = entries.filter { !$0.name.hasSuffix("/") && !$0.name.hasPrefix("__MACOSX/") }
        let images = files.filter {
            ImageSupport.supportedExtensions.contains(URL(fileURLWithPath: $0.name).pathExtension.lowercased())
        }
        if images.count == 1 {
            return images[0]
        }
        if images.isEmpty, files.count == 1 {
            return files[0]
        }
        if images.count > 1 {
            throw FlashError.invalidImage(
                "\(archiveName) contains several images (\(images.map(\.name).joined(separator: ", "))); unpack it and flash one"
            )
        }
        throw FlashError.invalidImage("\(archiveName) contains no .img or .iso image")
    }

    /// Reads the central directory, including Zip64 sizes and offsets.
    static func zipEntries(of url: URL) throws -> [ZipEntry] {
        let name = url.lastPathComponent
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()

        // End of central directory: 22 bytes plus a comment of up to 64 KiB at the very end.
        let tailLength = min(fileSize, 22 + 65_535 + 20)
        try handle.seek(toOffset: fileSize - tailLength)
        let tail = try handle.read(upToCount: Int(tailLength)) ?? Data()
        guard let eocd = tail.lastIndex(ofSignature: 0x0605_4B50, from: tail.count - 22) else {
            throw FlashError.invalidImage("Not a zip file: \(name)")
        }
        var entryCount = UInt64(tail.littleEndian(UInt16.self, at: eocd + 10))
        var directorySize = UInt64(tail.littleEndian(UInt32.self, at: eocd + 12))
        var directoryOffset = UInt64(tail.littleEndian(UInt32.self, at: eocd + 16))

        // Zip64: a locator right before the EOCD points to the Zip64 end record with the real values.
        if eocd >= 20, tail.littleEndian(UInt32.self, at: eocd - 20) == 0x0706_4B50 {
            let zip64Offset = tail.littleEndian(UInt64.self, at: eocd - 20 + 8)
            try handle.seek(toOffset: zip64Offset)
            let record = try handle.read(upToCount: 56) ?? Data()
            guard record.count == 56, record.littleEndian(UInt32.self, at: 0) == 0x0606_4B50 else {
                throw FlashError.invalidImage("Damaged zip64 file: \(name)")
            }
            entryCount = record.littleEndian(UInt64.self, at: 32)
            directorySize = record.littleEndian(UInt64.self, at: 40)
            directoryOffset = record.littleEndian(UInt64.self, at: 48)
        }
        guard directoryOffset + directorySize <= fileSize, directorySize < 64 * 1024 * 1024 else {
            throw FlashError.invalidImage("Damaged zip file: \(name)")
        }

        try handle.seek(toOffset: directoryOffset)
        let directory = try handle.read(upToCount: Int(directorySize)) ?? Data()
        var entries: [ZipEntry] = []
        var position = 0
        for _ in 0..<entryCount {
            guard position + 46 <= directory.count,
                  directory.littleEndian(UInt32.self, at: position) == 0x0201_4B50
            else {
                throw FlashError.invalidImage("Damaged zip directory: \(name)")
            }
            let nameLength = Int(directory.littleEndian(UInt16.self, at: position + 28))
            let extraLength = Int(directory.littleEndian(UInt16.self, at: position + 30))
            let commentLength = Int(directory.littleEndian(UInt16.self, at: position + 32))
            let nameStart = position + 46
            guard nameStart + nameLength + extraLength + commentLength <= directory.count else {
                throw FlashError.invalidImage("Damaged zip directory: \(name)")
            }
            var entry = ZipEntry(
                name: String(decoding: directory[(directory.startIndex + nameStart)..<(directory.startIndex + nameStart + nameLength)], as: UTF8.self),
                method: directory.littleEndian(UInt16.self, at: position + 10),
                crc32: directory.littleEndian(UInt32.self, at: position + 16),
                compressedSize: UInt64(directory.littleEndian(UInt32.self, at: position + 20)),
                uncompressedSize: UInt64(directory.littleEndian(UInt32.self, at: position + 24)),
                localHeaderOffset: UInt64(directory.littleEndian(UInt32.self, at: position + 42))
            )
            applyZip64Extra(directory, from: nameStart + nameLength, length: extraLength, to: &entry)
            entries.append(entry)
            position = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    /// Replaces 0xFFFFFFFF placeholders with the values from the Zip64 extra field (header id 1).
    private static func applyZip64Extra(_ data: Data, from start: Int, length: Int, to entry: inout ZipEntry) {
        var position = start
        while position + 4 <= start + length {
            let id = data.littleEndian(UInt16.self, at: position)
            let size = Int(data.littleEndian(UInt16.self, at: position + 2))
            var field = position + 4
            let end = field + size
            if id == 0x0001 {
                if entry.uncompressedSize == 0xFFFF_FFFF, field + 8 <= end {
                    entry.uncompressedSize = data.littleEndian(UInt64.self, at: field)
                    field += 8
                }
                if entry.compressedSize == 0xFFFF_FFFF, field + 8 <= end {
                    entry.compressedSize = data.littleEndian(UInt64.self, at: field)
                    field += 8
                }
                if entry.localHeaderOffset == 0xFFFF_FFFF, field + 8 <= end {
                    entry.localHeaderOffset = data.littleEndian(UInt64.self, at: field)
                }
                return
            }
            position = end
        }
    }

    // MARK: - Shared stream decoding

    /// Runs one compressed stream through `compression_stream` until its end marker. With a `limit`, at most that
    /// many input bytes are read; input after the end marker is handed back to the reader (gzip trailers).
    private static func decode(
        _ algorithm: compression_algorithm,
        from reader: ChunkReader,
        limit: Int64?,
        into sink: OutputSink,
        name: String,
        onChunk: () -> Void
    ) throws {
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }
        guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, algorithm) == COMPRESSION_STATUS_OK else {
            throw FlashError.invalidImage("Could not initialize decoder for \(name)")
        }
        defer { compression_stream_destroy(stream) }

        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { destination.deallocate() }
        var input = Data()
        var inputOffset = 0
        var remaining = limit
        var endOfInput = false

        while true {
            if inputOffset == input.count && !endOfInput {
                let wanted = remaining.map { Int(min($0, Int64(chunkSize))) } ?? chunkSize
                input = wanted > 0 ? try reader.read(upTo: wanted) : Data()
                inputOffset = 0
                remaining = remaining.map { $0 - Int64(input.count) }
                endOfInput = input.isEmpty
                onChunk()
            }

            let (status, consumedInput, produced): (compression_status, Int, Int) = input.withUnsafeBytes { buffer in
                let base = buffer.bindMemory(to: UInt8.self).baseAddress
                stream.pointee.src_ptr = base.map { UnsafePointer($0 + inputOffset) } ?? UnsafePointer(destination)
                stream.pointee.src_size = input.count - inputOffset
                stream.pointee.dst_ptr = destination
                stream.pointee.dst_size = chunkSize
                let flags = endOfInput ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                let status = compression_stream_process(stream, flags)
                return (status, input.count - inputOffset - stream.pointee.src_size, chunkSize - stream.pointee.dst_size)
            }
            inputOffset += consumedInput
            if produced > 0 {
                try sink.write(Data(bytes: destination, count: produced))
            }

            switch status {
            case COMPRESSION_STATUS_END:
                if inputOffset < input.count {
                    reader.unread(input.subdata(in: (input.startIndex + inputOffset)..<input.endIndex))
                }
                return
            case COMPRESSION_STATUS_OK:
                if endOfInput && produced == 0 {
                    throw FlashError.invalidImage("Compressed image is truncated: \(name)")
                }
            default:
                throw FlashError.invalidImage("Could not decompress \(name)")
            }
        }
    }
}

/// Reads a file in chunks and allows handing bytes back (for data after the end of a compressed stream).
final class ChunkReader {
    private let handle: FileHandle
    private var pending = Data()
    let totalSize: Int64
    private var position: Int64 = 0

    /// Bytes taken from the file so far (minus bytes handed back), for progress.
    var consumed: Int64 { position - Int64(pending.count) }

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        totalSize = max(size, 1)
    }

    deinit {
        try? handle.close()
    }

    func seek(to offset: UInt64) throws {
        try handle.seek(toOffset: offset)
        pending = Data()
        position = Int64(offset)
    }

    func read(upTo count: Int) throws -> Data {
        if !pending.isEmpty {
            let chunk = pending.prefix(count)
            pending = pending.dropFirst(chunk.count)
            return Data(chunk)
        }
        let chunk = try handle.read(upToCount: count) ?? Data()
        position += Int64(chunk.count)
        return chunk
    }

    func read(exactly count: Int) throws -> Data {
        var result = Data()
        while result.count < count {
            let chunk = try read(upTo: count - result.count)
            if chunk.isEmpty {
                throw FlashError.invalidImage("Compressed image is truncated")
            }
            result.append(chunk)
        }
        return result
    }

    func skipZeroTerminated() throws {
        while try read(exactly: 1)[0] != 0 {}
    }

    func unread(_ data: Data) {
        pending = data + pending
    }
}

/// Writes the unpacked image and computes SHA-256 and CRC-32 on the way.
final class OutputSink {
    private let handle: FileHandle
    private var hasher = SHA256()
    /// CRC-32 of the data written since it was last reset; nil when not needed.
    var crc: CRC32?
    private(set) var produced: Int64 = 0

    init(url: URL, computeCRC: Bool = true) throws {
        crc = computeCRC ? CRC32() : nil
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw FlashError.ioFailed("Could not create \(url.path)")
        }
        handle = try FileHandle(forWritingTo: url)
    }

    deinit {
        try? handle.close()
    }

    func write(_ data: Data) throws {
        hasher.update(data: data)
        crc?.update(data)
        try handle.write(contentsOf: data)
        produced += Int64(data.count)
    }

    func finish() -> String {
        try? handle.close()
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// CRC-32 (IEEE 802.3), as used by gzip and zip. Uses slicing-by-8 (eight bytes per step) so checking a
/// multi-GB image does not slow down unpacking noticeably.
struct CRC32 {
    private static let tables: [UInt32] = {
        var tables = [UInt32](repeating: 0, count: 8 * 256)
        for index in 0..<256 {
            var value = UInt32(index)
            for _ in 0..<8 {
                value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
            }
            tables[index] = value
        }
        for index in 0..<256 {
            for slice in 1..<8 {
                let previous = tables[(slice - 1) * 256 + index]
                tables[slice * 256 + index] = tables[Int(previous & 0xFF)] ^ (previous >> 8)
            }
        }
        return tables
    }()

    private var state: UInt32 = 0xFFFF_FFFF

    var value: UInt32 { state ^ 0xFFFF_FFFF }

    mutating func update(_ data: Data) {
        var crc = state
        Self.tables.withUnsafeBufferPointer { t in
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                var index = 0
                let count = bytes.count
                while index + 8 <= count {
                    let low = crc ^ (UInt32(bytes[index]) | UInt32(bytes[index + 1]) << 8
                        | UInt32(bytes[index + 2]) << 16 | UInt32(bytes[index + 3]) << 24)
                    crc = t[7 * 256 + Int(low & 0xFF)] ^ t[6 * 256 + Int((low >> 8) & 0xFF)]
                        ^ t[5 * 256 + Int((low >> 16) & 0xFF)] ^ t[4 * 256 + Int(low >> 24)]
                        ^ t[3 * 256 + Int(bytes[index + 4])] ^ t[2 * 256 + Int(bytes[index + 5])]
                        ^ t[1 * 256 + Int(bytes[index + 6])] ^ t[Int(bytes[index + 7])]
                    index += 8
                }
                while index < count {
                    crc = t[Int((crc ^ UInt32(bytes[index])) & 0xFF)] ^ (crc >> 8)
                    index += 1
                }
            }
        }
        state = crc
    }
}

extension Data {
    /// Reads a little-endian integer at a byte offset from the start of the data.
    func littleEndian<T: FixedWidthInteger>(_: T.Type, at offset: Int) -> T {
        var value: T = 0
        for index in 0..<MemoryLayout<T>.size {
            value |= T(self[startIndex + offset + index]) << (8 * index)
        }
        return value
    }

    /// Searches backwards for a little-endian 32-bit signature, starting at `from`.
    func lastIndex(ofSignature signature: UInt32, from: Int) -> Int? {
        guard from >= 0 else { return nil }
        for offset in stride(from: Swift.min(from, count - 4), through: 0, by: -1)
            where littleEndian(UInt32.self, at: offset) == signature {
            return offset
        }
        return nil
    }
}
