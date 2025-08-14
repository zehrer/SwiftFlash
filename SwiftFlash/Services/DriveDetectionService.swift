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
class DriveDetectionService: ObservableObject, DeviceDetectionService {
    /// Published array of detected drives, updated by detectDrives()
    @Published var drives: [Device] = []
    /// Indicates whether a scan is currently in progress
    @Published var isScanning: Bool = false
    
    /// Device inventory for persistence
    var deviceInventory: (any DeviceInventoryManager)?
    private var diskArbitrationSession: DASession?
    
    init(deviceInventory: (any DeviceInventoryManager)? = nil) {
        self.deviceInventory = deviceInventory
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
    
    /// Refreshes the list of drives by calling detectDrives()
    /// This is a convenience method for SwiftUI views to call
    func refreshDrives() {
        isScanning = true
        
        // Detect drives and update the published array
        let detectedDrives = detectDrives()
            self.drives = detectedDrives
        
        isScanning = false
    }
    

    
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
     func detectDrives() -> [Device] {
        isScanning = true
        defer { isScanning = false }
        
        // Get system boot device to exclude it
        let systemBootDevice = getSystemBootDevice()
        
        // Get devices from IOKit
        let devices = getExternalStorageDevices()
        var detectedDrives: [Device] = []
        
        print("🔍 [DEBUG] Found \(devices.count) external storage devices")
        
        // Iterate with index for clearer logging
        for (index, device) in devices.enumerated() {
            print("🔍 [DEBUG] Checking device \(index + 1): \(device.name)")
            
            // Check if this is the system boot device
            let isSystemDrive = device.devicePath == systemBootDevice
            
            if isSystemDrive {
                //print("⚠️ [DEBUG] Device \(device.name) is the system boot device - excluding")
                continue
            }
            
            // Check if this is a disk image (mounted .dmg file)
            if device.isDiskImage {
                print("⚠️ [DEBUG] Device \(device.name) is a disk image - excluding")
                continue
            }
            
            print("✅ [DEBUG] Found external drive: \(device.name)")
            
            // Detect partition scheme once and cache it
            var deviceWithPartitionScheme = device
            let partitionScheme = ImageFileService.PartitionSchemeDetector.detectPartitionScheme(devicePath: device.devicePath)
            deviceWithPartitionScheme.partitionScheme = partitionScheme
            print("🔍 [DEBUG] Detected partition scheme for \(device.name): \(deviceWithPartitionScheme.partitionSchemeDisplay)")
            

#if DEBUG
            // Dump full Disk Arbitration description for this relevant detected device
            //deviceWithPartitionScheme.logDiskDescription()
#endif
            
            detectedDrives.append(deviceWithPartitionScheme)
            print("✅ [DEBUG] Added drive to array: \(device.name) - Total drives: \(detectedDrives.count)")
        }
        
        print("🔍 [DEBUG] Drive detection complete. Found \(detectedDrives.count) external drives")
        
        return detectedDrives
    }
}

// MARK: - IOKit Device Detection Functions

extension DriveDetectionService {
    /// Converts an absolute device node path (e.g. "/dev/disk3") to its BSD name (e.g. "disk3").
    ///
    /// Framework: none (string utility)
    /// - Parameter devicePath: Absolute device path such as "/dev/disk4".
    /// - Returns: BSD name suitable for Disk Arbitration APIs (e.g. "disk4").
    private func toBSDName(_ devicePath: String) -> String {
        return devicePath.replacingOccurrences(of: "/dev/", with: "")
    }
    

    
    /// Gets external storage devices from IOKit.
    ///
    /// This method:
    /// 1. Iterates through IOKit registry entries of class kIOMediaClass
    /// 2. Extracts device information from IOKit properties
    /// 3. Builds Device objects directly with basic properties
    /// 4. Persistence is handled by DeviceInventory
    ///
    /// - Returns: Array of `Device` objects representing external storage devices.
    private func getExternalStorageDevices() -> [Device] {
        var devices: [Device] = []
        
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
            if let device = getDeviceFromIOKit(service: service) {
                //print("🔍 [DEBUG] Processing device: \(device.devicePath)")
                if device.isMainDevice {
                    //print("✅ [DEBUG] Adding device to list: \(device.devicePath)")
                    devices.append(device)
                } else {
                    //print("❌ [DEBUG] Excluding device from list: \(device.devicePath)")
                }
            }
        }
        
        return devices
    }
    
