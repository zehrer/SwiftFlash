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


// This service orchestrates device detection and metadata enrichment for external storage.
//
// Responsibilities and framework boundaries:
// - IOKit (IORegistry):
//   * Enumerate candidate removable/ejectable media (kIOMediaClass)
//   * Read base properties (BSD Name → /dev/diskN, size, writable, etc.)
//   * Walk parent chain to infer names when DiskArbitration does not provide one
// - Disk Arbitration:
//   * Open a DASession for lookups and (future) notifications
//   * Enrich devices with DA metadata (vendor, revision, media name, protocol)
//   * Build a derived, stable identifier from DA keys (see note in
//     getMediaUUIDFromDiskArbitration)
//
// This file keeps those concerns clearly separated: IOKit scanning happens in
// getExternalStorageDevices/getDeviceInfoFromIOKit; Disk Arbitration lookups are
// isolated to small helpers that query a shared diskDescription(for:) utility.
//
// Any changes must keep the service largely stateless (no persistent ownership
// of model data) and safe for re-scan at any time.
@MainActor
class DriveDetectionService: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var isScanning = false
    
    private var diskArbitrationSession: DASession?
    
    init() {
        setupDiskArbitration()
        // Note: refreshDrives() is called from ContentView.onAppear to ensure proper initialization order
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
        print("🔍 [DEBUG] DriveDetectionService: Starting drive refresh")
        
        Task {
            let detectedDrives = await detectDrives()
            print("🔍 [DEBUG] DriveDetectionService: Detected \(detectedDrives.count) drives, updating on MainActor")
            
            // Update directly on MainActor since we're already @MainActor
            self.drives = detectedDrives
            self.isScanning = false
            print("🔍 [DEBUG] DriveDetectionService: Updated drives array - count: \(self.drives.count)")
        }
    }
    
    /// Debug function to print all Disk Arbitration information for a drive
//    func printDiskArbitrationInfo(for drive: Drive) {
//        print("🔍 [DEBUG] === Disk Arbitration Info for Drive: \(drive.displayName) ===")
//        print("📍 Device Path: \(drive.mountPoint)")
//        
//        guard let session = diskArbitrationSession else {
//            print("❌ [DEBUG] Disk Arbitration session is nil")
//            return
//        }
//        
//        // Extract the BSD name from the mount point (remove /dev/ prefix)
//        let bsdName = drive.mountPoint.replacingOccurrences(of: "/dev/", with: "")
//        
//        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName) else {
//            print("❌ [DEBUG] Failed to create disk object for: \(bsdName)")
//            return
//        }
//        
//        guard let diskDescription = DADiskCopyDescription(disk) as? [String: Any] else {
//            print("❌ [DEBUG] Failed to get disk description for: \(bsdName)")
//            return
//        }
//        
//        print("🔧 [DEBUG] All available Disk Arbitration keys:")
//        for (key, value) in diskDescription.sorted(by: { $0.key < $1.key }) {
//            print("   \(key): \(value)")
//        }
//        
//        print("🔍 [DEBUG] === End Disk Arbitration Info ===")
//    }
    
    /// Sets up Disk Arbitration session for device monitoring
    private func setupDiskArbitration() {
        diskArbitrationSession = DASessionCreate(kCFAllocatorDefault)
        guard let session = diskArbitrationSession else {
            print("❌ [DEBUG] Failed to create Disk Arbitration session")
            return
        }
        
        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        //print("✅ [DEBUG] Disk Arbitration session created and scheduled")
    }
    
    /// Detects all external storage devices that can be used for flashing
    func detectDrives() async -> [Drive] {
        var drives: [Drive] = []
        
        //print("🔍 [DEBUG] Starting external drive detection...")
        
        // Get all external storage devices using IOKit
        let devices = getExternalStorageDevices()
        print("🔍 [DEBUG] Found \(devices.count) external storage devices")
        
        // Get the system boot device to exclude it
        let systemBootDevice = getSystemBootDevice()
        //print("🔍 [DEBUG] System boot device: \(systemBootDevice)")
        
        // Iterate with index for clearer logging
        for (index, deviceInfo) in devices.enumerated() {
            print("\n🔍 [DEBUG] Checking device \(index + 1): \(deviceInfo.name)")
            //print("   📍 Device path: \(deviceInfo.devicePath)")
            //print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: deviceInfo.size, countStyle: .file))")
            //print("   🔄 Removable: \(deviceInfo.isRemovable)")
            //print("   ⏏️ Ejectable: \(deviceInfo.isEjectable)")
            print("   📝 Read-only: \(deviceInfo.isReadOnly)")
            
            // Check if this is the system boot device
            let isSystemDrive = deviceInfo.devicePath == systemBootDevice
            
            if isSystemDrive {
                //print("⚠️ [DEBUG] Device \(deviceInfo.name) is the system boot device - excluding")
                continue
            }
            
            // Check if this is a disk image (mounted .dmg file)
            if deviceInfo.isDiskImage {
                print("⚠️ [DEBUG] Device \(deviceInfo.name) is a disk image - excluding")
                continue
            }
            
            print("✅ [DEBUG] Found external drive: \(deviceInfo.name)")
            
            // Determine device type automatically from detected properties
            let deviceType: DeviceType = deviceInfo.inferredDeviceType
            
            let drive = Drive(
                name: deviceInfo.name,
                mountPoint: deviceInfo.devicePath,
                size: deviceInfo.size,
                isRemovable: true,
                isSystemDrive: false,
                isReadOnly: deviceInfo.isReadOnly,
                mediaUUID: deviceInfo.mediaUUID,
                mediaName: deviceInfo.mediaName,
                vendor: deviceInfo.vendor,
                revision: deviceInfo.revision,
                deviceType: deviceType
            )
            
            // Detect partition scheme once and cache it
            var driveWithPartitionScheme = drive
            let partitionScheme = ImageFileService.PartitionSchemeDetector.detectPartitionScheme(devicePath: deviceInfo.devicePath)
            driveWithPartitionScheme.partitionScheme = partitionScheme
            print("🔍 [DEBUG] Detected partition scheme for \(deviceInfo.name): \(driveWithPartitionScheme.partitionSchemeDisplay)")
            
            // Log DADeviceProtocol (kDADiskDescriptionDeviceProtocolKey)
            if let deviceProtocol = getDeviceProtocolFromDiskArbitration(devicePath: deviceInfo.devicePath) {
                print("🔌 [DEBUG] DADeviceProtocol for \(deviceInfo.name): \(deviceProtocol)")
            }
            
            drives.append(driveWithPartitionScheme)
            print("✅ [DEBUG] Added drive to array: \(deviceInfo.name) - Total drives: \(drives.count)")
        }
        
        print("🔍 [DEBUG] Drive detection complete. Found \(drives.count) external drives")
        
        return drives
    }
}

