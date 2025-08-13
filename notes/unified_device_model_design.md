# Unified Device Model Design (Revised Approach)

## Overview

This document outlines the consolidating design, this was required because several AI agents were having trouble understanding basics concepts and created overlapping structures. 


THe device model is the main data object, it contains all the basic properties of a device.

**Device** (UI/Application Model):
- `name`, `size`, `mediaUUID`, `vendor`, `revision`, `deviceType` (via computed properties)
- `mountPoint`, `isRemovable`, `isSystemDrive`, `isReadOnly`
- `diskDescription`, `partitionScheme`
- UI display and application logic

A subset of information is stored in the DeviceInventoryItem, this is to avoid duplicating data.

**DeviceInventoryItem** (Persistence):
- `mediaUUID`, `size`, `mediaName`, `vendor`, `revision`, `deviceType`
- `firstSeen`, `lastSeen`, `customName`
- Persistence and history tracking

## Revised Solution: Two Separate Structs with Clear Responsibilities

### 1. Device Struct (Business Logic & Runtime Operations)

```swift
/// Main business logic model for device operations and runtime properties
/// This struct contains all non-optional properties and handles device operations
/// Acts as a wrapper around DeviceInventoryItem to avoid data duplication
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
    
    // MARK: - UI Properties
    var partitionScheme: ImageFileService.PartitionScheme = .unknown
    
    // MARK: - Persistence Reference
    let inventoryItem: DeviceInventoryItem?
    
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
    
    // MARK: - Disk Arbitration Computed Properties
    var daMediaUUID: String? { diskDescription?[kDADiskDescriptionMediaUUIDKey as String] as? String }
    var daMediaName: String? { diskDescription?[kDADiskDescriptionMediaNameKey as String] as? String }
    var daVendor: String? { diskDescription?[kDADiskDescriptionDeviceVendorKey as String] as? String }
    var daRevision: String? { diskDescription?[kDADiskDescriptionDeviceRevisionKey as String] as? String }
    var daDeviceModel: String? { diskDescription?[kDADiskDescriptionDeviceModelKey as String] as? String }
    var daDeviceProtocol: String? { diskDescription?[kDADiskDescriptionDeviceProtocolKey as String] as? String }
    var daVolumeName: String? { diskDescription?[kDADiskDescriptionVolumeNameKey as String] as? String }
    var daVolumeKind: String? { diskDescription?[kDADiskDescriptionVolumeKindKey as String] as? String }
    var daVolumePath: String? {
        if let url = diskDescription?[kDADiskDescriptionVolumePathKey as String] as? URL { return url.path }
        if let path = diskDescription?[kDADiskDescriptionVolumePathKey as String] as? String { return path }
        return nil
    }
    
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
        if lower.contains("udisk") || lower.contains("mass") || lower.contains("generic") { return .usbStick }
        if lower.contains("ssd") || lower.contains("solid state") { return .externalSSD }
        if lower.contains("external") || lower.contains("drive") || lower.contains("hard disk") { return .externalHDD }
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
                    
                    usleep(100000) // 0.1 seconds
                    
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
    init(from inventoryItem: DeviceInventoryItem, devicePath: String, isRemovable: Bool, isEjectable: Bool, isReadOnly: Bool, isSystemDrive: Bool, diskDescription: [String: Any]?, partitions: [PartitionInfo]) {
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

    private func generateStableDeviceID() -> String {
        guard let diskDescription = diskDescription else { return "" }
        
        let deviceVendor = diskDescription[kDADiskDescriptionDeviceVendorKey as String] as? String ?? "Unknown"
        let deviceRevision = diskDescription[kDADiskDescriptionDeviceRevisionKey as String] as? String ?? "Unknown"
        let mediaSize = diskDescription[kDADiskDescriptionMediaSizeKey as String] as? Int64 ?? 0
        
        // Get first 4 digits of media size
        let mediaSizeString = String(mediaSize)
        let sizePrefix = mediaSizeString.count >= 4 ? String(mediaSizeString.prefix(4)) : mediaSizeString
        
        // Clean up vendor and revision names
        let cleanVendor = deviceVendor.replacingOccurrences(of: " ", with: "_")
        let cleanRevision = deviceRevision.replacingOccurrences(of: " ", with: "_")
        
        return "\(cleanVendor)_\(cleanRevision)_\(sizePrefix)"
    }
}
```

### 2. DeviceInventoryItem Struct (Persistence Only)

