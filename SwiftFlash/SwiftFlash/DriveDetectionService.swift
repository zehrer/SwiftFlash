//
//  DriveDetectionService.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation
import Combine

@MainActor
class DriveDetectionService: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var isScanning = false
    
    private var mountedVolumes: Set<String> = []
    
    init() {
        refreshDrives()
    }
    
    deinit {
        // Cleanup will be added when DiskArbitration is re-enabled
    }
    
    private func setupDiskArbitration() {
        // Temporarily disabled for compilation
        // session = DASessionCreate(kCFAllocatorDefault)
        // guard let session = session else { return }
        // 
        // DASessionSetDispatchQueue(session, DispatchQueue.main)
        // DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue as CFString)
        // 
        // // Register callbacks for disk appearance and disappearance
        // DARegisterDiskAppearedCallback(session, nil, diskAppearedCallback, Unmanaged.passUnretained(self).toOpaque())
        // DARegisterDiskDisappearedCallback(session, nil, diskDisappearedCallback, Unmanaged.passUnretained(self).toOpaque())
    }
    
    func refreshDrives() {
        isScanning = true
        
        Task {
            let detectedDrives = await detectDrives()
            self.drives = detectedDrives
            self.isScanning = false
        }
    }
    
    private func detectDrives() async -> [Drive] {
        var drives: [Drive] = []
        
        print("🔍 [DEBUG] Starting drive detection...")
        
        // Get mounted volumes
        let fileManager = FileManager.default
        let mountedVolumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeNameKey, 
            .volumeTotalCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsLocalKey,
            .volumeIsReadOnlyKey
        ], options: [])
        
        print("🔍 [DEBUG] Found \(mountedVolumes?.count ?? 0) mounted volumes")
        
        for (index, volumeURL) in (mountedVolumes ?? []).enumerated() {
            print("\n🔍 [DEBUG] Checking volume \(index + 1): \(volumeURL.path)")
            
            guard let resourceValues = try? volumeURL.resourceValues(forKeys: [
                .volumeNameKey, 
                .volumeTotalCapacityKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeIsLocalKey,
                .volumeIsReadOnlyKey
            ]),
            let volumeName = resourceValues.volumeName,
            let totalCapacity = resourceValues.volumeTotalCapacity else {
                print("❌ [DEBUG] Failed to get resource values for \(volumeURL.path)")
                continue
            }
            
            print("✅ [DEBUG] Volume: \(volumeName)")
            print("   📍 Mount point: \(volumeURL.path)")
            print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: Int64(totalCapacity), countStyle: .file))")
            print("   🔄 Removable: \(resourceValues.volumeIsRemovable ?? false)")
            print("   ⏏️ Ejectable: \(resourceValues.volumeIsEjectable ?? false)")
            print("   🏠 Local: \(resourceValues.volumeIsLocal ?? false)")
            print("   📝 Read-only: \(resourceValues.volumeIsReadOnly ?? false)")
            
            let mountPoint = volumeURL.path
            
            // Check if this is a valid USB drive
            print("🔍 [DEBUG] Running USB drive validation...")
            let driveCheck = isUSBDrive(resourceValues: resourceValues, mountPoint: mountPoint)
            
            if driveCheck.isValid {
                print("✅ [DEBUG] Volume \(volumeName) is a valid USB drive (read-only: \(driveCheck.isReadOnly))")
                
                let drive = Drive(
                    name: volumeName,
                    mountPoint: mountPoint,
                    size: Int64(totalCapacity),
                    isRemovable: true,
                    isSystemDrive: false,
                    isReadOnly: driveCheck.isReadOnly
                )
                drives.append(drive)
            } else {
                print("❌ [DEBUG] Volume \(volumeName) is NOT a valid USB drive")
            }
        }
        
        print("\n🔍 [DEBUG] Drive detection complete. Found \(drives.count) valid USB drives:")
        for drive in drives {
            print("   📱 \(drive.displayName) (\(drive.formattedSize)) - Read-only: \(drive.isReadOnly)")
        }
        
        return drives
    }
    
    private func isUSBDrive(resourceValues: URLResourceValues, mountPoint: String) -> (isValid: Bool, isReadOnly: Bool) {
        print("🔍 [DEBUG] isUSBDrive() - Checking: \(mountPoint)")
        
        // Must be removable and ejectable (typical USB drive characteristics)
        guard let isRemovable = resourceValues.volumeIsRemovable,
              let isEjectable = resourceValues.volumeIsEjectable,
              let isLocal = resourceValues.volumeIsLocal else {
            print("❌ [DEBUG] Missing required volume properties")
            return (isValid: false, isReadOnly: false)
        }
        
        print("🔍 [DEBUG] Volume properties: removable=\(isRemovable), ejectable=\(isEjectable), local=\(isLocal)")
        
        // Must be removable, ejectable, and local (not network)
        guard isRemovable && isEjectable && isLocal else {
            print("❌ [DEBUG] Volume does not meet basic requirements (removable && ejectable && local)")
            return (isValid: false, isReadOnly: false)
        }
        
        // Note: We don't check volumeIsReadOnly here because it refers to filesystem writability
        // not device writability. A drive with an unknown filesystem (like Linux) will show
        // as "not writable" but the device itself can still be overwritten for flashing.
        
        // Skip system volumes and known non-USB paths
        if mountPoint.hasPrefix("/System") || 
           mountPoint.hasPrefix("/Volumes/Data") ||
           mountPoint.hasPrefix("/private/var") ||
           mountPoint.hasPrefix("/tmp") ||
           mountPoint.hasPrefix("/usr") ||
           mountPoint.hasPrefix("/bin") ||
           mountPoint.hasPrefix("/sbin") ||
           mountPoint == "/" {
            print("❌ [DEBUG] Volume is a system path: \(mountPoint)")
            return (isValid: false, isReadOnly: false)
        }
        
        // Must be in /Volumes/ (standard mount point for external drives)
        guard mountPoint.hasPrefix("/Volumes/") else {
            print("❌ [DEBUG] Volume is not in /Volumes/: \(mountPoint)")
            return (isValid: false, isReadOnly: false)
        }
        
        // Skip Time Machine backup volumes and other known non-USB volumes
        let volumeName = mountPoint.components(separatedBy: "/").last ?? ""
        print("🔍 [DEBUG] Volume name: '\(volumeName)'")
        
        if volumeName.lowercased().contains("timemachine") ||
           volumeName.lowercased().contains("backup") ||
           volumeName.lowercased().contains("sparsebundle") ||
           volumeName.lowercased().contains("dmg") ||
           volumeName.lowercased().contains("iso") ||
           volumeName.lowercased().contains("virtual") {
            print("❌ [DEBUG] Volume name contains excluded keywords: \(volumeName)")
            return (isValid: false, isReadOnly: false)
        }
        
        // REQUIRED: Must have a valid device path to be considered a USB drive
        guard let devicePath = getDevicePath(for: mountPoint) else {
            print("❌ [DEBUG] Could not get device path for: \(mountPoint)")
            return (isValid: false, isReadOnly: false)
        }
        
        print("🔍 [DEBUG] Device path: \(devicePath)")
        
        // Must be a physical disk device (not virtual, not Time Machine, etc.)
        guard devicePath.hasPrefix("/dev/disk") && 
              !devicePath.contains("virtual") &&
              !devicePath.contains("timemachine") &&
              !devicePath.contains("sparsebundle") else {
            print("❌ [DEBUG] Device path validation failed: \(devicePath)")
            return (isValid: false, isReadOnly: false)
        }
        
        // Additional check: verify it's actually a USB device using diskutil
        print("🔍 [DEBUG] Running final USB device validation...")
        let deviceCheck = isPhysicalUSBDevice(devicePath: devicePath)
        
        if deviceCheck.isValid {
            print("✅ [DEBUG] Device is confirmed as USB device (read-only: \(deviceCheck.isReadOnly))")
        } else {
            print("❌ [DEBUG] Device failed USB validation")
        }
        
        return (isValid: deviceCheck.isValid, isReadOnly: deviceCheck.isReadOnly)
    }
    
    private func getDevicePath(for mountPoint: String) -> String? {
        // Use diskutil to get the device path for a mount point
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", mountPoint]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for the device identifier
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("Device Identifier:") {
                        let parts = line.components(separatedBy: ":")
                        if parts.count > 1 {
                            let deviceId = parts[1].trimmingCharacters(in: .whitespaces)
                            return "/dev/\(deviceId)"
                        }
                    }
                }
            }
        } catch {
            // If diskutil fails, we'll fall back to the volume properties
            return nil
        }
        
        return nil
    }
    
    private func isPhysicalUSBDevice(devicePath: String) -> (isValid: Bool, isReadOnly: Bool) {
        print("🔍 [DEBUG] isPhysicalUSBDevice() - Checking: \(devicePath)")
        
        // Use diskutil to get detailed information about the device
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", devicePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("🔍 [DEBUG] diskutil output for \(devicePath):")
                print(output)
                
                let lines = output.components(separatedBy: .newlines)
                
                // Check for USB-specific characteristics
                var hasUSBInterface = false
                var isRemovable = false
                var isEjectable = false
                var isReadOnly = false
                
                for line in lines {
                    let lowercasedLine = line.lowercased()
                    
                    // Check for USB interface
                    if lowercasedLine.contains("protocol:") && lowercasedLine.contains("usb") {
                        hasUSBInterface = true
                        print("✅ [DEBUG] Found USB interface")
                    }
                    
                    // Check for removable media
                    if lowercasedLine.contains("removable media:") && lowercasedLine.contains("yes") {
                        isRemovable = true
                        print("✅ [DEBUG] Found removable media")
                    }
                    
                    // Check for ejectable
                    if lowercasedLine.contains("ejectable:") && lowercasedLine.contains("yes") {
                        isEjectable = true
                        print("✅ [DEBUG] Found ejectable device")
                    }
                    
                    // Check for read-only device (like CD-ROM, write-protected)
                    if lowercasedLine.contains("read-only media:") && lowercasedLine.contains("yes") {
                        isReadOnly = true
                        print("⚠️ [DEBUG] Found read-only media")
                    }
                    
                    // Exclude if it's a Time Machine backup or sparse bundle
                    if lowercasedLine.contains("timemachine") ||
                       lowercasedLine.contains("sparsebundle") ||
                       lowercasedLine.contains("virtual") ||
                       lowercasedLine.contains("dmg") {
                        print("❌ [DEBUG] Device contains excluded keywords: \(line)")
                        return (isValid: false, isReadOnly: false)
                    }
                }
                
                // Must have USB interface and be removable/ejectable
                let isValid = hasUSBInterface && isRemovable && isEjectable
                print("🔍 [DEBUG] Device validation results:")
                print("   USB Interface: \(hasUSBInterface)")
                print("   Removable: \(isRemovable)")
                print("   Ejectable: \(isEjectable)")
                print("   Read-only: \(isReadOnly)")
                print("   Final result: \(isValid ? "VALID" : "INVALID")")
                return (isValid: isValid, isReadOnly: isReadOnly)
            }
        } catch {
            // If diskutil fails, be conservative and exclude the device
            print("❌ [DEBUG] diskutil failed with error: \(error)")
            return (isValid: false, isReadOnly: false)
        }
        
        print("❌ [DEBUG] No diskutil output or parsing failed")
        return (isValid: false, isReadOnly: false)
    }
}

// MARK: - Disk Arbitration Callbacks (temporarily disabled)

// private func diskAppearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
//     guard let context = context else { return }
//     let service = Unmanaged<DriveDetectionService>.fromOpaque(context).takeUnretainedValue()
//     Task { @MainActor in
//         service.refreshDrives()
//     }
// }
// 
// private func diskDisappearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
//     guard let context = context else { return }
//     let service = Unmanaged<DriveDetectionService>.fromOpaque(context).takeUnretainedValue()
//     Task { @MainActor in
//         service.refreshDrives()
//     }
// } 