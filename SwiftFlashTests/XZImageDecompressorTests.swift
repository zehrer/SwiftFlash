//
//  XZImageDecompressorTests.swift
//  SwiftFlashTests
//

import Foundation
import Testing
@testable import SwiftFlash

/// Tests for `.img.xz` support using a small real xz stream (CRC64) created with `xz`.
struct XZImageDecompressorTests {

    /// 300 000 bytes: `byte(i) = (i * 7 + i / 251) % 256`, compressed as xz.
    private static let fixtureBase64 =
        "/Td6WFoAAATm1rRGAgAhARYAAAB0L+Wj5JPfAs9dAAACD1cCaMZ4ztgPkObrtt0fcGKwIScU+bGVilhgIXosrOd3mN9FhtqsaTRpDThkVeK3GBaqRBWZvqKQiwnWH8lH/+/emsaNvzPZtdRqrxbt9IO8aXTRI+bHhB4Sm6Z1kFaQiXIaWH9aPoAGTFZlP3jrrdfGVTsfZ+OoN4oZmfJM5qXLAHGJW88WI4GS8fcHv5vu3PoWEw5R0BBpiD7e5L3DpuCVgytLqJV1mHobigJ0eKah/Gpg8KWtKshVxM8vBg9iG52FuRUcyJuUGWbUBiCGJqOtfGiEAi97jytXcjJWs9iID01/A1Y9w9War4y2pWgSIryM4Zg9NVt+L1vFxMsBfUW65J7Xc502x4lSBzXTw/7a2HYa00sXbWIat6ltnSlPVt4Zp+XxcZe7Paof2kjUMtUYTxxs6Z5I5I2vHdRyWZqp/bZwpbn7EL3Ag/fOnwjx6SZgXUziSl61Sx+ey6uldTklY337oaW9dvfedljvkcAqQpYqN3HS0reKWLwjRI3n2Y4bWbzHc1itIDCbChoZFfe+9nb1b/jj/F2LQgG/HqYL0MLkHa8NI8HFioUvuNNrflSD+HJDxHnHbH1+53KnA7GzAZFk3EMXEZH/ljnVj69PUbjiGZG/4o9woaL4eWUPhfQhgBRn1bqtVoE5XmHmCOleHnwoNEENJwnnQsVcTOQPF0GBZbvG0a1sXxag9lrnt2SrudTkglhUzmIYUuUFPcHrD3FT2vqy5n5cr0k0uzGlzSfIUXIbArc83gA3jZ0TnUWI6lBjpAawcXkzeewiFIaWekMfacOfMIf89vicy6zQepN6TeXslmFdVgIgfSoxlbDdmAnDBWfXg16UBGfRUFfXMCZ3OqvM9Tyk7r/K/ThXL4M+lVry244cWxYFtZJHCSah8vK6x/hBCkckb/PEbwmfVTuosYjaLGxyP+TSSa0HpxSpEX2DZa7cHzwAAADGzgNb31ldGAAB6wXgpxIA4sqKBbHEZ/sCAAAAAARZWg=="
    private static let fixtureSize = 300_000

    private func temporaryFile(_ name: String, contents: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftFlashTests-\(UUID().uuidString)-\(name)")
        try contents.write(to: url)
        return url
    }

    private func fixtureData() throws -> Data {
        try #require(Data(base64Encoded: Self.fixtureBase64))
    }

    private func decompress(_ source: URL, to destination: URL) throws -> Int64 {
        try XZImageDecompressor.decompress(
            from: source, to: destination, progress: { _ in }, isCancelled: { false })
    }

    @Test func readsUncompressedSizeFromIndex() throws {
        let url = try temporaryFile("fixture.img.xz", contents: fixtureData())
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(XZImageDecompressor.uncompressedSize(of: url) == Int64(Self.fixtureSize))
    }

    @Test func decompressesToOriginalBytes() throws {
        let source = try temporaryFile("fixture.img.xz", contents: fixtureData())
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftFlashTests-\(UUID().uuidString).img")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }

        let written = try decompress(source, to: destination)
        let result = try Data(contentsOf: destination)

        #expect(written == Int64(Self.fixtureSize))
        #expect(result.count == Self.fixtureSize)
        let expected = (0..<Self.fixtureSize).map { UInt8(truncatingIfNeeded: $0 * 7 + $0 / 251) }
        #expect(Array(result) == expected)
    }

    @Test func rejectsTruncatedFile() throws {
        let truncated = try fixtureData().dropLast(40)
        let source = try temporaryFile("truncated.img.xz", contents: Data(truncated))
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftFlashTests-\(UUID().uuidString).img")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }

        #expect(XZImageDecompressor.uncompressedSize(of: source) == nil)
        #expect(throws: (any Error).self) { try decompress(source, to: destination) }
    }

    @Test func rejectsNonXZData() throws {
        let source = try temporaryFile("garbage.img.xz", contents: Data(repeating: 0x41, count: 4096))
        defer { try? FileManager.default.removeItem(at: source) }

        #expect(XZImageDecompressor.uncompressedSize(of: source) == nil)
    }

    @Test func honoursCancellation() throws {
        let source = try temporaryFile("fixture.img.xz", contents: fixtureData())
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftFlashTests-\(UUID().uuidString).img")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }

        #expect(throws: XZImageDecompressor.Failure.self) {
            try XZImageDecompressor.decompress(
                from: source, to: destination, progress: { _ in }, isCancelled: { true })
        }
    }

    // MARK: - ImageFile

    @Test @MainActor func imageFileDetectsCompression() {
        let compressed = ImageFile(name: "a.img.xz", path: "/tmp/a.img.xz", size: 10, fileType: .img)
        let plain = ImageFile(name: "a.img", path: "/tmp/a.img", size: 10, fileType: .img)

        #expect(compressed.isCompressed)
        #expect(!plain.isCompressed)
        #expect(plain.flashSize() == 10)
        #expect(plain.uncompressedSize() == nil)
    }

    /// The inspector shows the size after decompression, not the file size.
    @Test @MainActor func imageFileReportsUncompressedSize() throws {
        let data = try fixtureData()
        let url = try temporaryFile("sized.img.xz", contents: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = ImageFile(
            name: url.lastPathComponent, path: url.path, size: Int64(data.count), fileType: .img)

        #expect(image.uncompressedSize() == Int64(Self.fixtureSize))
        #expect(image.flashSize() == Int64(Self.fixtureSize))
        #expect(image.flashSize() > image.size)
    }

    /// A damaged compressed file has no known size; flashSize falls back to the file size.
    @Test @MainActor func damagedImageHasNoUncompressedSize() throws {
        let url = try temporaryFile("bad.img.xz", contents: Data(repeating: 0x41, count: 4096))
        defer { try? FileManager.default.removeItem(at: url) }

        let image = ImageFile(name: url.lastPathComponent, path: url.path, size: 4096, fileType: .img)

        #expect(image.uncompressedSize() == nil)
        #expect(image.flashSize() == 4096)
    }
}
