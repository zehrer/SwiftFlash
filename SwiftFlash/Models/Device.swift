//
//  Device.swift
//  SwiftFlash
//
//  Main business logic model for device operations and runtime properties.
//  This struct acts as a wrapper around DeviceInventoryItem to avoid data duplication
//  and provides a unified interface for device operations throughout the application.
//  It combines the functionality of the previous Device and Drive models.
//

import DiskArbitration
import Foundation

// Compatibility alias for legacy code paths using Drive
typealias Drive = Device

/// Main business logic model for device operations and runtime properties
/// This struct contains all non-optional properties and handles device operations
/// Acts as a wrapper around DeviceInventoryItem to avoid data duplication
/// Replaces the previous Device, Drive, and DeviceInfo models
struct Device: Identifiable, Hashable {
    // MARK: - Core Identity (from DeviceInventoryItem)
    var id: UUID { inventoryItem?.id ?? UUID() }
    var mediaUUID: String {
        // If we have an inventory item, use its stored UUID
        if let inventoryItem = inventoryItem {
            return inventoryItem.mediaUUID
        }

        // For new devices, generate a stable identifier from Disk Arbitration data
        return generateStableDeviceID()
    }

    // MARK: - Basic Properties (wrapper access to DeviceInventoryItem)
    var name: String { inventoryItem?.name ?? "" }
    var size: Int64 { inventoryItem?.size ?? 0 }
    var vendor: String? { inventoryItem?.vendor }
    var revision: String? { inventoryItem?.revision }
    var deviceType: DeviceType {
        get { inventoryItem?.deviceType ?? .unknown }
        set { inventoryItem?.deviceType = newValue }
    }

    // MARK: - Persistence Properties (wrapper access)
    var firstSeen: Date { inventoryItem?.firstSeen ?? Date() }
    var lastSeen: Date {
        get { inventoryItem?.lastSeen ?? Date() }
        set { inventoryItem?.lastSeen = newValue }
    }
    var customName: String? {
        get { inventoryItem?.customName }
        set { inventoryItem?.customName = newValue }
    }

    // MARK: - Runtime Properties (non-optional, Device-specific)
    let devicePath: String
    let isRemovable: Bool
    let isEjectable: Bool
    let isReadOnly: Bool
    let isSystemDrive: Bool
    let diskDescription: [String: Any]?
    let partitions: [PartitionInfo]

    // Compatibility alias for legacy code using Drive.mountPoint
    var mountPoint: String { devicePath }

    // MARK: - UI Properties
    var partitionScheme: ImageFileService.PartitionScheme = .unknown

    // MARK: - Persistence Reference
    var inventoryItem: DeviceInventoryItem?

    // MARK: - Computed Properties
    var displayName: String {
        return customName ?? name
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Formatted partition scheme display string
    var partitionSchemeDisplay: String {
        switch partitionScheme {
        case .mbr:
            return "MBR (Master Boot Record)"
        case .gpt:
            return "GPT (GUID Partition Table)"
        case .unknown:
            return "Unknown"
        }
    }

    // MARK: - Disk Arbitration Computed Properties
    // These properties provide direct access to Disk Arbitration data
    // They replace the previous DeviceInfo properties
    var daMediaUUID: String? { daString(kDADiskDescriptionMediaUUIDKey as String) }

    // MARK: - Derived Properties
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

    var isDiskImage: Bool {
        // Check media name from Disk Arbitration
        if let daMediaName, daMediaName == "Disk Image" { return true }
        // Check device name
        if name == "Disk Image" { return true }
        // Check Disk Arbitration device model (most reliable indicator)
        if let daDeviceModel, daDeviceModel == "Disk Image" { return true }
        return false
    }

    var inferredDeviceType: DeviceType {
        let lower = name.lowercased()
        if lower.contains("microsd") || lower.contains("micro sd") { return .microSDCard }
        if lower.contains("sd") || lower.contains("transce") { return .sdCard }
        if lower.contains("udisk") || lower.contains("mass") || lower.contains("generic") {
            return .usbStick
        }
        if lower.contains("ssd") || lower.contains("solid state") { return .externalSSD }
        if lower.contains("external") || lower.contains("drive") || lower.contains("hard disk") {
            return .externalHDD
        }
        return .unknown
    }

    // MARK: - Device Operations (moved from Drive struct)
    func unmountDevice() -> Bool {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["unmountDisk", devicePath]

        // Don't use pipes - they can cause blocking
        task.standardOutput = nil
        task.standardError = nil

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("❌ Failed to run diskutil: \(error)")
            return false
        }
    }

