import Foundation
import Testing
@testable import SwiftFlashCore

/// Archives are created with the `gzip` and `zip` tools that ship with macOS, so the unpacker is checked against
/// real-world files rather than its own encoder.
struct ImageUnpackerTests {
    @Test
    func gzipImageIsUnpackedAndChecked() throws {
        try withDirectory { directory in
            let payload = Self.payload(size: 3 * 1024 * 1024 + 123)
            let image = directory.appendingPathComponent("disk.img")
            try payload.write(to: image)
            try run("/usr/bin/gzip", "-k", "-9", image.path)
            let gz = directory.appendingPathComponent("disk.img.gz")

            let out = directory.appendingPathComponent("out", isDirectory: true)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let result = try ImageUnpacker.unpack(gz, into: out) { _, _, _ in }
            #expect(result.url.lastPathComponent == "disk.img")
            #expect(try Data(contentsOf: result.url) == payload)
            #expect(result.sha256 == (try ImageSupport.calculateSHA256(for: image)))

            // Several members back to back are not supported and must not pass silently.
            let gzData = try Data(contentsOf: gz)
            let double = directory.appendingPathComponent("double.img.gz")
            try (gzData + gzData.prefix(gzData.count - 8) + Data(repeating: 0, count: 8)).write(to: double)
            #expect(throws: FlashError.self) { try ImageUnpacker.unpack(double, into: out) { _, _, _ in } }
        }
    }

    @Test
    func damagedGzipIsRejected() throws {
        try withDirectory { directory in
            let image = directory.appendingPathComponent("disk.img")
            try Self.payload(size: 2 * 1024 * 1024).write(to: image)
            try run("/usr/bin/gzip", "-9", image.path)
            let gz = directory.appendingPathComponent("disk.img.gz")
            var data = try Data(contentsOf: gz)
            data[data.count - 6] ^= 0xFF // inside the CRC/size trailer
            try data.write(to: gz)
            #expect(throws: FlashError.self) { try ImageUnpacker.unpack(gz, into: directory) { _, _, _ in } }

            let truncated = directory.appendingPathComponent("short.img.gz")
            try data.prefix(data.count / 2).write(to: truncated)
            #expect(throws: FlashError.self) { try ImageUnpacker.unpack(truncated, into: directory) { _, _, _ in } }
        }
    }

    @Test(arguments: [["-q", "-9"], ["-q", "-0"], ["-q", "-fz"]])
    func zipDeflatedStoredAndZip64(options: [String]) throws {
        try withDirectory { directory in
            let payload = Self.payload(size: 2 * 1024 * 1024 + 7)
            let image = directory.appendingPathComponent("raspios.img")
            try payload.write(to: image)
            try Data("readme".utf8).write(to: directory.appendingPathComponent("README.txt"))
            let zip = directory.appendingPathComponent("2026-10-06-raspios.zip")
            try run("/usr/bin/zip", options + [zip.path, "raspios.img", "README.txt"], in: directory)

            let out = directory.appendingPathComponent("out", isDirectory: true)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let result = try ImageUnpacker.unpack(zip, into: out) { _, _, _ in }
            #expect(result.url.lastPathComponent == "raspios.img")
            #expect(try Data(contentsOf: result.url) == payload)
        }
    }

    @Test
    func streamedZipWithDataDescriptorUsesArchiveName() throws {
        try withDirectory { directory in
            let payload = Self.payload(size: 1024 * 1024 + 5)
            let image = directory.appendingPathComponent("raw.bin")
            try payload.write(to: image)
            let zip = directory.appendingPathComponent("homebridge.zip")
            // `zip - ` reads stdin, writes an entry named "-" with a data descriptor.
            try run("/bin/sh", "-c", "/usr/bin/zip -q '\(zip.path)' - < '\(image.path)'")

            let out = directory.appendingPathComponent("out", isDirectory: true)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let result = try ImageUnpacker.unpack(zip, into: out) { _, _, _ in }
            #expect(result.url.lastPathComponent == "homebridge.img")
            #expect(try Data(contentsOf: result.url) == payload)
        }
    }