    /// IOKit: Builds `Device` for a given IORegistry service node.
    ///
    /// - Reads IORegistry properties (BSD Name → device path, size, writable, etc.).
    /// - Consults Disk Arbitration for media name, vendor, revision, and a derived stable identifier.
    /// - Creates a Device object directly with all necessary properties
    /// - Handles inventory persistence through DeviceInventory
    /// - Skips nodes that represent partitions/slices.
    ///
    /// - Parameter service: IORegistry object of class kIOMedia.
    /// - Returns: `Device` or `nil` if not a main device or properties unavailable.
    private func getDeviceFromIOKit(service: io_object_t) -> Device? {
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
        // Create a temporary Device to check if it's a main device
        let tempDevice = Device(
            devicePath: devicePath,
            isRemovable: false,
            isEjectable: false,
            isReadOnly: false,
            isSystemDrive: false,
            diskDescription: nil,
            partitions: []
        )
        
        if !tempDevice.isMainDevice {
            // print("❌ [DEBUG] Device \(devicePath) is a partition - excluding from processing")
            return nil
        }
        
        // Get device name from IOKit properties first, then fallback to parent lookup
        let originalName = getDeviceName(from: props) ?? getDeviceNameFromParent(service: service) ?? "Unknown Device"
        let size = getDeviceSize(from: props)
        let isRemovable = props["Removable"] as? Bool ?? false
        let isEjectable = props["Ejectable"] as? Bool ?? false
        let isReadOnly = props["Writable"] as? Bool == false
        
        // Get raw Disk Arbitration description and extract individual values
        let daDesc = diskDescription(for: devicePath)
        
        // Collect partitions (Disk Arbitration) for this main device
        let partitions = getPartitionsForDevice(devicePath: devicePath)
        
        // Generate a stable mediaUUID if needed
        let mediaUUID = daDesc?[kDADiskDescriptionMediaUUIDKey as String] as? String ?? Device.generateStableDeviceID(from: daDesc ?? [:])
        
        // Check if we have this device in inventory
        var inventoryItem: DeviceInventoryItem? = nil
        if let inventory = deviceInventory {
            // Find by mediaUUID
            inventoryItem = inventory.getInventoryItem(for: mediaUUID)
            
            // If not found, create a new inventory item
            if inventoryItem == nil {
                let deviceType = DeviceType.unknown
                let mediaName = daDesc?[kDADiskDescriptionMediaNameKey as String] as? String ?? originalName
                let vendor = daDesc?[kDADiskDescriptionDeviceVendorKey as String] as? String
                let revision = daDesc?[kDADiskDescriptionDeviceRevisionKey as String] as? String
                
                inventory.addOrUpdateDevice(
                    mediaUUID: mediaUUID,
                size: size,
                    originalName: mediaName,
                deviceType: deviceType,
                vendor: vendor,
                revision: revision
            )
                inventoryItem = inventory.getInventoryItem(for: mediaUUID)
            } else {
                // Update lastSeen for existing device
                let deviceType = inventoryItem?.deviceType ?? DeviceType.unknown
                let mediaName = daDesc?[kDADiskDescriptionMediaNameKey as String] as? String ?? originalName
                let vendor = daDesc?[kDADiskDescriptionDeviceVendorKey as String] as? String
                let revision = daDesc?[kDADiskDescriptionDeviceRevisionKey as String] as? String
                
                inventory.addOrUpdateDevice(
                    mediaUUID: mediaUUID,
                    size: size,
                    originalName: mediaName,
                    deviceType: deviceType,
                    vendor: vendor,
                    revision: revision
                )
            }
        }
        
        // Create a Device object directly
        let device = Device(
            devicePath: devicePath,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
            isReadOnly: isReadOnly,
            isSystemDrive: false,
            diskDescription: daDesc,
            partitions: partitions,
            inventoryItem: inventoryItem
        )
        
        return device
    }
    
    // Note: Individual Disk Arbitration value extraction is now handled by Drive computed properties
    // The raw diskDescription is captured and passed to Drive struct for on-demand access