    func mountDevice() -> Bool {
        print("🔄 [DEBUG] Starting mount for: \(devicePath)")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["mount", devicePath]

        // Don't use pipes - they can cause blocking
        task.standardOutput = nil
        task.standardError = nil

        do {
            print("🚀 [DEBUG] Launching diskutil mount \(devicePath)")
            try task.run()

            // Create a timeout mechanism
            let timeoutSeconds: TimeInterval = 10.0
            let startTime = Date()

            // Check if process is still running with timeout
            var lastOutputCheck = Date()
            let outputCheckInterval: TimeInterval = 0.5

            while task.isRunning {
                if Date().timeIntervalSince(startTime) > timeoutSeconds {
                    print("⏰ [DEBUG] Timeout reached (\(timeoutSeconds)s), terminating process")
                    task.terminate()

                    usleep(100000)  // 0.1 seconds

                    if task.isRunning {
                        print("🔪 [DEBUG] Process still running after terminate, waiting...")
                    }

                    print("❌ [DEBUG] mountDevice timed out for \(devicePath)")
                    return false
                }

                let now = Date()
                if now.timeIntervalSince(lastOutputCheck) >= outputCheckInterval {
                    let elapsed = now.timeIntervalSince(startTime)
                    print("⏳ [DEBUG] Process running for \(String(format: "%.1f", elapsed))s...")
                    lastOutputCheck = now
                }

                usleep(50000)  // 0.05 seconds
            }

            print("✅ [DEBUG] Process completed")
            print("🏁 [DEBUG] Exit code: \(task.terminationStatus)")

            return task.terminationStatus == 0
        } catch {
            print("❌ [DEBUG] Failed to run diskutil mount: \(error)")
            return false
        }
    }

    // MARK: - Initializers
    /// Creates a Device from detection with optional existing inventory item
    init(
        devicePath: String,
        isRemovable: Bool,
        isEjectable: Bool,
        isReadOnly: Bool,
        isSystemDrive: Bool,
        diskDescription: [String: Any]?,
        partitions: [PartitionInfo],
        inventoryItem: DeviceInventoryItem? = nil
    ) {
        self.devicePath = devicePath
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.isReadOnly = isReadOnly
        self.isSystemDrive = isSystemDrive
        self.diskDescription = diskDescription
        self.partitions = partitions
        self.inventoryItem = inventoryItem
    }

    /// Creates a Device from an existing DeviceInventoryItem (for known devices)
    init(
        from inventoryItem: DeviceInventoryItem, devicePath: String, isRemovable: Bool,
        isEjectable: Bool, isReadOnly: Bool, isSystemDrive: Bool, diskDescription: [String: Any]?,
        partitions: [PartitionInfo]
    ) {
        self.devicePath = devicePath
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.isReadOnly = isReadOnly
        self.isSystemDrive = isSystemDrive
        self.diskDescription = diskDescription
        self.partitions = partitions
        self.inventoryItem = inventoryItem
    }

    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(mediaUUID)
    }

    static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.mediaUUID == rhs.mediaUUID
    }

    /// Generates a stable device identifier from Disk Arbitration data
    /// This is used when no inventory item exists yet
    private func generateStableDeviceID() -> String {
        guard let diskDescription = diskDescription else { return "" }
        return Device.generateStableDeviceID(from: diskDescription)
    }

    /// Static helper to generate a stable device identifier from a Disk Arbitration description dictionary.
    /// Used by detection services to correlate devices when DA media UUID is unavailable.
    static func generateStableDeviceID(from diskDescription: [String: Any]) -> String {
        let deviceVendor =
            diskDescription[kDADiskDescriptionDeviceVendorKey as String] as? String ?? "Unknown"
        let deviceRevision =
            diskDescription[kDADiskDescriptionDeviceRevisionKey as String] as? String ?? "Unknown"
        let mediaSize = diskDescription[kDADiskDescriptionMediaSizeKey as String] as? Int64 ?? 0

        // Get first 4 digits of media size
        let mediaSizeString = String(mediaSize)
        let sizePrefix =
            mediaSizeString.count >= 4 ? String(mediaSizeString.prefix(4)) : mediaSizeString

        // Clean up vendor and revision names
        let cleanVendor = deviceVendor.replacingOccurrences(of: " ", with: "_")
        let cleanRevision = deviceRevision.replacingOccurrences(of: " ", with: "_")

        return "\(cleanVendor)_\(cleanRevision)_\(sizePrefix)"
    }
}

