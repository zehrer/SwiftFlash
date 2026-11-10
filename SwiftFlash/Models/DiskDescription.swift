//
//  DiskDescription.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 06.11.25.
//

import Foundation
import DiskArbitration

// MARK: - Design Considerations
//
// DiskDescription is intentionally implemented as a struct with a captured
// immutable `[String: Any]?` dictionary from Disk Arbitration. Swift's
// standard library collections (Dictionary/Array/Set) use copy-on-write (CoW),
// so storing the dictionary as `let` and only reading from it does not cause
// additional copies when DiskDescription is passed by value. The underlying
// storage is shared until a mutation occurs (which we do not perform here).
//
// Benefits of using a struct here:
// - Value semantics: predictable, thread-friendly, and no shared mutable state.
// - Performance: avoids unnecessary copies due to CoW; minimal ARC overhead.
// - Simplicity: this type is a transient, read-only view over system metadata.
//
// If we later need to persist a subset of these values with SwiftData, we will
// use a dedicated @Model class to represent the persisted schema, copying the
// relevant fields from this transient description at ingestion time. This keeps
// persistence concerns separate from runtime system metadata access.

/// Thin wrapper around Disk Arbitration's disk description dictionary.
///
/// This struct captures the raw description dictionary once and exposes a
/// set of typed, lazily-computed getters. No values are copied or mutated.
/// If a key is unavailable or of an unexpected type, the corresponding
/// property returns `nil` (or applies a safe conversion where noted).
struct DiskDescription {
    /// The raw Disk Arbitration description dictionary (DA* keys → values).
    let dictionary: [String: Any]?

    /// Initialize with the raw DA description dictionary captured at detection time.
    /// - Parameter dictionary: The description returned by `DADiskCopyDescription(_:)`.
    init(_ dictionary: [String: Any]?) {
        self.dictionary = dictionary
    }

    // MARK: - Volume (filesystem-related)

    /// Human-readable volume name (e.g., "UNTITLED").
    var volumeName: String? { string(for: kDADiskDescriptionVolumeNameKey) }

    /// Indicates a network-backed volume (if provided by DA).
    var volumeNetwork: String? { string(for: kDADiskDescriptionVolumeNetworkKey) }

    /// Filesystem mount path, if mounted. Handles both URL and String storage.
    var volumePath: String? { path(for: kDADiskDescriptionVolumePathKey) }

    /// Volume UUID string (if available from DA).
    var volumeUUID: String? { string(for: kDADiskDescriptionVolumeUUIDKey) }


    /// Filesystem kind (e.g., "apfs", "hfs", "msdos"). [kDADiskDescriptionVolumeKindKey]
    var volumeKind: String? { string(for: kDADiskDescriptionVolumeKindKey) }

    /// Whether the volume is mountable according to Disk Arbitration.
    var isMountable: Bool? { bool(for: kDADiskDescriptionVolumeMountableKey) }
    

    // MARK: - Media (physical or virtual media)

    /// Media UUID (if provided; may be absent for some devices).
    var mediaUUID: String? { string(for: kDADiskDescriptionMediaUUIDKey) }

    /// Media name (e.g., vendor-provided label or generic name).
    var mediaName: String? { string(for: kDADiskDescriptionMediaNameKey) }

    /// Media kind (e.g., "disk image", "solid state", etc.).
    var mediaKind: String? { string(for: kDADiskDescriptionMediaKindKey) }


    /// Media size in bytes as UInt64.
    ///
    /// Safely converts from UInt64, Int64 (non-negative), or NSNumber.
    /// Returns nil if the value is missing or negative (for Int64-backed values).
    var mediaSize: UInt64? { uint64(for: kDADiskDescriptionMediaSizeKey) }

    /// Whether the media is ejectable (e.g., optical, external removable).
    var isEjectable: Bool? { bool(for: kDADiskDescriptionMediaEjectableKey) }

