import Foundation
import Combine

/// Represents a device in the inventory with key identifying information
struct DeviceInventoryItem: Codable, Identifiable {
    var id = UUID()
    let mediaUUID: String
    var devicePath: String
    let size: Int64
    let deviceType: String
    let originalName: String
    var customName: String?
    let firstSeen: Date
    var lastSeen: Date
    
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
        cleanupInvalidDevices()
    }
    
    /// Adds or updates a device in the inventory
    func addOrUpdateDevice(
        mediaUUID: String,
        devicePath: String,
        size: Int64,
        deviceType: String,
        originalName: String
    ) {
        let now = Date()
        
        if let existingIndex = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            // Update existing device
            var updatedDevice = devices[existingIndex]
            updatedDevice.lastSeen = now
            updatedDevice.devicePath = devicePath // Update path in case it changed
            devices[existingIndex] = updatedDevice
            print("📝 [INVENTORY] Updated: \(originalName)")
        } else {
            // Add new device
            let newDevice = DeviceInventoryItem(
                mediaUUID: mediaUUID,
                devicePath: devicePath,
                size: size,
                deviceType: deviceType,
                originalName: originalName,
                customName: nil,
                firstSeen: now,
                lastSeen: now
            )
            devices.append(newDevice)
            print("➕ [INVENTORY] Added: \(originalName)")
        }
        
        saveInventory()
    }
    
    /// Sets a custom name for a device
    func setCustomName(for mediaUUID: String, customName: String) {
        print("🔧 [DEBUG] DeviceInventory.setCustomName called with UUID: \(mediaUUID), name: \(customName)")
        if let index = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            print("🔧 [DEBUG] Found device at index \(index), updating custom name")
            devices[index].customName = customName
            saveInventory()
            print("✏️ [INVENTORY] Custom name set: \(customName)")
        } else {
            print("❌ [DEBUG] Device with UUID \(mediaUUID) not found in inventory")
            print("🔧 [DEBUG] Available devices in inventory:")
            for device in devices {
                print("   - \(device.originalName) (UUID: \(device.mediaUUID))")
            }
        }
    }
    
    /// Gets the display name for a device (custom name if set, otherwise original name)
    func getDisplayName(for mediaUUID: String) -> String? {
        return devices.first(where: { $0.mediaUUID == mediaUUID })?.displayName
    }
    
    /// Removes a device from inventory
    func removeDevice(mediaUUID: String) {
        devices.removeAll { $0.mediaUUID == mediaUUID }
        saveInventory()
                    print("🗑️ [INVENTORY] Device removed")
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
    
    /// Cleans up invalid devices (partitions, old UUID format, etc.)
    private func cleanupInvalidDevices() {
        let initialCount = devices.count
        var devicesToRemove: [Int] = []
        
        for (index, device) in devices.enumerated() {
            // Remove devices with old UUID format (contains underscores and long numbers)
            if device.mediaUUID.contains("_") && device.mediaUUID.count > 20 {
                print("🗑️ [DEBUG] Removing device with old UUID format: \(device.originalName) (ID: \(device.mediaUUID))")
                devicesToRemove.append(index)
                continue
            }
            
            // Remove partition-like devices (ESP, Gap1, ISO9660, etc.)
            let partitionNames = ["ESP", "Gap1", "ISO9660", "Untitled"]
            if partitionNames.contains(where: { device.originalName.contains($0) }) {
                print("🗑️ [DEBUG] Removing partition-like device: \(device.originalName) (ID: \(device.mediaUUID))")
                devicesToRemove.append(index)
                continue
            }
            
            // Remove devices with very small sizes (likely partitions)
            if device.size < 100 * 1024 * 1024 { // Less than 100MB
                print("🗑️ [DEBUG] Removing small device (likely partition): \(device.originalName) (ID: \(device.mediaUUID), Size: \(device.formattedSize))")
                devicesToRemove.append(index)
                continue
            }
        }
        
        // Remove devices in reverse order to maintain indices
        for index in devicesToRemove.reversed() {
            devices.remove(at: index)
        }
        
        let removedCount = initialCount - devices.count
        if removedCount > 0 {
            saveInventory()
            print("🧹 [INVENTORY] Cleaned up \(removedCount) invalid devices")
            print("📊 [DEBUG] Remaining devices: \(devices.count)")
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