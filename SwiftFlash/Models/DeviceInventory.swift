import Foundation
import Combine

// DeviceType enum has been moved to DeviceType.swift

// This struct represents devices in the inventory and is used for persistence.
// Changes here affect device tracking, data storage, and UI display.
// Any modifications require testing of device inventory functionality.
struct DeviceInventoryItem: Codable, Identifiable, Hashable {
    var id = UUID()
    let mediaUUID: String
    let size: Int64
    let mediaName: String
    var name: String?
    let firstSeen: Date
    var lastSeen: Date
    var deviceType: DeviceType = .unknown
    var vendor: String?
    var revision: String?
    var customName: String?
    
    var displayName: String {
        return customName ?? name ?? mediaName
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
        firstSeen: Date,
        lastSeen: Date,
        deviceType: DeviceType = .unknown,
        vendor: String? = nil,
        revision: String? = nil
    ) {
        self.mediaUUID = mediaUUID
        self.size = size
        self.mediaName = mediaName
        self.name = name
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.deviceType = deviceType
        self.vendor = vendor
        self.revision = revision
    }
    
    /// Creates a DeviceInventoryItem from a Device (for new devices)
    init(from device: Device) {
        self.mediaUUID = device.mediaUUID
        self.size = device.size
        self.mediaName = device.daMediaName ?? device.name
        self.name = device.name
        self.vendor = device.daVendor ?? device.vendor
        self.revision = device.daRevision ?? device.revision
        self.deviceType = device.deviceType
        self.firstSeen = Date()
        self.lastSeen = Date()
    }
}

/// Manages the inventory of recognized devices
@MainActor
class DeviceInventory: ObservableObject, DeviceInventoryManager {
    
    @Published var devices: [DeviceInventoryItem] = []
    
    private let userDefaults = UserDefaults.standard
    private let inventoryKey = "DeviceInventory"
    
    init() {
        
        // Debug: Show UserDefaults path
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            let userDefaultsPath = "~/Library/Preferences/\(bundleIdentifier).plist"
            print("🔍 [DEBUG] UserDefaults path: \(userDefaultsPath)")
            
            // Also show the actual file path if it exists
            let expandedPath = (userDefaultsPath as NSString).expandingTildeInPath
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: expandedPath) {
                print("✅ [DEBUG] UserDefaults file exists at: \(expandedPath)")
            } else {
                print("⚠️ [DEBUG] UserDefaults file does not exist yet at: \(expandedPath)")
            }
        }
        
        loadInventory()
    }
    
    /// Adds or updates a device in the inventory
    func addOrUpdateDevice(
        mediaUUID: String,
        size: Int64,
        originalName: String,
        deviceType: DeviceType = .unknown,
        vendor: String? = nil,
        revision: String? = nil
    ) {
        let now = Date()
        
        if let existingIndex = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            // Update existing device
            var updatedDevice = devices[existingIndex]
            updatedDevice.lastSeen = now
            devices[existingIndex] = updatedDevice
            //print("📝 [INVENTORY] Updated: \(originalName)")
        } else {
            // Add new device
            let newDevice = DeviceInventoryItem(
                mediaUUID: mediaUUID,
                size: size,
                mediaName: originalName,
                name: nil,
                firstSeen: now,
                lastSeen: now,
                deviceType: deviceType,
                vendor: vendor,
                revision: revision
            )
            devices.append(newDevice)
            print("➕ [INVENTORY] Added: \(originalName)")
        }
        
        saveInventory()
    }
    
    /// Sets a custom name for a device
    func setCustomName(for mediaUUID: String, customName: String?) {
        //print("🔧 [DEBUG] DeviceInventory.setCustomName called with UUID: \(mediaUUID), name: \(customName ?? "nil")")
        if let index = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            //print("🔧 [DEBUG] Found device at index \(index), updating custom name")
            devices[index].customName = customName
            saveInventory()
            //print("✏️ [INVENTORY] Custom name set: \(customName ?? "nil")")
        } else {
            print("❌ [DEBUG] Device with UUID \(mediaUUID) not found in inventory")
            print("🔧 [DEBUG] Available devices in inventory:")
            for device in devices {
                print("   - \(device.mediaName) (UUID: \(device.mediaUUID))")
            }
        }
    }
    
    /// Sets the device type for a device
    func setDeviceType(for mediaUUID: String, deviceType: DeviceType) {
        if let index = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            devices[index].deviceType = deviceType
            saveInventory()
            print("🏷️ [INVENTORY] Device type set: \(deviceType.rawValue)")
        }
    }
    
    /// Sets the vendor for a device
    func setVendor(for mediaUUID: String, vendor: String?) {
        if let index = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            devices[index].vendor = vendor
            saveInventory()
            print("🏭 [INVENTORY] Vendor set: \(vendor ?? "nil")")
        }
    }
    
    /// Sets the revision for a device
    func setRevision(for mediaUUID: String, revision: String?) {
        if let index = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            devices[index].revision = revision
            saveInventory()
            print("📋 [INVENTORY] Revision set: \(revision ?? "nil")")
        }
    }
    
    /// Gets the display name for a device (custom name if set, otherwise original name)
    func getDisplayName(for mediaUUID: String) -> String? {
        return devices.first(where: { $0.mediaUUID == mediaUUID })?.displayName
    }
    
    /// Removes a device from inventory
    func removeDevice(with mediaUUID: String) {
        if let index = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            let deviceName = devices[index].displayName
            devices.remove(at: index)
            saveInventory()
            print("🗑️ [INVENTORY] Removed device: \(deviceName)")
        } else {
            print("❌ [DEBUG] Device with UUID \(mediaUUID) not found in inventory")
        }
    }
    
    /// Cleans up old devices that haven't been seen recently
    func cleanupOldDevices(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let initialCount = devices.count
        devices.removeAll { $0.lastSeen < cutoffDate }
        let removedCount = initialCount - devices.count
        if removedCount > 0 {
            saveInventory()
            print("🧹 [INVENTORY] Cleaned up \(removedCount) old devices")
        }
    }
    

    
    func saveInventory() {
        do {
            let data = try JSONEncoder().encode(devices)
            userDefaults.set(data, forKey: inventoryKey)
            //print("💾 [DEBUG] Saved inventory with \(devices.count) devices to UserDefaults")
            
            // Debug: Show the actual data size
            //print("📊 [DEBUG] Inventory data size: \(data.count) bytes")
        } catch {
            print("❌ [INVENTORY] Failed to save inventory: \(error)")
        }
    }
    
    /// Gets an inventory item by its media UUID
    func getInventoryItem(for mediaUUID: String) -> DeviceInventoryItem? {
        return devices.first(where: { $0.mediaUUID == mediaUUID })
    }
    
    private func loadInventory() {
        guard let data = userDefaults.data(forKey: inventoryKey) else { 
            print("📚 [DEBUG] No inventory data found in UserDefaults")
            return 
        }
        
        do {
            devices = try JSONDecoder().decode([DeviceInventoryItem].self, from: data)
            print("📚 [INVENTORY] Loaded \(devices.count) devices")
            
#if DEBUG
            // Debug: Show loaded devices
            for (index, device) in devices.enumerated() {
                print("   📱 [DEBUG] Device \(index + 1): \(String(describing: device.name)) (ID: \(device.mediaUUID))")
            }
#endif
        } catch {
            print("❌ [INVENTORY] Failed to load inventory: \(error)")
            devices = []
        }
    }
}