// MARK: - IOKit Device Detection Functions

extension DriveDetectionService {
    /// Converts a device path like "/dev/disk3" to BSD name "disk3"
    private func toBSDName(_ devicePath: String) -> String {
        return devicePath.replacingOccurrences(of: "/dev/", with: "")
    }
    
    /// Scans the IOKit registry for external storage devices that are removable and ejectable.
    ///
    /// This method uses IOKit to find all media devices that are both marked as `Removable` and `Ejectable`,
    /// which typically includes USB sticks, SD cards, and other flash media. It filters out partition entries
    /// and only includes the main device entries (e.g., `/dev/disk2` but not `/dev/disk2s1`).
    ///
    /// Devices are further examined using IOKit and Disk Arbitration to extract metadata such as name,
    /// UUID, vendor, and revision. Devices that pass all checks are returned as `DeviceInfo` instances.
    ///
    /// - Returns: An array of `DeviceInfo` objects representing external flashable devices.
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
            
            
            // Only include main devices (not partitions)
            if let deviceInfo = getDeviceInfoFromIOKit(service: service) {
                //print("🔍 [DEBUG] Processing device: \(deviceInfo.devicePath)")
                if deviceInfo.isMainDevice {
                    //print("✅ [DEBUG] Adding device to list: \(deviceInfo.devicePath)")
                    devices.append(deviceInfo)
                } else {
                    //print("❌ [DEBUG] Excluding device from list: \(deviceInfo.devicePath)")
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
        
        // Check if this is a main device (not a partition) BEFORE processing further
        // Use DeviceInfo-style predicate to keep a single source of truth
        if !DeviceInfo(name: "", devicePath: devicePath, size: 0, isRemovable: false, isEjectable: false, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil).isMainDevice {
            // print("❌ [DEBUG] Device \(devicePath) is a partition - excluding from processing")
            return nil
        }
        
        let originalName = getDeviceNameFromDiskArbitration(devicePath: devicePath) ?? getDeviceNameFromParent(service: service) ?? getDeviceName(from: props) ?? "Unknown Device"
        let size = getDeviceSize(from: props)
        let isRemovable = props["Removable"] as? Bool ?? false
        let isEjectable = props["Ejectable"] as? Bool ?? false
        let isReadOnly = props["Writable"] as? Bool == false
        
        // Get media UUID
        let mediaUUID = getMediaUUIDFromDiskArbitration(devicePath: devicePath)
        //print("🔧 [DEBUG] getMediaUUIDFromDiskArbitration returned: \(mediaUUID ?? "nil") for device: \(devicePath)")
        
        // Extract vendor and revision early
        let vendor = getVendorFromDiskArbitration(devicePath: devicePath)
        let revision = getRevisionFromDiskArbitration(devicePath: devicePath)
        
        // Always use original name from system; higher-level model may overlay custom names
        let name: String = originalName
        
        let mediaName = getMediaNameFromDiskArbitration(devicePath: devicePath)
        
        return DeviceInfo(
            name: name,
            devicePath: devicePath,
            size: size,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
            isReadOnly: isReadOnly,
            mediaUUID: mediaUUID,
            mediaName: mediaName,
            vendor: vendor,
            revision: revision
        )
    }
    
    // moved: device type inference is now a derived property on DeviceInfo
    
    /// Gets the specific DAMediaName from Disk Arbitration framework
    private func getMediaNameFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let mediaName = diskDescription["DAMediaName"] as? String, !mediaName.isEmpty { return mediaName }
        print("⚠️ [DEBUG] No DAMediaName found for device: \(devicePath)")
        return nil
    }
    
