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

@MainActor
class DriveDetectionService: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var isScanning = false

    init() {
        refreshDrives()
    }
    
    deinit {
        // Cleanup will be added when DiskArbitration is re-enabled
    }
    
    /// Refreshes the list of available drives
    func refreshDrives() {
        isScanning = true
        
        Task {
            let detectedDrives = await detectDrives()
            self.drives = detectedDrives
            self.isScanning = false
        }
    }
    
    /// Detects all external storage devices that can be used for flashing
    private func detectDrives() async -> [Drive] {
        var drives: [Drive] = []
        
        print("🔍 [DEBUG] Starting external drive detection...")
        
        // Get all external storage devices using IOKit
        let devices = getExternalStorageDevices()
        print("🔍 [DEBUG] Found \(devices.count) external storage devices")
        
        // Get the system boot device to exclude it
        let systemBootDevice = getSystemBootDevice()
        print("🔍 [DEBUG] System boot device: \(systemBootDevice)")
        
        for (index, deviceInfo) in devices.enumerated() {
            print("\n🔍 [DEBUG] Checking device \(index + 1): \(deviceInfo.name)")
            print("   📍 Device path: \(deviceInfo.devicePath)")
            print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: deviceInfo.size, countStyle: .file))")
            print("   🔄 Removable: \(deviceInfo.isRemovable)")
            print("   ⏏️ Ejectable: \(deviceInfo.isEjectable)")
            print("   📝 Read-only: \(deviceInfo.isReadOnly)")
            
            // Check if this is the system boot device
            let isSystemDrive = deviceInfo.devicePath == systemBootDevice
            
            if isSystemDrive {
                print("⚠️ [DEBUG] Device \(deviceInfo.name) is the system boot device - excluding")
                continue
            }
            
            print("✅ [DEBUG] Device \(deviceInfo.name) is a valid external drive (read-only: \(deviceInfo.isReadOnly))")
            
            let drive = Drive(
                name: deviceInfo.name,
                mountPoint: deviceInfo.devicePath,
                size: deviceInfo.size,
                isRemovable: true,
                isSystemDrive: false,
                isReadOnly: deviceInfo.isReadOnly
            )
            drives.append(drive)
        }
        
        print("\n🔍 [DEBUG] Drive detection complete. Found \(drives.count) valid external drives:")
        for drive in drives {
            print("   📱 \(drive.displayName) (\(drive.formattedSize)) - Read-only: \(drive.isReadOnly)")
        }
        
        return drives
    }
}

// MARK: - Device Info Structure

struct DeviceInfo {
    let name: String
    let devicePath: String
    let size: Int64
    let isRemovable: Bool
    let isEjectable: Bool
    let isReadOnly: Bool
}

// MARK: - IOKit Device Detection Functions

extension DriveDetectionService {
    
    /// Gets all external storage devices using IOKit
    private func getExternalStorageDevices() -> [DeviceInfo] {
        var devices: [DeviceInfo] = []
        
        // Create a matching dictionary for removable storage devices
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
                // Only include main devices (not partitions)
                if isMainDevice(deviceInfo: deviceInfo) {
                    devices.append(deviceInfo)
                } else {
                    print("🔍 [DEBUG] Skipping partition: \(deviceInfo.devicePath)")
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
        let isReadOnly = props["Writable"] as? Bool == false
        
        print("🔍 [DEBUG] IOKit device: \(name)")
        print("   📍 Device path: \(devicePath)")
        print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        print("   🔄 Removable: \(isRemovable)")
        print("   ⏏️ Ejectable: \(isEjectable)")
        print("   📝 Read-only: \(isReadOnly)")
        
        // Debug: Print all available properties for troubleshooting
        print("   🔍 [DEBUG] Available properties:")
        for (key, value) in props {
            print("      \(key): \(value)")
        }
        
        return DeviceInfo(
            name: name,
            devicePath: devicePath,
            size: size,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
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
        if let name = props["Device Name"] as? String, !name.isEmpty {
            return name
        }
        if let name = props["IOUserClass"] as? String, !name.isEmpty {
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
        // Try different property keys for device size
        if let size = props["Media Size"] as? Int64 {
            return size
        }
        if let size = props["Size"] as? Int64 {
            return size
        }
        if let size = props["Total Size"] as? Int64 {
            return size
        }
        if let size = props["Capacity"] as? Int64 {
            return size
        }
        return 0
    }
    
    /// Checks if a device is a main device (not a partition)
    private func isMainDevice(deviceInfo: DeviceInfo) -> Bool {
        // Check if the device path contains partition indicators
        let devicePath = deviceInfo.devicePath
        
        // Skip if it's a partition (contains 's' followed by numbers)
        if devicePath.range(of: #"s\d+$"#, options: .regularExpression) != nil {
            return false
        }
        
        // Skip if it's a slice (contains 's' followed by numbers)
        if devicePath.contains("s") && devicePath.components(separatedBy: "s").count > 1 {
            let lastComponent = devicePath.components(separatedBy: "s").last ?? ""
            if Int(lastComponent) != nil {
                return false
            }
        }
        
        return true
    }
    
    /// Gets the system boot device path to exclude it from the list
    private func getSystemBootDevice() -> String {
        // Use diskutil to get the system boot device
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "/"]
        
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
            print("❌ [DEBUG] Failed to get system boot device: \(error)")
        }
        
        // Fallback: return empty string if we can't determine
        return ""
    }
} 