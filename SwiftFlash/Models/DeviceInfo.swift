//
//  DeviceInfo.swift
//  SwiftFlash
//
//  Transient, low-level model describing device information discovered by
//  DriveDetectionService (IOKit/DiskArbitration). This struct itself is not
//  persisted. However, a subset of its attributes is copied into the
//  DeviceInventory (stored as JSON via UserDefaults) to maintain a history of
//  seen devices.
//
//  Persisted via DeviceInventory JSON (when inventory is updated):
//  - mediaUUID    → DeviceInventoryItem.mediaUUID
//  - size         → DeviceInventoryItem.size
//  - mediaName    → DeviceInventoryItem.mediaName
//  - vendor       → DeviceInventoryItem.vendor
//  - revision     → DeviceInventoryItem.revision
//
//  Not persisted (runtime-only, discovery context):
//  - name, devicePath, isRemovable, isEjectable, isReadOnly
//

import Foundation

struct DeviceInfo {
    /// Human-readable device name from the system (runtime, not persisted)
    let name: String
    /// Absolute device node path, e.g. "/dev/disk4" (runtime, not persisted)
    let devicePath: String
    /// Total media size in bytes (persisted to inventory)
    let size: Int64
    /// Whether the media is removable (runtime, not persisted)
    let isRemovable: Bool
    /// Whether the media is ejectable (runtime, not persisted)
    let isEjectable: Bool
    /// Whether the media is read-only (runtime, not persisted)
    let isReadOnly: Bool
    /// Media UUID from Disk Arbitration (persisted to inventory)
    let mediaUUID: String?
    /// Media name from Disk Arbitration (persisted to inventory)
    let mediaName: String?
    /// Vendor from Disk Arbitration (persisted to inventory)
    let vendor: String?
    /// Revision from Disk Arbitration (persisted to inventory)
    let revision: String?
    /// Device model from Disk Arbitration (runtime-only)
    let daDeviceModel: String?
    /// Discovered partitions/slices of this device (runtime-only)
    let partitions: [PartitionInfo]
}

// MARK: - Derived properties

extension DeviceInfo {
    /// Returns true if this represents a main device (not a partition/slice)
    var isMainDevice: Bool {
        // Ends with s<number> indicates a partition
        if devicePath.range(of: #"s\d+$"#, options: .regularExpression) != nil {
            return false
        }
        // Contains 's' followed by number in the middle e.g. disk3s1
        let components = devicePath.components(separatedBy: "s")
        if components.count > 1 {
            if let last = components.last, Int(last) != nil { return false }
        }
        // Nested partition like disk3s1s1
        if components.count > 2 { return false }
        return true
    }

    /// Returns true if this device is a mounted disk image
    var isDiskImage: Bool {
        // Check media name from Disk Arbitration
        if let mediaName, mediaName == "Disk Image" { return true }
        // Check device name
        if name == "Disk Image" { return true }
        // Check Disk Arbitration device model (most reliable indicator)
        if let daDeviceModel, daDeviceModel == "Disk Image" { return true }
        return false
    }

    /// Heuristic mapping from detected name/path to a DeviceType
    var inferredDeviceType: DeviceType {
        let lower = name.lowercased()
        if lower.contains("microsd") || lower.contains("micro sd") { return .microSDCard }
        if lower.contains("sd") || lower.contains("transce") { return .sdCard }
        if lower.contains("udisk") || lower.contains("mass") || lower.contains("generic") { return .usbStick }
        if lower.contains("ssd") || lower.contains("solid state") { return .externalSSD }
        if lower.contains("external") || lower.contains("drive") || lower.contains("hard disk") { return .externalHDD }
        return .unknown
    }

    /// Formatted size string for display
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}


