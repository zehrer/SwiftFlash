import Foundation

/// A Raspberry Pi board as listed by the Raspberry Pi Imager, e.g. `pi5` for "Raspberry Pi 5".
public struct RaspberryPiModel: Equatable, Sendable {
    /// Short name used on the command line: `pi5`, `pi4`, `zero2w`, …
    public var slug: String
    public var name: String
    /// Device tags an image must carry to run on this board, e.g. `pi5-64bit`.
    public var tags: [String]
    /// Exclusive boards only get images that list one of their tags; inclusive boards also get
    /// images without any device list.
    public var exclusive: Bool

    public init(slug: String, name: String, tags: [String], exclusive: Bool) {
        self.slug = slug
        self.name = name
        self.tags = tags
        self.exclusive = exclusive
    }

    public func supports(_ image: RemoteImage) -> Bool {
        image.devices.isEmpty ? !exclusive : !Set(image.devices).isDisjoint(with: tags)
    }

    /// `Raspberry Pi 5` → `pi5`, `Raspberry Pi Zero 2 W` → `zero2w`.
    static func slug(for name: String) -> String {
        var rest = name.lowercased()
        if rest.hasPrefix("raspberry pi") {
            rest = String(rest.dropFirst("raspberry pi".count))
        }
        let compact = rest.filter { $0.isLetter || $0.isNumber }
        return compact.first?.isNumber == true ? "pi" + compact : compact
    }
}

/// The OS list of the Raspberry Pi Imager (`os_list_imagingutility_v4.json`), used as an image source.
public struct RaspberryPiImageList: Equatable, Sendable {
    public static let officialURL = "https://downloads.raspberrypi.com/os_list_imagingutility_v4.json"

    /// Images in list order, each its own family; only formats SwiftFlash can write.
    public var images: [RemoteImage]
    public var models: [RaspberryPiModel]
    /// Images left out because of their format (e.g. `.zip`, `.gz`).
    public var unsupportedCount: Int

    public func model(named slug: String) throws -> RaspberryPiModel {
        guard let model = models.first(where: { $0.slug == slug.lowercased() }) else {
            throw FlashError.usage(
                "Unknown Raspberry Pi model '\(slug)'. Known: \(models.map(\.slug).joined(separator: ", "))"
            )
        }
        return model
    }

    /// Short board names an image runs on, e.g. `pi5 pi4 pi3 zero2w`.
    public func modelSlugs(for image: RemoteImage) -> [String] {
        image.devices.isEmpty ? [] : models.filter { $0.supports(image) }.map(\.slug)
    }

    /// True for URLs that point to an Imager OS list rather than a directory.
    public static func isListURL(_ url: String) -> Bool {
        URL(string: url)?.pathExtension.lowercased() == "json"
    }

    public static func parse(_ data: Data) -> RaspberryPiImageList? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let osList = root["os_list"] as? [[String: Any]]
        else {
            return nil
        }

        let devices = (root["imager"] as? [String: Any])?["devices"] as? [[String: Any]] ?? []
        let models: [RaspberryPiModel] = devices.compactMap { device in
            guard let name = device["name"] as? String,
                  let tags = device["tags"] as? [String], !tags.isEmpty
            else {
                return nil
            }
            return RaspberryPiModel(
                slug: RaspberryPiModel.slug(for: name),
                name: name,
                tags: tags,
                exclusive: (device["matching_type"] as? String) == "exclusive"
            )
        }

        var images: [RemoteImage] = []
        var seenURLs = Set<URL>()
        var usedFamilies = Set<String>()
        var unsupported = 0

        func walk(_ items: [[String: Any]], category: String?) {
            for item in items {
                guard let name = item["name"] as? String else { continue }
                if let subitems = item["subitems"] as? [[String: Any]] {
                    walk(subitems, category: category ?? name)
                    continue
                }
                guard let urlText = item["url"] as? String, let url = URL(string: urlText),
                      seenURLs.insert(url).inserted
                else {
                    continue
                }
                guard (try? ImageSupport.validateImageName(url.lastPathComponent)) != nil else {
                    unsupported += 1
                    continue
                }
                var family = familyName(for: name)
                if !usedFamilies.insert(family).inserted {
                    family += "-\(images.count + 1)"
                    usedFamilies.insert(family)
                }
                let releaseDate = item["release_date"] as? String
                images.append(
                    RemoteImage(
                        fileName: url.lastPathComponent,
                        url: url,
                        family: family,
                        version: releaseDate,
                        date: releaseDate.flatMap(parseDate),
                        title: name,
                        category: category,
                        devices: item["devices"] as? [String] ?? [],
                        imageSHA256: (item["extract_sha256"] as? String)?.lowercased()
                    )
                )
            }
        }
        walk(osList, category: nil)
        return RaspberryPiImageList(images: images, models: models, unsupportedCount: unsupported)
    }

    /// `Raspberry Pi OS Lite (64-bit)` → `raspberry-pi-os-lite-64-bit`.
    static func familyName(for title: String) -> String {
        title.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
            .split(separator: "-")
            .joined(separator: "-")
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }
}
