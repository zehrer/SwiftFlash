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
            print("🔍 [DEBUG] Checking device \(index + 1): \(deviceInfo.name)")
            //print("   📍 Device path: \(deviceInfo.devicePath)")
            //print("   💾 Size: \(ByteCountFormatter.string(fromByteCount: deviceInfo.size, countStyle: .file))")
            //print("   🔄 Removable: \(deviceInfo.isRemovable)")
            //print("   ⏏️ Ejectable: \(deviceInfo.isEjectable)")
            //print("   📝 Read-only: \(deviceInfo.isReadOnly)")
            
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
            
            // Capture a single DA description to avoid repeated lookups later
            let daDesc = diskDescription(for: deviceInfo.devicePath)

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
                diskDescription: daDesc,
                deviceType: deviceType
            )
            
            // Detect partition scheme once and cache it
            var driveWithPartitionScheme = drive
            let partitionScheme = ImageFileService.PartitionSchemeDetector.detectPartitionScheme(devicePath: deviceInfo.devicePath)
            driveWithPartitionScheme.partitionScheme = partitionScheme
            print("🔍 [DEBUG] Detected partition scheme for \(deviceInfo.name): \(driveWithPartitionScheme.partitionSchemeDisplay)")
            
            // Log DADeviceProtocol (kDADiskDescriptionDeviceProtocolKey) from captured description
            if let proto = daDesc?["DADeviceProtocol"] as? String, !proto.isEmpty {
                print("🔌 [DEBUG] DADeviceProtocol for \(deviceInfo.name): \(proto)")
            }

#if DEBUG
            // Dump full Disk Arbitration description for this relevant detected device
            driveWithPartitionScheme.logDiskDescription()
#endif
            
            drives.append(driveWithPartitionScheme)
            print("✅ [DEBUG] Added drive to array: \(deviceInfo.name) - Total drives: \(drives.count)")
        }
        
        print("🔍 [DEBUG] Drive detection complete. Found \(drives.count) external drives")
        
        return drives
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
    
    /// IOKit: Enumerates removable/ejectable media and builds `DeviceInfo` records.
    ///
    /// - Uses IORegistry (kIOMediaClass) to find candidates with properties `Removable == true` and
    ///   `Ejectable == true`.
    /// - Filters out partition/slice nodes; includes only main devices (e.g. `/dev/disk2`, not `/dev/disk2s1`).
    /// - Enriches with Disk Arbitration metadata (vendor, revision, media name) via helper lookups.
    /// - Returns transient `DeviceInfo` models; persistence is handled by higher-level model logic.
    ///
    /// - Returns: Array of discovered `DeviceInfo`.
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
    
    /// IOKit: Builds `DeviceInfo` for a given IORegistry service node.
    ///
    /// - Reads IORegistry properties (BSD Name → device path, size, writable, etc.).
    /// - Consults Disk Arbitration for media name, vendor, revision, and a derived stable identifier.
    /// - Skips nodes that represent partitions/slices.
    ///
    /// - Parameter service: IORegistry object of class kIOMedia.
    /// - Returns: `DeviceInfo` or `nil` if not a main device or properties unavailable.
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
        if !DeviceInfo(name: "", devicePath: devicePath, size: 0, isRemovable: false, isEjectable: false, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil, partitions: []).isMainDevice {
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
        
        // Collect partitions (Disk Arbitration) for this main device
        let partitions = getPartitionsForDevice(devicePath: devicePath)

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
            revision: revision,
            partitions: partitions
        )
    }
    
    // moved: device type inference is now a derived property on DeviceInfo
    
    /// Disk Arbitration: Returns the `DAMediaName` for a device, if present.
    ///
    /// Common related keys: `DAVolumeName`, `DAMediaName`.
    /// - Parameter devicePath: Absolute device path (e.g. "/dev/disk4").
    /// - Returns: Media name string or `nil`.
    private func getMediaNameFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let mediaName = diskDescription["DAMediaName"] as? String, !mediaName.isEmpty { return mediaName }
        print("⚠️ [DEBUG] No DAMediaName found for device: \(devicePath)")
        return nil
    }
    
    /// Disk Arbitration: Returns the `DADeviceVendor` for a device, if present.
    ///
    /// Common related keys: `DADeviceVendor`, `DADeviceProduct`.
    /// - Parameter devicePath: Absolute device path.
    /// - Returns: Vendor string or `nil`.
    private func getVendorFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let vendor = diskDescription["DADeviceVendor"] as? String, !vendor.isEmpty { return vendor }
        print("⚠️ [DEBUG] No DADeviceVendor found for device: \(devicePath)")
        return nil
    }
    
    /// Disk Arbitration: Returns the `DADeviceRevision` for a device, if present.
    /// - Parameter devicePath: Absolute device path.
    /// - Returns: Revision string or `nil`.
    private func getRevisionFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let revision = diskDescription["DADeviceRevision"] as? String, !revision.isEmpty { return revision }
        print("⚠️ [DEBUG] No DADeviceRevision found for device: \(devicePath)")
        return nil
    }
    
    /// Disk Arbitration: Attempts to derive a human-friendly device name.
    ///
    /// Tries, in order: `DAVolumeName`, `DAMediaName`, `DADeviceModel`, `DADeviceProtocol`,
    /// and finally a concatenation of `DADeviceVendor + DADeviceProduct`.
    /// - Parameter devicePath: Absolute device path.
    /// - Returns: Name string or `nil` if none found.
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
    
    /// Disk Arbitration: Returns a generated stable identifier based on DA keys.
    ///
    /// Note: This is not a literal UUID from the OS. It is synthesized from
    /// `DADeviceVendor`, `DADeviceRevision`, and a short prefix of `DAMediaSize` to
    /// provide a stable identifier across runs for inventory correlation.
    /// - Parameter devicePath: Absolute device path.
    /// - Returns: Generated identifier string or `nil`.
    private func getMediaUUIDFromDiskArbitration(devicePath: String) -> String? {
        print("🔧 [DEBUG] Analyse device: \(devicePath)")
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        let deviceID = generateDeviceID(from: diskDescription)
        return deviceID
    }

    /// Disk Arbitration: Returns `DADeviceProtocol` (kDADiskDescriptionDeviceProtocolKey).
    /// - Parameter devicePath: Absolute device path.
    /// - Returns: Protocol string (e.g. "USB", "SATA") or `nil`.
    private func getDeviceProtocolFromDiskArbitration(devicePath: String) -> String? {
        guard let diskDescription = diskDescription(for: devicePath) else { return nil }
        if let proto = diskDescription["DADeviceProtocol"] as? String, !proto.isEmpty { return proto }
        return nil
    }

    /// Shared helper: returns Disk Arbitration description dictionary for a given device path.
    /// Centralizes session/bsd name handling to avoid code duplication across DA helpers.
    /// Disk Arbitration: Provides the description dictionary for a given device.
    ///
    /// Common keys seen include:
    /// - `DADeviceVendor`, `DADeviceProduct`, `DADeviceRevision`, `DADeviceModel`
    /// - `DADeviceProtocol` (kDADiskDescriptionDeviceProtocolKey)
    /// - `DAMediaName`, `DAMediaSize`
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
            let volumeName = (desc?["DAVolumeName"] as? String) ?? (desc?["DAMediaName"] as? String)
            let fs = (desc?["DAVolumeKind"] as? String) ?? (desc?["DAMediaKind"] as? String)
            let mountPoint = desc?["DAVolumePath"] as? String
            let writable: Bool? = (desc?["DADeviceWritable"] as? Bool)

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
