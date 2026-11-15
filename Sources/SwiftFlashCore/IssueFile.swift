import Foundation

/// Reads `issue.txt` from a boot partition, as written by `pi-gen` (Raspberry Pi OS and derived images):
///
///     Raspberry Pi reference 2026-10-06
///     Generated using pi-gen, https://github.com/RPi-Distro/pi-gen, b2cd98a9ee08…, stage2
///
/// Used as image identity when the image has no `/.uuid` with an `image` block.
public enum IssueFile {
    public static let fileName = "issue.txt"

    /// Marker in `additionalFields` so it is clear the identity was derived, not shipped by the image.
    public static let detectedFromKey = "detectedFrom"

    public static func read(from partitions: [PartitionVolume]) -> ImageIdentity? {
        for partition in partitions {
            guard let mountPoint = partition.mountPoint else { continue }
            let url = URL(fileURLWithPath: mountPoint).appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: url), data.count <= 64 * 1024,
                  let identity = parse(String(decoding: data, as: UTF8.self))
            else {
                continue
            }
            return identity
        }
        return nil
    }

    public static func parse(_ text: String) -> ImageIdentity? {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let title = lines.first, !title.isEmpty else {
            return nil
        }

        var fields: [String: JSONValue] = [detectedFromKey: .string(fileName)]
        var build: String?
        var stage: String?
        if let generated = lines.dropFirst().first(where: { $0.hasPrefix("Generated using pi-gen") }) {
            let parts = generated.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3 {
                build = String(parts[2].prefix(12))
            }
            if parts.count >= 4 {
                stage = parts[3]
                fields["piGenStage"] = .string(parts[3])
            }
        }

        // The last word is the version when it looks like a date or a version number.
        var words = title.split(separator: " ").map(String.init)
        var version: String?
        if words.count > 1, let last = words.last,
           last.range(of: #"^(\d{4}-\d{2}-\d{2}|v?\d+(\.\d+)+)$"#, options: .regularExpression) != nil {
            version = last
            words.removeLast()
        }

        var name = words.joined(separator: " ")
        var id: String?
        if name == "Raspberry Pi reference" {
            // Official Raspberry Pi OS build; the pi-gen stage tells the variant.
            name = ["Raspberry Pi OS", stage.flatMap(raspberryPiOSVariant)].compactMap { $0 }.joined(separator: " ")
            id = "raspberry-pi-os"
        }

        return ImageIdentity(id: id, name: name, version: version, build: build, additionalFields: fields)
    }

    /// pi-gen stages of the official images: stage2 = Lite, stage4 = with desktop, stage5 = full.
    static func raspberryPiOSVariant(stage: String) -> String? {
        switch stage {
        case "stage2": "Lite"
        case "stage4": nil
        case "stage5": "Full"
        default: nil
        }
    }
}