    /// Shared helper: returns Disk Arbitration description dictionary for a given device path.
    /// Centralizes session/bsd name handling to avoid code duplication across DA helpers.
    /// Disk Arbitration: Provides the description dictionary for a given device.
    ///
    /// Common keys seen include:
    /// - `DADeviceVendor`, `DADeviceRevision`, `DADeviceModel`
    /// - `DADeviceProtocol` (kDADiskDescriptionDeviceProtocolKey)
    /// - `DAMediaSize`
    /// - `DAVolumeName`
    ///
    /// - Parameter devicePath: Absolute device path.
    /// - Returns: Dictionary of description keys or `nil`.
    private func diskDescription(for devicePath: String) -> [String: Any]? {
        guard let session = diskArbitrationSession else { return nil }
        let bsdName = toBSDName(devicePath)
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName) else { return nil }
        guard let description = DADiskCopyDescription(disk) as? [String: Any] else { return nil }
        return description
    }

    /// Disk Arbitration: Enumerates partitions (slices) for a given main device.
    ///
    /// Implementation note: Disk Arbitration does not directly list children by API;
    /// we obtain the whole-disk's bsd name, then use IOKit to match child IOMedia entries
    /// whose BSD Name starts with the parent (e.g. disk4s1, disk4s2). For each slice,
    /// we read DA description to enrich with names and mount points.
    private func getPartitionsForDevice(devicePath: String) -> [PartitionInfo] {
        var results: [PartitionInfo] = []
        let parentBSD = toBSDName(devicePath)

        // Build IOKit matcher for IOMedia children with matching BSD prefix
        let matching = IOServiceMatching(kIOMediaClass) as NSMutableDictionary
        // Child partitions are not whole; don't require Removable/Ejectable
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == kIOReturnSuccess else { return results }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var propsUnmanaged: Unmanaged<CFMutableDictionary>?
            let ok = IORegistryEntryCreateCFProperties(service, &propsUnmanaged, kCFAllocatorDefault, 0)
            guard ok == kIOReturnSuccess, let props = propsUnmanaged?.takeRetainedValue() as? [String: Any] else { continue }

            guard let bsdName = props["BSD Name"] as? String, bsdName.hasPrefix(parentBSD + "s") else { continue }

            let path = "/dev/" + bsdName
            let size = (props["Media Size"] as? Int64)
                ?? (props["Size"] as? Int64)
                ?? (props["Total Size"] as? Int64)
                ?? (props["Capacity"] as? Int64)
                ?? 0

            // Enrich with Disk Arbitration details
            let desc = diskDescription(for: path)
            let volumeName = (desc?[kDADiskDescriptionVolumeNameKey as String] as? String) ?? (desc?[kDADiskDescriptionMediaNameKey as String] as? String)
            let fs = (desc?[kDADiskDescriptionVolumeKindKey as String] as? String) ?? (desc?[kDADiskDescriptionMediaKindKey as String] as? String)
            let mountPoint = desc?[kDADiskDescriptionVolumePathKey as String] as? String
            let writable: Bool? = (desc?[kDADiskDescriptionMediaWritableKey as String] as? Bool)

            results.append(
                PartitionInfo(
                    bsdName: bsdName,
                    devicePath: path,
                    size: size,
                    volumeName: volumeName,
                    fileSystem: fs,
                    mountPoint: mountPoint,
                    isWritable: writable
                )
            )
        }

        // Sort partitions by numeric suffix (s1, s2, ...)
        results.sort { a, b in
            let anum = Int(a.bsdName.split(separator: "s").last ?? "") ?? 0
            let bnum = Int(b.bsdName.split(separator: "s").last ?? "") ?? 0
            return anum < bnum
        }

        return results
    }
    
    // Note: Device ID generation is now handled by Device.generateStableDeviceID
    
    /// IOKit: Attempts to read a content type hint from IORegistry properties.
    /// - Parameter props: IORegistry property dictionary.
    /// - Returns: Raw content type string or "Unknown".
    private func getDeviceType(from props: [String: Any]) -> String {
        if let content = props["Content"] as? String {
            return content
        }
        if let contentHint = props["Content Hint"] as? String, !contentHint.isEmpty {
            return contentHint
        }
        return "Unknown"
    }
    
    /// IOKit: Walks up the IOServicePlane to find a plausible product/device name.
    ///
    /// Used when Disk Arbitration does not provide a satisfactory name. Looks for
    /// well-known IORegistry string properties on parent nodes (USB device levels).
    /// - Parameter service: Starting IORegistry node.
    /// - Returns: Found name or `nil`.
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
    
    /// IOKit: Extracts a human-friendly name from IORegistry properties.
    ///
    /// Tries multiple candidate keys (e.g., "Media Name", "Product Name", "Device Name",
    /// "USB Product Name", vendor/product IDs) and returns the first non-empty string.
    /// - Parameter props: IORegistry property dictionary.
    /// - Returns: Name string or `nil`.
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
    
    /// IOKit: Extracts the absolute device path from IORegistry properties.
    ///
    /// Reads the `BSD Name` property and formats it as "/dev/<bsd>".
    /// - Parameter props: IORegistry property dictionary.
    /// - Returns: Absolute device path or `nil`.
    private func getDevicePath(from props: [String: Any]) -> String? {
        // Get the BSD device name
        if let bsdName = props["BSD Name"] as? String {
            return "/dev/\(bsdName)"
        }
        return nil
    }
    
    /// IOKit: Extracts the media size in bytes from IORegistry properties.
    ///
    /// Tries common size-related keys (e.g., "Media Size", "Size", "Total Size", "Capacity").
    /// - Parameter props: IORegistry property dictionary.
    /// - Returns: Size in bytes (0 if missing).
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
    
    /// Utility: Returns the system boot device node by parsing `diskutil info /`.
    ///
    /// - Returns: Absolute device path of the boot volume (e.g. "/dev/disk3") or empty string on failure.
    /// - Warning: Synchronous subprocess; keep off hot paths.
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
