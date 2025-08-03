import Foundation
import Combine

// MARK: - CRITICAL ENUM (DO NOT MODIFY - Device type definitions)
// This enum defines device types and their icons. Changes here affect
// device categorization, UI display, and icon mapping throughout the app.
// Any modifications require testing of device type detection and display.
enum DeviceType: String, CaseIterable, Codable {
    case usbStick = "USB Stick"
    case sdCard = "SD Card"
    case microSDCard = "microSD Card"
    case externalHDD = "external HDD"
    case externalSSD = "external SSD"
    case unknown = "unknown"
    
    var icon: String {
        switch self {
        case .usbStick:
            return "mediastick"
        case .sdCard:
            return "sdcard"
        case .microSDCard:
            return "sdcard.fill"
        case .externalHDD:
            return "externaldrive.fill"
        case .externalSSD:
            return "externaldrive.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
}
// END: CRITICAL ENUM

// MARK: - CRITICAL DATA MODEL (DO NOT MODIFY - Device inventory structure)
// This struct represents devices in the inventory and is used for persistence.
// Changes here affect device tracking, data storage, and UI display.
// Any modifications require testing of device inventory functionality.
struct DeviceInventoryItem: Codable, Identifiable, Hashable {
    var id = UUID()
    let mediaUUID: String
    let size: Int64
    let originalName: String
    var customName: String?
    let firstSeen: Date
    var lastSeen: Date
    var deviceType: DeviceType = .unknown
    var vendor: String?
    var revision: String?
    
    var displayName: String {
        return customName ?? originalName
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
// END: CRITICAL DATA MODEL

/// Manages the inventory of recognized devices
@MainActor
class DeviceInventory: ObservableObject {
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
            print("📝 [INVENTORY] Updated: \(originalName)")
        } else {
            // Add new device
            let newDevice = DeviceInventoryItem(
                mediaUUID: mediaUUID,
                size: size,
                originalName: originalName,
                customName: nil,
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
        print("🔧 [DEBUG] DeviceInventory.setCustomName called with UUID: \(mediaUUID), name: \(customName ?? "nil")")
        if let index = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            print("🔧 [DEBUG] Found device at index \(index), updating custom name")
            devices[index].customName = customName
            saveInventory()
            print("✏️ [INVENTORY] Custom name set: \(customName ?? "nil")")
        } else {
            print("❌ [DEBUG] Device with UUID \(mediaUUID) not found in inventory")
            print("🔧 [DEBUG] Available devices in inventory:")
            for device in devices {
                print("   - \(device.originalName) (UUID: \(device.mediaUUID))")
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
    

    
    private func saveInventory() {
        do {
            let data = try JSONEncoder().encode(devices)
            userDefaults.set(data, forKey: inventoryKey)
            print("💾 [DEBUG] Saved inventory with \(devices.count) devices to UserDefaults")
            
            // Debug: Show the actual data size
            print("📊 [DEBUG] Inventory data size: \(data.count) bytes")
        } catch {
            print("❌ [INVENTORY] Failed to save inventory: \(error)")
        }
    }
    
    private func loadInventory() {
        guard let data = userDefaults.data(forKey: inventoryKey) else { 
            print("📚 [DEBUG] No inventory data found in UserDefaults")
            return 
        }
        
        print("📚 [DEBUG] Found inventory data in UserDefaults: \(data.count) bytes")
        
        do {
            devices = try JSONDecoder().decode([DeviceInventoryItem].self, from: data)
            print("📚 [INVENTORY] Loaded \(devices.count) devices")
            
            // Debug: Show loaded devices
            for (index, device) in devices.enumerated() {
                print("   📱 [DEBUG] Device \(index + 1): \(device.originalName) (ID: \(device.mediaUUID))")
            }
        } catch {
            print("❌ [INVENTORY] Failed to load inventory: \(error)")
            devices = []
        }
    }
} 