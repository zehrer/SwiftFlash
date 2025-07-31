//
//  DriveDetectionService.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation
import Combine
import IOKit
import IOKit.storage
import IOKit.usb

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
        
        print("🔍 [DEBUG] Starting drive detection using IOKit...")
        
        // Get all USB storage devices using IOKit
        let devices = getUSBStorageDevices()
        print("🔍 [DEBUG] Found \(devices.count) USB storage devices")
        
        for (index, deviceInfo) in devices.enumerated() {
            print("\n🔍 [DEBUG] Checking device \(index + 1): \(deviceInfo.name)")
            print("✅ [DEBUG] Device: \(deviceInfo.name)")
            print("   📍 Device path: \(deviceInfo.devicePath)")
            print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: deviceInfo.size, countStyle: .file))")
            print("   🔄 Removable: \(deviceInfo.isRemovable)")
            print("   ⏏️ Ejectable: \(deviceInfo.isEjectable)")
            print("   🔌 Protocol: \(deviceInfo.connectionProtocol)")
            print("   📝 Read-only: \(deviceInfo.isReadOnly)")
            
            // Check if this is a valid USB drive for flashing
            print("🔍 [DEBUG] Running USB drive validation...")
            let driveCheck = isUSBDevice(deviceInfo: deviceInfo)
            
            if driveCheck.isValid {
                print("✅ [DEBUG] Device \(deviceInfo.name) is a valid USB drive (read-only: \(driveCheck.isReadOnly))")
                
                let drive = Drive(
                    name: deviceInfo.name,
                    mountPoint: deviceInfo.devicePath,
                    size: deviceInfo.size,
                    isRemovable: true,
                    isSystemDrive: false,
                    isReadOnly: driveCheck.isReadOnly
                )
                drives.append(drive)
            } else {
                print("❌ [DEBUG] Device \(deviceInfo.name) is NOT a valid USB drive")
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
    let devicePath: String
    let size: Int64
    let isRemovable: Bool
    let isEjectable: Bool
    let connectionProtocol: String
    let isReadOnly: Bool
}

// MARK: - IOKit Device Detection Functions

extension DriveDetectionService {
    
    /// Gets all USB storage devices using IOKit
    private func getUSBStorageDevices() -> [DeviceInfo] {
        var devices: [DeviceInfo] = []
        
        // Create a matching dictionary for USB storage devices
        let matchingDict = IOServiceMatching(kIOMediaClass) as NSMutableDictionary
        matchingDict["Removable"] = true
        matchingDict["Ejectable"] = true
        
        // Get an iterator for all matching devices
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        
        guard result == kIOReturnSuccess else {
            print("❌ [DEBUG] Failed to get IOKit services: \(result)")
            return devices
        }
        
        defer {
            IOObjectRelease(iterator)
        }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            if let deviceInfo = getDeviceInfoFromIOKit(service: service) {
                // Only include USB devices
                if deviceInfo.connectionProtocol.lowercased().contains("usb") {
                    devices.append(deviceInfo)
                }
            }
        }
        
        return devices
    }
    
    /// Gets detailed information about a specific IOKit device
    private func getDeviceInfoFromIOKit(service: io_object_t) -> DeviceInfo? {
        // Get device properties
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        
        guard result == kIOReturnSuccess, let props = properties?.takeRetainedValue() as? [String: Any] else {
            print("❌ [DEBUG] Failed to get device properties")
            return nil
        }
        
        // Extract device information
        let name = getDeviceName(from: props) ?? "Unknown Device"
        let devicePath = getDevicePath(from: props) ?? "/dev/unknown"
        let size = getDeviceSize(from: props)
        let isRemovable = props["Removable"] as? Bool ?? false
        let isEjectable = props["Ejectable"] as? Bool ?? false
        let connectionProtocol = getConnectionProtocol(from: props)
        let isReadOnly = props["Writable"] as? Bool == false
        
        print("🔍 [DEBUG] IOKit device: \(name)")
        print("   📍 Device path: \(devicePath)")
        print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        print("   🔄 Removable: \(isRemovable)")
        print("   ⏏️ Ejectable: \(isEjectable)")
        print("   🔌 Protocol: \(connectionProtocol)")
        print("   📝 Read-only: \(isReadOnly)")
        
        return DeviceInfo(
            name: name,
            devicePath: devicePath,
            size: size,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
            connectionProtocol: connectionProtocol,
            isReadOnly: isReadOnly
        )
    }
    
    /// Extracts device name from IOKit properties
    private func getDeviceName(from props: [String: Any]) -> String? {
        // Try different property keys for device name
        if let name = props["Media Name"] as? String, !name.isEmpty {
            return name
        }
        if let name = props["Product Name"] as? String, !name.isEmpty {
            return name
        }
        if let name = props["USB Product Name"] as? String, !name.isEmpty {
            return name
        }
        return nil
    }
    
    /// Extracts device path from IOKit properties
    private func getDevicePath(from props: [String: Any]) -> String? {
        // Get the BSD device name
        if let bsdName = props["BSD Name"] as? String {
            return "/dev/\(bsdName)"
        }
        return nil
    }
    
    /// Extracts device size from IOKit properties
    private func getDeviceSize(from props: [String: Any]) -> Int64 {
        if let size = props["Media Size"] as? Int64 {
            return size
        }
        return 0
    }
    
    /// Extracts connection protocol from IOKit properties
    private func getConnectionProtocol(from props: [String: Any]) -> String {
        // Check for USB-specific properties
        if props["USB Vendor Name"] != nil || props["USB Product Name"] != nil {
            return "USB"
        }
        
        // Check for other connection types
        if let protocolType = props["Protocol Characteristics"] as? String {
            return protocolType
        }
        
        return "Unknown"
    }
    
    /// Checks if a device is a valid USB drive for flashing
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