```swift
/// Persistence model for device history and storage
/// This struct is Codable and contains only persistent properties
struct DeviceInventoryItem: Codable, Identifiable, Hashable {
    // MARK: - Core Identity
    var id = UUID()
    let mediaUUID: String
    
    // MARK: - Basic Properties (persisted)
    let size: Int64
    let mediaName: String
    var name: String?
    let vendor: String?
    let revision: String?
    var deviceType: DeviceType = .unknown
    
    // MARK: - Persistence Properties
    let firstSeen: Date
    var lastSeen: Date
    var customName: String?
    
    // MARK: - Computed Properties
    var displayName: String {
        return customName ?? name ?? mediaName.isEmpty ? "Unknown Device" : mediaName
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // MARK: - Initializers
    /// Creates a new DeviceInventoryItem from detection data
    init(
        mediaUUID: String,
        size: Int64,
        mediaName: String,
        name: String?,
        vendor: String?,
        revision: String?,
        deviceType: DeviceType = .unknown
    ) {
        self.mediaUUID = mediaUUID
        self.size = size
        self.mediaName = mediaName
        self.name = name
        self.vendor = vendor
        self.revision = revision
        self.deviceType = deviceType
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.customName = nil
    }
    
    /// Creates a DeviceInventoryItem from a Device (for new devices)
    init(from device: Device) {
        self.mediaUUID = device.mediaUUID  // Uses computed property with stable ID generation
        self.size = device.size
        self.mediaName = device.daMediaName ?? device.name
        self.name = device.name
        self.vendor = device.daVendor ?? device.vendor
        self.revision = device.daRevision ?? device.revision
        self.deviceType = device.deviceType
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.customName = nil
    }
    
    // MARK: - Hashable & Equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(mediaUUID)
    }
    
    static func == (lhs: DeviceInventoryItem, rhs: DeviceInventoryItem) -> Bool {
        return lhs.mediaUUID == rhs.mediaUUID
    }
}
```

### 3. DeviceType Enum (Separate File)

```swift
// DeviceType.swift
enum DeviceType: String, CaseIterable, Codable {
    case usbStick = "USB Stick"
    case sdCard = "SD Card"
    case microSDCard = "microSD Card"
    case externalHDD = "external HDD"
    case externalSSD = "external SSD"
    case unknown = "unknown"
    
    var icon: String {
        switch self {
        case .usbStick, .sdCard, .microSDCard:
            return "mediastick"
        case .externalHDD, .externalSSD:
            return "externaldrive"
        case .unknown:
            return "questionmark.circle"
        }
    }
}
```

### 4. DriveDetectionService (Keep Current Name)

```swift
/// Service for device detection operations
/// Mount/unmount operations remain in Device struct
class DriveDetectionService: ObservableObject {
    @Published var drives: [Device] = []
    @Published var isScanning: Bool = false
    
    // MARK: - Device Detection
    func detectDrives() async -> [Device] {
        // ... existing detection logic, but return Device instead of Drive
        // Replace DeviceInfo with Device in the detection process
    }
    
    // MARK: - Helper Methods
    func getDeviceFromIOKit(service: io_object_t) -> Device? {
        // Replace getDeviceInfoFromIOKit with getDeviceFromIOKit
        // Return Device instead of DeviceInfo
    }
}
```

## Open Questions - RESOLVED

### 1. Device Wrapper Around DeviceInventoryItem ✅ RESOLVED

**Answer**: Option A - Device contains inventory item as property

**Implementation**: 
- `Device` acts as a wrapper around `DeviceInventoryItem`
- All persistent properties accessed via computed properties from `inventoryItem`
- No data duplication - `Device` delegates to `DeviceInventoryItem` for persistent data
- `inventoryItem` is optional to handle new devices not yet in inventory

**Use Case Flow**:
1. App starts → Load all `DeviceInventoryItem` from storage
2. App detects connected devices → Create `Device` for each
3. For known devices → Link existing `DeviceInventoryItem` to `Device`
4. For new devices → Create new `DeviceInventoryItem` and add to inventory

### 2. DeviceInfo Replacement ✅ RESOLVED

**Answer**: Yes - `Device` completely replaces `DeviceInfo`

**Implementation**: 
- `DriveDetectionService.getDeviceFromIOKit()` returns `Device` instead of `DeviceInfo`
- `Device` becomes the main data structure throughout the app
- No concerns identified - this eliminates duplication

### 3. Service Renaming and Responsibilities ✅ RESOLVED

**Answer**: Keep `DriveDetectionService` name for now, mount/unmount operations stay in `Device` struct

**Implementation**:
- Mount/unmount operations remain as methods on `Device` struct
- Service focuses on detection only
- Can rename to `DriveService` later if needed

### 4. Initialization Strategy ✅ RESOLVED

**Answer**: Multiple initializers for different use cases

**Implementation**:
- `DeviceInventoryItem` optional in `Device` (required for lookup)
- Efficient initializers for both new and existing devices
- `DeviceInventoryItem` can be created from `Device` for new devices

### 5. Migration Strategy ✅ RESOLVED

**Answer**: Implement in one change as the change is not too big

**Implementation**:
- Finalize design document first
- Implement all changes in one comprehensive update
- Replace `DeviceInfo` and `Drive` with new `Device` structure
- Update all references throughout codebase

## Concerns and Clarifications Needed

### ⚠️ **Potential Issue 1: Mutability of DeviceInventoryItem**