    /// Gets the DADeviceVendor from Disk Arbitration framework
    private func getVendorFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let vendor = diskDescription["DADeviceVendor"] as? String, !vendor.isEmpty { return vendor }
        print("⚠️ [DEBUG] No DADeviceVendor found for device: \(devicePath)")
        return nil
    }
    
    /// Gets the DADeviceRevision from Disk Arbitration framework
    private func getRevisionFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let revision = diskDescription["DADeviceRevision"] as? String, !revision.isEmpty { return revision }
        print("⚠️ [DEBUG] No DADeviceRevision found for device: \(devicePath)")
        return nil
    }
    
    /// Gets device name using Disk Arbitration framework
    private func getDeviceNameFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let mediaUUID = diskDescription["DADiskDescriptionMediaUUIDKey"] as? String { print("🔑 [DEBUG] Media UUID: \(mediaUUID)") }
        if let name = diskDescription["DAVolumeName"] as? String, !name.isEmpty { return name }
        if let name = diskDescription["DAMediaName"] as? String, !name.isEmpty { return name }
        if let name = diskDescription["DADeviceModel"] as? String, !name.isEmpty { return name }
        if let name = diskDescription["DADeviceProtocol"] as? String, !name.isEmpty { return name }
        if let vendorName = diskDescription["DADeviceVendor"] as? String,
           let productName = diskDescription["DADeviceProduct"] as? String { return "\(vendorName) \(productName)" }
        return nil
    }
    
    /// Gets the media UUID from Disk Arbitration
    private func getMediaUUIDFromDiskArbitration(devicePath: String) -> String? {
        print("🔧 [DEBUG] Analyse device: \(devicePath)")
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        let deviceID = generateDeviceID(from: diskDescription)
        return deviceID
    }

    /// Gets DADeviceProtocol (kDADiskDescriptionDeviceProtocolKey) from Disk Arbitration
    private func getDeviceProtocolFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let proto = diskDescription["DADeviceProtocol"] as? String, !proto.isEmpty { return proto }
        return nil
    }

    /// Shared helper: returns Disk Arbitration description dictionary for a given device path.
    /// Centralizes session/bsd name handling to avoid code duplication across DA helpers.
    private func diskDescription(for devicePath: String) -> [String: Any]? {
        guard let session = diskArbitrationSession else { return nil }
        let bsdName = toBSDName(devicePath)
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName) else { return nil }
        guard let description = DADiskCopyDescription(disk) as? [String: Any] else { return nil }
        return description
    }
    
    /// Generates a consistent device ID using DADeviceVendor + DADeviceRevision + 4 digits of DAMediaSize
    private func generateDeviceID(from diskDescription: [String: Any]) -> String {
        let deviceVendor = diskDescription["DADeviceVendor"] as? String ?? "Unknown"
        let deviceRevision = diskDescription["DADeviceRevision"] as? String ?? "Unknown"
        let mediaSize = diskDescription["DAMediaSize"] as? Int64 ?? 0
        
        // Get first 4 digits of media size (convert to string and take first 4 chars)
        let mediaSizeString = String(mediaSize)
        let sizePrefix = mediaSizeString.count >= 4 ? String(mediaSizeString.prefix(4)) : mediaSizeString
        
        // Clean up vendor and revision names (replace spaces with underscores)
        let cleanVendor = deviceVendor.replacingOccurrences(of: " ", with: "_")
        let cleanRevision = deviceRevision.replacingOccurrences(of: " ", with: "_")
        
        let deviceID = "\(cleanVendor)_\(cleanRevision)_\(sizePrefix)"
        //print("🔧 [DEBUG] Device ID components - Vendor: \(deviceVendor), Revision: \(deviceRevision), Size: \(mediaSize)")
        
        return deviceID
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
    
    /// (Deprecated) helpers replaced by DeviceInfo derived properties.
    /// Keeping empty stubs here would risk accidental use; removing them fully to avoid duplication.
    
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