    /// Whether the media is removable.
    var isRemovable: Bool? { bool(for: kDADiskDescriptionMediaRemovableKey) }

    /// Whether this dictionary describes the whole media (not a partition slice).
    var isWhole: Bool? { bool(for: kDADiskDescriptionMediaWholeKey) }

    /// Whether the media is writable.
    var isWritable: Bool? { bool(for: kDADiskDescriptionMediaWritableKey) }

    // MARK: - Device (hardware info)

    /// Device GUID (if available).
    var deviceGUID: String? { string(for: kDADiskDescriptionDeviceGUIDKey) }

    /// Device model (e.g., vendor model string).
    var deviceModel: String? { string(for: kDADiskDescriptionDeviceModelKey) }

    /// Device path (e.g., IOKit path string).
    var devicePath: String? { string(for: kDADiskDescriptionDevicePathKey) }

    /// Connection protocol (e.g., "USB", "SATA").
    var deviceProtocol: String? { string(for: kDADiskDescriptionDeviceProtocolKey) }

    /// Device firmware or hardware revision string.
    var deviceRevision: String? { string(for: kDADiskDescriptionDeviceRevisionKey) }

    /// Device vendor name.
    var deviceVendor: String? { string(for: kDADiskDescriptionDeviceVendorKey) }

    /// Whether the device is internal to the system (true) or external (false), if known.
    var isInternal: Bool? { bool(for: kDADiskDescriptionDeviceInternalKey) }
}

private extension DiskDescription {
    func bool(for key: CFString) -> Bool? {
        (dictionary?[key as String] as? NSNumber)?.boolValue
    }
    func string(for key: CFString) -> String? {
        dictionary?[key as String] as? String
    }
    func path(for key: CFString) -> String? {
        if let url = dictionary?[key as String] as? URL { return url.path }
        if let path = dictionary?[key as String] as? String { return path }
        return nil
    }
    func uint64(for key: CFString) -> UInt64? {
        if let v = dictionary?[key as String] as? UInt64 { return v }
        if let v = dictionary?[key as String] as? Int64, v >= 0 { return UInt64(v) }
        if let n = dictionary?[key as String] as? NSNumber {
            let v = n.int64Value
            return v >= 0 ? UInt64(v) : nil
        }
        return nil
    }
}

// MARK: - Extension : Convenience Accessors


extension DiskDescription {
    var isMountableDefaultFalse: Bool { isMountable ?? false }
    var isWritableDefaultFalse: Bool { isWritable ?? false }

    //
    var isWholeMedia: Bool { isWhole ?? false }
}


// MARK: - Extension : VolumeKind

enum VolumeKind: String {
    case apfs, hfs, msdos, exfat
    case unknown
}

extension DiskDescription {
    var volumeKindEnum: VolumeKind {
        guard let k = volumeKind?.lowercased() else { return .unknown }
        return VolumeKind(rawValue: k) ?? .unknown
    }
}

// MARK: - Extension : sanity view


extension DiskDescription {
    var summary: String {
        [
            "Volume: \(volumeName ?? "-")",
            "Path: \(volumePath ?? "-")",
            "Kind: \(volumeKind ?? "-")",
            "Media: \(mediaName ?? "-")",
            "Size: \(mediaSize.map { String($0) } ?? "-")",
            "Vendor/Model: \(deviceVendor ?? "-") / \(deviceModel ?? "-")",
            "Protocol: \(deviceProtocol ?? "-")",
            "Internal: \(isInternal?.description ?? "-")"
        ].joined(separator: " | ")
    }
}

// MARK: - Extension : sanity view

struct BasicDiskInfo {
    let name: String
    let path: String
    let size: UInt64
}

extension DiskDescription {
    var basicInfo: BasicDiskInfo? {
        guard let name = volumeName ?? mediaName,
              let path = volumePath,
              let size = mediaSize else { return nil }
        return .init(name: name, path: path, size: size)
    }
}

