import Foundation

/// What the user should know about a target medium before choosing or erasing it:
/// whether it is a remembered medium and what is currently on it.
public struct DeviceOverview: Equatable, Sendable {
    /// Name to show for the medium (custom name if the medium is remembered).
    public var title: String
    /// Indented detail lines, e.g. `Known medium: …`, `Currently on it: …`.
    public var details: [String]

    public init(title: String, details: [String]) {
        self.title = title
        self.details = details
    }

    /// One line describing the current content, used in the erase confirmation.
    public var currentContent: String? {
        details.first { $0.hasPrefix(Self.contentPrefix) }.map { String($0.dropFirst(Self.contentPrefix.count)) }
    }

    static let contentPrefix = "Currently on it: "

    /// Earlier flashes of this medium from the local history (newest first), for `swiftflash id`.
    public static func historyLines(
        _ history: [FlashHistoryEntry],
        deviceUUID: String,
        limit: Int = 5,
        formatDate: (Date) -> String = { $0.formatted(date: .abbreviated, time: .shortened) }
    ) -> [String] {
        let entries = history
            .filter { $0.deviceUUID == deviceUUID }
            .sorted { $0.finishedAt > $1.finishedAt }
        guard !entries.isEmpty else {
            return []
        }
        var lines = ["History on this Mac (\(entries.count) flash\(entries.count == 1 ? "" : "es")):"]
        for entry in entries.prefix(limit) {
            let label = entry.image?.displayLabel.map { "\($0) (\(entry.imageName))" } ?? entry.imageName
            let failed = entry.result.hasPrefix("failed") ? "  [failed]" : ""
            lines.append("  \(formatDate(entry.finishedAt))  \(label)\(failed)")
        }
        if entries.count > limit {
            lines.append("  … \(entries.count - limit) more, see `swiftflash history`")
        }
        return lines
    }

    /// Detailed lines about the flashed image for `swiftflash id`: identity, file, source, checksum and flash.
    public static func imageDetails(
        metadata: FlashUUIDMetadata?,
        imageIdentity: ImageIdentity?,
        formatDate: (Date) -> String = { $0.formatted(date: .abbreviated, time: .shortened) }
    ) -> [String] {
        var lines: [String] = []
        if let image = metadata?.image ?? imageIdentity {
            if let label = image.displayLabel {
                lines.append("Image:        \(label)")
            }
            if let id = image.id, image.name != nil {
                lines.append("Image id:     \(id)")
            }
            if let build = image.build {
                lines.append("Image build:  \(build)")
            }
            for key in image.additionalFields.keys.sorted() {
                if case .string(let value)? = image.additionalFields[key] {
                    lines.append("\(String("\(key):".padding(toLength: 14, withPad: " ", startingAt: 0)))\(value)")
                }
            }
        }
        if let metadata, metadata.flashUUID != nil, !metadata.imageName.isEmpty {
            lines.append("Image file:   \(metadata.imageName)")
            if metadata.imagePath != metadata.imageName {
                lines.append("Source:       \(metadata.imagePath)")
            }
            if let sha256 = metadata.imageSHA256 {
                lines.append("SHA-256:      \(sha256)")
            }
            lines.append("Flashed:      \(formatDate(metadata.flashedAt))")
            if let flashUUID = metadata.flashUUID {
                lines.append("Flash UUID:   \(flashUUID.uuidString)")
            }
        }
        return lines
    }

    public static func make(
        device: DiskCandidate,
        identityStatus: DeviceIdentityStatus,
        knownDevice: KnownPhysicalDevice?,
        imageIdentity: ImageIdentity?,
        formatDate: (Date) -> String = { $0.formatted(date: .abbreviated, time: .shortened) }
    ) -> DeviceOverview {
        var details: [String] = []
        let metadata = identityStatus.resolvedIdentity?.metadata

        switch identityStatus {
        case .identified(let identity):
            if let knownDevice {
                let name = knownDevice.customName ?? "unnamed"
                let mediaType = knownDevice.mediaTypeName.map { " [\($0)]" } ?? ""
                details.append("Known medium: \(name)\(mediaType), device-uuid \(identity.metadata.deviceUUID)")
            } else {
                details.append("Identified medium, device-uuid \(identity.metadata.deviceUUID)")
            }
        case .trailerRequiresSudo:
            details.append("Unknown medium (sudo required to read trailer metadata)")
        case .unassigned:
            details.append("Unknown medium")
        }

        if let metadata, metadata.flashUUID != nil, !metadata.imageName.isEmpty {
            let label = (metadata.image ?? imageIdentity)?.displayLabel
            let image = label.map { "\($0) (\(metadata.imageName))" } ?? metadata.imageName
            details.append("\(contentPrefix)\(image), flashed \(formatDate(metadata.flashedAt))")
        } else if let label = (metadata?.image ?? imageIdentity)?.displayLabel {
            details.append("\(contentPrefix)\(label)")
        } else {
            let volumes = device.partitions.compactMap(\.volumeName).filter { !$0.isEmpty }
            if !volumes.isEmpty {
                details.append("\(contentPrefix)volumes \(volumes.joined(separator: ", "))")
            }
        }

        return DeviceOverview(title: knownDevice?.customName ?? device.displayName, details: details)
    }
}