    @Test
    func zipWithSeveralImagesIsRejected() throws {
        try withDirectory { directory in
            for name in ["a.img", "b.img"] {
                try Self.payload(size: 4096).write(to: directory.appendingPathComponent(name))
            }
            let zip = directory.appendingPathComponent("two.zip")
            try run("/usr/bin/zip", ["-q", zip.path, "a.img", "b.img"], in: directory)
            #expect(throws: FlashError.self) { try ImageUnpacker.unpack(zip, into: directory) { _, _, _ in } }
        }
    }

    @Test
    func preparerUnpacksZipAndChecksExpectedSHA256() async throws {
        let directory = try ImagePreparer.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Self.payload(size: 2 * 1024 * 1024)
        let image = directory.appendingPathComponent("os.img")
        try payload.write(to: image)
        let sha256 = try ImageSupport.calculateSHA256(for: image)
        let zip = directory.appendingPathComponent("os-2026.zip")
        try run("/usr/bin/zip", ["-q", zip.path, "os.img"], in: directory)

        let prepared = try await ImagePreparer().prepare(source: zip.path, expectedImageSHA256: sha256) { _ in }
        defer { prepared.cleanup() }
        #expect(prepared.imageChecksumVerified)
        #expect(prepared.image.name == "os.img")
        #expect(prepared.image.sourceLocation == zip.path)
    }

    @Test
    func cancelledPreparationStopsAndRemovesTemporaryFiles() async throws {
        let directory = try ImagePreparer.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = directory.appendingPathComponent("big.img")
        try Data(count: 64 * 1024 * 1024).write(to: image)
        try run("/usr/bin/gzip", "-1", image.path)
        let gz = directory.appendingPathComponent("big.img.gz")

        let started = AsyncStream<URL?>.makeStream()
        let task = Task {
            try await ImagePreparer().prepare(source: gz.path) { _ in started.continuation.yield(nil) }
        }
        for await _ in started.stream { break } // unpacking has begun
        task.cancel()
        await #expect(throws: FlashError.cancelled) { _ = try await task.value }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)
            .filter { $0.hasPrefix("swiftflash-") }
            .map { FileManager.default.temporaryDirectory.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("big.img").path) }
        #expect(leftovers.isEmpty)
    }

    @Test
    func baseNamesAndFamilies() {
        #expect(ImageSupport.baseName(of: "os-v1.0.img.xz") == "os-v1.0")
        #expect(ImageSupport.baseName(of: "os-v1.0.zip") == "os-v1.0")
        #expect(ImageSupport.baseName(of: "os-v1.0.img.gz") == "os-v1.0")
        #expect(RemoteImageNaming.split(fileName: "fam-v1.2.zip") == ("fam", "v1.2"))
        #expect(ImageUnpacker.unpackedName(for: URL(fileURLWithPath: "/x/disk.img.gz")) == "disk.img")
        #expect(ImageUnpacker.unpackedName(for: URL(fileURLWithPath: "/x/image.zip")) == "image.img")
    }

    // MARK: - Helpers

    static func payload(size: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        var data = Data(count: size)
        // Half random, half zeros: compressible but not trivial.
        for index in stride(from: 0, to: size / 2, by: 8) {
            let value = generator.next() as UInt64
            for byte in 0..<min(8, size / 2 - index) {
                data[index + byte] = UInt8(truncatingIfNeeded: value >> (8 * byte))
            }
        }
        return data
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let directory = try ImagePreparer.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func run(_ tool: String, _ arguments: String...) throws {
        try run(tool, arguments, in: nil)
    }

    private func run(_ tool: String, _ arguments: [String], in directory: URL?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(tool) \(arguments) failed")
    }
}