// MARK: - Disk Arbitration accessors

extension Device {
    private func daString(_ key: String) -> String? {
        guard let value = diskDescription?[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    /// DADeviceProtocol (e.g., "USB", "SATA")
    var daDeviceProtocol: String? { daString(kDADiskDescriptionDeviceProtocolKey as String) }

    /// Device model from Disk Arbitration.
    var daDeviceModel: String? { daString(kDADiskDescriptionDeviceModelKey as String) }

    /// Vendor from Disk Arbitration.
    var daVendor: String? { daString(kDADiskDescriptionDeviceVendorKey as String) }

    /// Revision from Disk Arbitration.
    var daRevision: String? { daString(kDADiskDescriptionDeviceRevisionKey as String) }

    /// Media name from Disk Arbitration.
    var daMediaName: String? { daString(kDADiskDescriptionMediaNameKey as String) }

    /// Volume name from Disk Arbitration.
    var daVolumeName: String? {
        daString(kDADiskDescriptionVolumeNameKey as String)
            ?? daString(kDADiskDescriptionMediaNameKey as String)
    }

    /// Volume/filesystem kind, if available (e.g. "apfs", "msdos").
    var daVolumeKind: String? {
        daString(kDADiskDescriptionVolumeKindKey as String)
            ?? daString(kDADiskDescriptionMediaKindKey as String)
    }

    /// Volume mount path as string, if available.
    var daVolumePath: String? {
        if let url = diskDescription?[kDADiskDescriptionVolumePathKey as String] as? URL {
            return url.path
        }
        if let path = diskDescription?[kDADiskDescriptionVolumePathKey as String] as? String {
            return path
        }
        return nil
    }

    /// Device name derived from Disk Arbitration with fallback chain.
    /// Tries: DAVolumeName → DAMediaName → DADeviceModel → DADeviceProtocol → Vendor+Product
    var daDeviceName: String? {
        // Try volume name first
        if let volumeName = daString(kDADiskDescriptionVolumeNameKey as String) {
            return volumeName
        }
        // Try media name
        if let mediaName = daString(kDADiskDescriptionMediaNameKey as String) { return mediaName }
        // Try device model
        if let deviceModel = daString(kDADiskDescriptionDeviceModelKey as String) {
            return deviceModel
        }
        // Try device protocol
        if let deviceProtocol = daString(kDADiskDescriptionDeviceProtocolKey as String) {
            return deviceProtocol
        }
        // Try vendor + product combination
        if let vendor = daString(kDADiskDescriptionDeviceVendorKey as String),
            let product = diskDescription?["DADeviceProduct"] as? String
        {
            return "\(vendor) \(product)"
        }
        return nil
    }
}

// MARK: - Debug helpers

#if DEBUG
    extension Device {
        /// Prints all available Disk Arbitration description key/values for this device.
        ///
        /// Usage: call `device.logDiskDescription()` from debug code paths when you
        /// need to inspect raw DA metadata without re-querying the system. This uses
        /// the captured `diskDescription` stored on the model.
        func logDiskDescription() {
            guard let desc = diskDescription, !desc.isEmpty else {
                print("[Device][DA] No diskDescription captured for: \(devicePath)")
                return
            }
            print("[Device][DA] Description for \(devicePath) → \(displayName)")
            for (key, value) in desc.sorted(by: { $0.key < $1.key }) {
                print("   \(key): \(value)")
            }
        }
    }
#endif
