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
@preconcurrency import DiskArbitration

@MainActor
class DriveDetectionService: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var isScanning = false
    
    private var diskArbitrationSession: DASession?
    private let inventory = DeviceInventory()
    
    init() {
        setupDiskArbitration()
        refreshDrives()
    }
    
    deinit {
        // Capture the session before deinit to avoid Sendable issues
        let session = diskArbitrationSession
        if let session = session {
            DASessionUnscheduleFromRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        }
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
    
    /// Gets the current inventory of devices
    var deviceInventory: [DeviceInventoryItem] {
        return inventory.devices
    }
    
    /// Debug function to print all Disk Arbitration information for a drive
    func printDiskArbitrationInfo(for drive: Drive) {
        print("🔍 [DEBUG] === Disk Arbitration Info for Drive: \(drive.displayName) ===")
        print("📍 Device Path: \(drive.mountPoint)")
        
        guard let session = diskArbitrationSession else {
            print("❌ [DEBUG] Disk Arbitration session is nil")
            return
        }
        
        // Extract the BSD name from the mount point (remove /dev/ prefix)
        let bsdName = drive.mountPoint.replacingOccurrences(of: "/dev/", with: "")
        
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName) else {
            print("❌ [DEBUG] Failed to create disk object for: \(bsdName)")
            return
        }
        
        guard let diskDescription = DADiskCopyDescription(disk) as? [String: Any] else {
            print("❌ [DEBUG] Failed to get disk description for: \(bsdName)")
            return
        }
        
        print("🔧 [DEBUG] All available Disk Arbitration keys:")
        for (key, value) in diskDescription.sorted(by: { $0.key < $1.key }) {
            print("   \(key): \(value)")
        }
        
        print("🔍 [DEBUG] === End Disk Arbitration Info ===")
    }
    
    /// Sets a custom name for a device
    func setCustomName(for mediaUUID: String, customName: String) {
        print("🔧 [DEBUG] DriveDetectionService.setCustomName called with UUID: \(mediaUUID), name: \(customName)")
        inventory.setCustomName(for: mediaUUID, customName: customName)
        // Refresh drives to update the display
        refreshDrives()
    }
    
    /// Removes a device from inventory
    func removeFromInventory(mediaUUID: String) {
        inventory.removeDevice(mediaUUID: mediaUUID)
    }
    
    /// Sets up Disk Arbitration session for device monitoring
    private func setupDiskArbitration() {
        diskArbitrationSession = DASessionCreate(kCFAllocatorDefault)
        guard let session = diskArbitrationSession else {
            print("❌ [DEBUG] Failed to create Disk Arbitration session")
            return
        }
        
        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        print("✅ [DEBUG] Disk Arbitration session created and scheduled")
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
            
            print("✅ [DEBUG] Found external drive: \(deviceInfo.name)")
            
            let drive = Drive(
                name: deviceInfo.name,
                mountPoint: deviceInfo.devicePath,
                size: deviceInfo.size,
                isRemovable: true,
                isSystemDrive: false,
                isReadOnly: deviceInfo.isReadOnly,
                mediaUUID: deviceInfo.mediaUUID,
                mediaName: deviceInfo.mediaName
            )
            drives.append(drive)
        }
        
        print("🔍 [DEBUG] Drive detection complete. Found \(drives.count) external drives")
        
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
    let mediaUUID: String?
    let mediaName: String?
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
                print("🔍 [DEBUG] Processing device: \(deviceInfo.devicePath)")
                // Only include main devices (not partitions)
                if isMainDevice(deviceInfo: deviceInfo) {
                    print("✅ [DEBUG] Adding device to list: \(deviceInfo.devicePath)")
                    devices.append(deviceInfo)
                } else {
                    print("❌ [DEBUG] Excluding device from list: \(deviceInfo.devicePath)")
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
        let devicePath = getDevicePath(from: props) ?? "/dev/unknown"
        let originalName = getDeviceNameFromDiskArbitration(devicePath: devicePath) ?? getDeviceNameFromParent(service: service) ?? getDeviceName(from: props) ?? "Unknown Device"
        let size = getDeviceSize(from: props)
        let isRemovable = props["Removable"] as? Bool ?? false
        let isEjectable = props["Ejectable"] as? Bool ?? false
        let isReadOnly = props["Writable"] as? Bool == false
        
        // Get media UUID and update inventory
        let mediaUUID = getMediaUUIDFromDiskArbitration(devicePath: devicePath)
        print("🔧 [DEBUG] getMediaUUIDFromDiskArbitration returned: \(mediaUUID ?? "nil") for device: \(devicePath)")
        let deviceType = getDeviceType(from: props)
        
        let name: String
        if let uuid = mediaUUID {
            print("🔧 [DEBUG] Adding device to inventory: \(originalName) with UUID: \(uuid)")
            inventory.addOrUpdateDevice(
                mediaUUID: uuid,
                devicePath: devicePath,
                size: size,
                deviceType: deviceType,
                originalName: originalName
            )
            
            // Use custom name from inventory if available, otherwise use original name
            name = inventory.getDisplayName(for: uuid) ?? originalName
            print("🔧 [DEBUG] Final display name: \(name)")
        } else {
            print("❌ [DEBUG] No media UUID found for device: \(originalName)")
            name = originalName
        }
        
        print("🔍 [DEBUG] Device: \(name)")
        print("   📍 Path: \(devicePath)")
        print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
        
        let mediaName = getMediaNameFromDiskArbitration(devicePath: devicePath)
        
        return DeviceInfo(
            name: name,
            devicePath: devicePath,
            size: size,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
            isReadOnly: isReadOnly,
            mediaUUID: mediaUUID,
            mediaName: mediaName
        )
    }
    
    /// Gets the specific DAMediaName from Disk Arbitration framework
    private func getMediaNameFromDiskArbitration(devicePath: String) -> String? {
        guard let session = diskArbitrationSession else {
            return nil
        }
        
        // Create a URL from the device path (not used but kept for future reference)
        _ = URL(fileURLWithPath: devicePath)
        
        // Get the disk object for this device
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, devicePath) else {
            return nil
        }

        // Get disk description
        guard let diskDescription = DADiskCopyDescription(disk) as? [String: Any] else {
            return nil
        }
        
        // Specifically get the DAMediaName
        if let mediaName = diskDescription["DAMediaName"] as? String, !mediaName.isEmpty {
            print("🔍 [DEBUG] Found DAMediaName: \(mediaName)")
            return mediaName
        }
        
        print("⚠️ [DEBUG] No DAMediaName found for device: \(devicePath)")
        return nil
    }
    
    /// Gets device name using Disk Arbitration framework
    private func getDeviceNameFromDiskArbitration(devicePath: String) -> String? {
        guard let session = diskArbitrationSession else {
            return nil
        }
        
        // Create a URL from the device path (not used but kept for future reference)
        _ = URL(fileURLWithPath: devicePath)
        
                // Get the disk object for this device
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, devicePath) else {
            return nil
        }

        // Get disk description
        guard let diskDescription = DADiskCopyDescription(disk) as? [String: Any] else {
            return nil
        }
        
        // Log the media UUID for inventory purposes
        if let mediaUUID = diskDescription["DADiskDescriptionMediaUUIDKey"] as? String {
            print("🔑 [DEBUG] Media UUID: \(mediaUUID)")
        }
        
        // Try to get the device name from various Disk Arbitration keys
        if let name = diskDescription["DAVolumeName"] as? String, !name.isEmpty {
            return name
        }
        
        if let name = diskDescription["DAMediaName"] as? String, !name.isEmpty {
            return name
        }
        
        if let name = diskDescription["DADeviceModel"] as? String, !name.isEmpty {
            return name
        }
        
        if let name = diskDescription["DADeviceProtocol"] as? String, !name.isEmpty {
            return name
        }
        
        // Try vendor and product names
        if let vendorName = diskDescription["DADeviceVendor"] as? String,
           let productName = diskDescription["DADeviceProduct"] as? String {
            let name = "\(vendorName) \(productName)"
            return name
        }
        
        return nil
    }
    
    /// Gets the media UUID from Disk Arbitration
    private func getMediaUUIDFromDiskArbitration(devicePath: String) -> String? {
        print("🔧 [DEBUG] getMediaUUIDFromDiskArbitration called for device: \(devicePath)")
        
        guard let session = diskArbitrationSession else {
            print("❌ [DEBUG] Disk Arbitration session is nil")
            return nil
        }
        
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, devicePath) else {
            print("❌ [DEBUG] Failed to create disk object for: \(devicePath)")
            return nil
        }
        
        guard let diskDescription = DADiskCopyDescription(disk) as? [String: Any] else {
            print("❌ [DEBUG] Failed to get disk description for: \(devicePath)")
            return nil
        }
        
        print("🔧 [DEBUG] Disk description keys available: \(Array(diskDescription.keys))")
        
        // Try different UUID keys that might be available
        let mediaUUID = diskDescription["DADiskDescriptionMediaUUIDKey"] as? String ??
                       diskDescription["DAVolumeUUID"] as? String ??
                       diskDescription["DAMediaUUID"] as? String
        
        print("🔧 [DEBUG] Media UUID extracted: \(mediaUUID ?? "nil")")
        
        // If no UUID found, create a fallback identifier using device properties
        if mediaUUID == nil {
            let deviceModel = diskDescription["DADeviceModel"] as? String ?? "Unknown"
            let deviceVendor = diskDescription["DADeviceVendor"] as? String ?? "Unknown"
            let mediaSize = diskDescription["DAMediaSize"] as? Int64 ?? 0
            let fallbackUUID = "\(deviceVendor)_\(deviceModel)_\(mediaSize)".replacingOccurrences(of: " ", with: "_")
            print("🔧 [DEBUG] Using fallback UUID: \(fallbackUUID)")
            return fallbackUUID
        }
        
        return mediaUUID
    }
    
    /// Gets the device type from IOKit properties
    private func getDeviceType(from props: [String: Any]) -> String {
        if let content = props["Content"] as? String {
            return content
        }
        if let contentHint = props["Content Hint"] as? String, !contentHint.isEmpty {
            return contentHint
        }
        return "Unknown"
    }
    
    /// Gets device name by traversing up the device tree to find USB device properties
    private func getDeviceNameFromParent(service: io_object_t) -> String? {
        var currentService = service
        var level = 0
        
                // Traverse up the device tree to find USB devices with name information
        while currentService != 0 {
            defer {
                if currentService != service {
                    IOObjectRelease(currentService)
                }
            }

            // Get properties of current service
            var properties: Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(currentService, &properties, kCFAllocatorDefault, 0)

            if result == kIOReturnSuccess, let props = properties?.takeRetainedValue() as? [String: Any] {
                // Try to get name from this level
                if let name = getDeviceName(from: props) {
                    return name
                }
            }
            
            // Get the parent device
            var parentService: io_object_t = 0
            let parentResult = IORegistryEntryGetParentEntry(currentService, kIOServicePlane, &parentService)
            
            if parentResult == kIOReturnSuccess {
                // Move up to the parent
                if currentService != service {
                    IOObjectRelease(currentService)
                }
                currentService = parentService
                level += 1
                                    } else {
                            // No more parents
                            break
                        }
                    }

                    return nil
    }
    
    /// Extracts device name from IOKit properties
    private func getDeviceName(from props: [String: Any]) -> String? {
        // Try different property keys for device name in order of preference
        let nameKeys = [
            "Media Name",
            "Product Name", 
            "Device Name",
            "USB Product Name",
            "USB Vendor Name",
            "IOUserClass",
            "Model",
            "Model Name",
            "Product ID",
            "Vendor ID",
            "IOUserClass",
            "IOClassName",
            "IOClass"
        ]
        
                            for key in nameKeys {
                        if let name = props[key] as? String, !name.isEmpty {
                            return name
                        }
                    }

                    // Also check for numeric IDs that might be useful
                    if let vendorId = props["idVendor"] as? Int,
                       let productId = props["idProduct"] as? Int {
                        let name = "USB Device (Vendor: \(String(format: "0x%04X", vendorId)), Product: \(String(format: "0x%04X", productId)))"
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
        
        print("🔍 [DEBUG] Checking if device is main device: \(devicePath)")
        
        // Skip if it's a partition (contains 's' followed by numbers)
        if devicePath.range(of: #"s\d+$"#, options: .regularExpression) != nil {
            print("❌ [DEBUG] Device \(devicePath) is a partition - excluding")
            return false
        }
        
        // Skip if it's a slice (contains 's' followed by numbers)
        if devicePath.contains("s") && devicePath.components(separatedBy: "s").count > 1 {
            let lastComponent = devicePath.components(separatedBy: "s").last ?? ""
            if Int(lastComponent) != nil {
                print("❌ [DEBUG] Device \(devicePath) is a slice - excluding")
                return false
            }
        }
        
        // Additional check: skip if it contains any partition indicators
        if devicePath.contains("s") {
            print("❌ [DEBUG] Device \(devicePath) contains partition indicator 's' - excluding")
            return false
        }
        
        print("✅ [DEBUG] Device \(devicePath) is a main device - including")
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