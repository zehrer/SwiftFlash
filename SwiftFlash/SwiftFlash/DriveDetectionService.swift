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
        
        // Get all disk devices using diskutil list
        let devices = getDiskDevices()
        print("🔍 [DEBUG] Found \(devices.count) disk devices")
        
        for (index, devicePath) in devices.enumerated() {
            print("\n🔍 [DEBUG] Checking device \(index + 1): \(devicePath)")
            
            // Get detailed information about this device
            let deviceInfo = getDeviceInfo(devicePath: devicePath)
            
            if let info = deviceInfo {
                print("✅ [DEBUG] Device: \(devicePath)")
                print("   📍 Device path: \(devicePath)")
                print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: info.size, countStyle: .file))")
                print("   🔄 Removable: \(info.isRemovable)")
                print("   ⏏️ Ejectable: \(info.isEjectable)")
                print("   🔌 Protocol: \(info.connectionProtocol)")
                print("   📝 Read-only: \(info.isReadOnly)")
                
                // Check if this is a valid USB drive
                print("🔍 [DEBUG] Running USB drive validation...")
                let driveCheck = isUSBDevice(deviceInfo: info)
                
                if driveCheck.isValid {
                    print("✅ [DEBUG] Device \(devicePath) is a valid USB drive (read-only: \(driveCheck.isReadOnly))")
                    
                    let drive = Drive(
                        name: info.name,
                        mountPoint: devicePath, // Use device path instead of mount point
                        size: info.size,
                        isRemovable: true,
                        isSystemDrive: false,
                        isReadOnly: driveCheck.isReadOnly
                    )
                    drives.append(drive)
                } else {
                    print("❌ [DEBUG] Device \(devicePath) is NOT a valid USB drive")
                }
            } else {
                print("❌ [DEBUG] Failed to get device info for \(devicePath)")
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

// MARK: - Device Info Structure

struct DeviceInfo {
    let name: String
    let size: Int64
    let isRemovable: Bool
    let isEjectable: Bool
    let connectionProtocol: String
    let isReadOnly: Bool
}

// MARK: - Device Detection Functions

extension DriveDetectionService {
    
    /// Gets all disk devices using diskutil list
    private func getDiskDevices() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["list"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        var devices: [String] = []
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("🔍 [DEBUG] diskutil list output:")
                print(output)
                
                let lines = output.components(separatedBy: .newlines)
                
                for line in lines {
                    // Look for lines that start with /dev/disk
                    if line.contains("/dev/disk") {
                        let components = line.components(separatedBy: " ")
                        for component in components {
                            if component.hasPrefix("/dev/disk") {
                                devices.append(component)
                                break
                            }
                        }
                    }
                }
            }
        } catch {
            print("❌ [DEBUG] diskutil list failed with error: \(error)")
        }
        
        return devices
    }
    
    /// Gets detailed information about a specific device
    private func getDeviceInfo(devicePath: String) -> DeviceInfo? {
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
                print("🔍 [DEBUG] diskutil info for \(devicePath):")
                print(output)
                
                return parseDeviceInfo(output: output, devicePath: devicePath)
            }
        } catch {
            print("❌ [DEBUG] diskutil info failed with error: \(error)")
        }
        
        return nil
    }
    
    /// Parses diskutil info output into DeviceInfo struct
    private func parseDeviceInfo(output: String, devicePath: String) -> DeviceInfo? {
        let lines = output.components(separatedBy: .newlines)
        
        var name = "Unknown Device"
        var size: Int64 = 0
        var isRemovable = false
        var isEjectable = false
        var connectionProtocol = "Unknown"
        var isReadOnly = false
        
        for line in lines {
            let lowercasedLine = line.lowercased()
            
            // Device name
            if line.contains("Device / Media Name:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    name = components[1].trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Size
            if line.contains("Total Size:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    let sizeString = components[1].trimmingCharacters(in: .whitespaces)
                    // Parse size like "15.6 GB (15,728,640,000 Bytes)"
                    if let byteRange = sizeString.range(of: "\\(([0-9,]+) Bytes\\)") {
                        let byteString = String(sizeString[byteRange])
                            .replacingOccurrences(of: "(", with: "")
                            .replacingOccurrences(of: ")", with: "")
                            .replacingOccurrences(of: " Bytes", with: "")
                            .replacingOccurrences(of: ",", with: "")
                        size = Int64(byteString) ?? 0
                    }
                }
            }
            
            // Removable
            if lowercasedLine.contains("removable media:") && lowercasedLine.contains("yes") {
                isRemovable = true
            }
            
            // Ejectable
            if lowercasedLine.contains("ejectable:") && lowercasedLine.contains("yes") {
                isEjectable = true
            }
            
            // Protocol
            if lowercasedLine.contains("protocol:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    connectionProtocol = components[1].trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Read-only
            if lowercasedLine.contains("read-only media:") && lowercasedLine.contains("yes") {
                isReadOnly = true
            }
        }
        
        return DeviceInfo(
            name: name,
            size: size,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
            connectionProtocol: connectionProtocol,
            isReadOnly: isReadOnly
        )
    }
    
    /// Checks if a device is a valid USB drive
    private func isUSBDevice(deviceInfo: DeviceInfo) -> (isValid: Bool, isReadOnly: Bool) {
        print("🔍 [DEBUG] isUSBDevice() - Checking: \(deviceInfo.name)")
        
        // Must be removable and ejectable
        guard deviceInfo.isRemovable && deviceInfo.isEjectable else {
            print("❌ [DEBUG] Device is not removable or ejectable")
            return (isValid: false, isReadOnly: false)
        }
        
        // Must be USB protocol
        guard deviceInfo.connectionProtocol.lowercased().contains("usb") else {
            print("❌ [DEBUG] Device protocol is not USB: \(deviceInfo.connectionProtocol)")
            return (isValid: false, isReadOnly: false)
        }
        
        // Skip if it's read-only media (like CD-ROM)
        if deviceInfo.isReadOnly {
            print("⚠️ [DEBUG] Device is read-only media")
            return (isValid: true, isReadOnly: true)
        }
        
        print("✅ [DEBUG] Device is a valid USB device")
        return (isValid: true, isReadOnly: false)
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