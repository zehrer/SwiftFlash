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
        loadInventory()
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
        if let index = devices.firstIndex(where: { $0.mediaUUID == mediaUUID }) {
            devices[index].customName = customName
            saveInventory()
            print("✏️ [INVENTORY] Custom name set: \(customName)")
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
    
    private func saveInventory() {
        do {
            let data = try JSONEncoder().encode(devices)
            userDefaults.set(data, forKey: inventoryKey)
        } catch {
            print("❌ [INVENTORY] Failed to save inventory: \(error)")
        }
    }
    
    private func loadInventory() {
        guard let data = userDefaults.data(forKey: inventoryKey) else { return }
        
        do {
            devices = try JSONDecoder().decode([DeviceInventoryItem].self, from: data)
            print("📚 [INVENTORY] Loaded \(devices.count) devices")
        } catch {
            print("❌ [INVENTORY] Failed to load inventory: \(error)")
            devices = []
        }
    }
} 