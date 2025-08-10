//
//  DriveModel.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation

// This Drive model is used throughout the application and changes here
// will affect device detection, UI display, and data persistence.
// Any modifications require thorough testing of all dependent components.
struct Drive: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let mountPoint: String
    let size: Int64
    let isRemovable: Bool
    let isSystemDrive: Bool
    let isReadOnly: Bool
    let mediaUUID: String? // Added for inventory tracking
    let mediaName: String? // Specific DAMediaName from Disk Arbitration
    let vendor: String? // DADeviceVendor from Disk Arbitration
    let revision: String? // DADeviceRevision from Disk Arbitration
    /// Raw Disk Arbitration description dictionary for this disk (not persisted).
    /// Provides on-demand access to additional DA attributes without repeated lookups.
    let diskDescription: [String: Any]?
    var deviceType: DeviceType = .unknown // Device type for display and settings
    var partitionScheme: ImageFileService.PartitionScheme = .unknown // Cached partition scheme
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var displayName: String {
        if name.isEmpty {
            return "Unknown Drive"
        }
        return name
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(mountPoint)
    }
    
    static func == (lhs: Drive, rhs: Drive) -> Bool {
        return lhs.mountPoint == rhs.mountPoint
    }
    
    /// Unmount the device using diskutil unmountDisk command with timeout protection
    /// - Returns: Bool indicating success (true) or failure (false)
    /// - Note: This method includes timeout protection and detailed logging
    @discardableResult
    func unmountDevice() -> Bool {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments = ["unmountDisk", mountPoint]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("📤 diskutil output:\n\(output)")

            return task.terminationStatus == 0
        } catch {
            print("❌ Failed to run diskutil: \(error)")
            return false
        }
    }
    
    /// Mount the device using diskutil mount command with timeout protection
    /// - Returns: Bool indicating success (true) or failure (false)
    /// - Note: Uses same reliable pattern as unmountDevice() with timeout protection
    @discardableResult
    func mountDevice() -> Bool {
        print("🔄 [DEBUG] Starting mount for: \(mountPoint)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["mount", mountPoint]

        // Don't use pipes - they can cause blocking
        task.standardOutput = nil
        task.standardError = nil

        do {
            print("🚀 [DEBUG] Launching diskutil mount \(mountPoint)")
            try task.run()
            
            // Create a timeout mechanism
            let timeoutSeconds: TimeInterval = 10.0
            let startTime = Date()
            
            // Check if process is still running with timeout
            var lastOutputCheck = Date()
            let outputCheckInterval: TimeInterval = 0.5 // Check output every 0.5 seconds
            
            while task.isRunning {
                if Date().timeIntervalSince(startTime) > timeoutSeconds {
                    print("⏰ [DEBUG] Timeout reached (\(timeoutSeconds)s), terminating process")
                    task.terminate()
                    
                    // Give it a moment to clean up
                    usleep(100000) // 0.1 seconds
                    
                    if task.isRunning {
                        print("🔪 [DEBUG] Process still running after terminate, waiting...")
                        // Process.kill() doesn't exist in Swift, terminate() should be sufficient
                    }
                    
                    print("❌ [DEBUG] mountDevice timed out for \(mountPoint)")
                    return false
                }
                
                // Show progress indicator periodically
                let now = Date()
                if now.timeIntervalSince(lastOutputCheck) >= outputCheckInterval {
                    let elapsed = now.timeIntervalSince(startTime)
                    print("⏳ [DEBUG] Process running for \(String(format: "%.1f", elapsed))s...")
                    lastOutputCheck = now
                }
                
                // Small sleep to prevent busy waiting
                usleep(50000) // 0.05 seconds
            }
            
            print("✅ [DEBUG] Process completed")
            print("🏁 [DEBUG] Exit code: \(task.terminationStatus)")

            return task.terminationStatus == 0
        } catch {
            print("❌ [DEBUG] Failed to run diskutil mount: \(error)")
            return false
        }
    }
}

// MARK: - Disk Arbitration accessors

extension Drive {
    private func daString(_ key: String) -> String? {
        // First try to get from stored diskDescription (if available)
        if let value = diskDescription?[key] as? String, !value.isEmpty {
            return value
        }
        
        // Fallback to live Disk Arbitration lookup
        return DiskArbitrationUtils.getStringValue(for: mountPoint, key: key)
    }

    /// DADeviceProtocol (e.g., "USB", "SATA")
    var daDeviceProtocol: String? { daString(kDADiskDescriptionDeviceProtocolKey as String) }

    /// Vendor from Disk Arbitration. Falls back to stored `vendor` property.
    var daVendor: String? { vendor ?? daString(kDADiskDescriptionDeviceVendorKey as String) }

    /// Revision from Disk Arbitration. Falls back to stored `revision` property.
    var daRevision: String? { revision ?? daString(kDADiskDescriptionDeviceRevisionKey as String) }

    /// Volume name from Disk Arbitration. Falls back to stored `mediaName` property.
    var daVolumeName: String? { daString(kDADiskDescriptionVolumeNameKey as String) ?? daString(kDADiskDescriptionMediaNameKey as String) ?? mediaName }

    /// Volume/filesystem kind, if available (e.g. "apfs", "msdos").
    var daVolumeKind: String? { daString(kDADiskDescriptionVolumeKindKey as String) ?? daString(kDADiskDescriptionMediaKindKey as String) }

    /// Volume mount path as string, if available.
    var daVolumePath: String? {
        // First try to get from stored diskDescription (if available)
        if let url = diskDescription?[kDADiskDescriptionVolumePathKey as String] as? URL { return url.path }
        if let path = diskDescription?[kDADiskDescriptionVolumePathKey as String] as? String { return path }
        
        // Fallback to live Disk Arbitration lookup
        if let url: URL = DiskArbitrationUtils.getValue(for: mountPoint, key: kDADiskDescriptionVolumePathKey as String) {
            return url.path
        }
        return DiskArbitrationUtils.getStringValue(for: mountPoint, key: kDADiskDescriptionVolumePathKey as String)
    }
}

// MARK: - Debug helpers

#if DEBUG
extension Drive {
    /// Prints all available Disk Arbitration description key/values for this drive.
    ///
    /// Usage: call `drive.logDiskDescription()` from debug code paths when you
    /// need to inspect raw DA metadata without re-querying the system. This uses
    /// the captured `diskDescription` stored on the model.
    func logDiskDescription() {
        guard let desc = diskDescription, !desc.isEmpty else {
            print("[Drive][DA] No diskDescription captured for: \(mountPoint)")
            return
        }
        print("[Drive][DA] Description for \(mountPoint) → \(displayName)")
        for (key, value) in desc.sorted(by: { $0.key < $1.key }) {
            print("   \(key): \(value)")
        }
    }
}
#endif