**Problem**: `Device` computed properties need to modify `DeviceInventoryItem` properties (e.g., `deviceType`, `lastSeen`, `customName`), but `inventoryItem` is `let`.

**Solution Options**:
1. Make `inventoryItem` `var` instead of `let`
2. Use a different pattern for updates
3. Handle updates through the service layer

**Recommendation**: Make `inventoryItem` `var` to allow direct updates.

### ⚠️ **Potential Issue 2: mediaUUID Bug and Fallback Values**

**Problem**: When `inventoryItem` is `nil` (new device), computed properties need sensible fallbacks.

**Current Fallbacks**:
- `id`: New UUID
- `mediaUUID`: Empty string
- `name`: Empty string
- `size`: 0

**CRITICAL BUG IDENTIFIED**: The `mediaUUID` implementation has a bug in the current codebase.

**Bug Analysis**:
- **Previous Implementation**: `getMediaUUIDFromDiskArbitration()` was a computed property that generated a stable identifier from `DADeviceVendor`, `DADeviceRevision`, and `DAMediaSize` using `generateDeviceID()`
- **Current Implementation**: `mediaUUID` is now directly extracted from `kDADiskDescriptionMediaUUIDKey` which may be `nil` for many devices
- **Impact**: This breaks device identification and inventory correlation

**Solution**: Restore the computed `mediaUUID` generation logic:

```swift
// In Device struct, replace the simple wrapper with computed generation
var mediaUUID: String { 
    // If we have an inventory item, use its stored UUID
    if let inventoryItem = inventoryItem {
        return inventoryItem.mediaUUID
    }
    
    // For new devices, generate a stable identifier from Disk Arbitration data
    return generateStableDeviceID()
}

private func generateStableDeviceID() -> String {
    guard let diskDescription = diskDescription else { return "" }
    
    let deviceVendor = diskDescription[kDADiskDescriptionDeviceVendorKey as String] as? String ?? "Unknown"
    let deviceRevision = diskDescription[kDADiskDescriptionDeviceRevisionKey as String] as? String ?? "Unknown"
    let mediaSize = diskDescription[kDADiskDescriptionMediaSizeKey as String] as? Int64 ?? 0
    
    // Get first 4 digits of media size
    let mediaSizeString = String(mediaSize)
    let sizePrefix = mediaSizeString.count >= 4 ? String(mediaSizeString.prefix(4)) : mediaSizeString
    
    // Clean up vendor and revision names
    let cleanVendor = deviceVendor.replacingOccurrences(of: " ", with: "_")
    let cleanRevision = deviceRevision.replacingOccurrences(of: " ", with: "_")
    
    return "\(cleanVendor)_\(cleanRevision)_\(sizePrefix)"
}
```

**Updated Fallbacks**:
- `id`: New UUID
- `mediaUUID`: Generated stable identifier from Disk Arbitration data
- `name`: Empty string (will be populated from detection)
- `size`: 0 (will be populated from detection)

### ⚠️ **Potential Issue 3: DeviceInventoryItem Creation**

**Problem**: When creating a new `DeviceInventoryItem` from a `Device`, we need to extract values from `diskDescription`.

**Question**: Should this logic be in `DeviceInventoryItem.init(from:)` or handled by the service layer?

**Solution**: The `DeviceInventoryItem.init(from:)` should use the computed `mediaUUID` from `Device`:

```swift
/// Creates a DeviceInventoryItem from a Device (for new devices)
init(from device: Device) {
    self.mediaUUID = device.mediaUUID  // Uses computed property with stable ID generation
    self.size = device.size
    self.mediaName = device.daMediaName ?? device.name
    self.name = device.name
    self.vendor = device.daVendor ?? device.vendor
    self.revision = device.daRevision ?? device.revision
    self.deviceType = device.deviceType
    self.firstSeen = Date()
    self.lastSeen = Date()
    self.customName = nil
}
```

## Benefits of This Approach

1. **Clear Separation of Concerns**: Business logic vs. persistence
2. **No Data Duplication**: `Device` delegates to `DeviceInventoryItem` for persistent data
3. **Maintainable**: Each struct has a single responsibility
4. **Testable**: Clear interfaces for unit testing
5. **Extensible**: Easy to add new properties to either struct
6. **Efficient**: Wrapper pattern avoids copying data

## Implementation Plan

1. Create `DeviceType.swift` with the enum
2. Create new `Device` struct with wrapper pattern
3. Update `DeviceInventoryItem` with new initializers
4. Update `DriveDetectionService` to return `Device` instead of `DeviceInfo`
5. Replace all `Drive` references with `Device`
6. Update all UI components to use new `Device` structure
7. Remove `DeviceInfo` and `Drive` structs
8. Update tests to use new models

## Next Steps

1. **Address the concerns above** (mutability, fallbacks, creation logic)
2. **Confirm the implementation approach**
3. **Begin implementation with the agreed structure**
