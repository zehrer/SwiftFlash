import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var inventory: DeviceInventory
    @State private var selectedDevice: DeviceInventoryItem?
    @State private var showingDeleteAlert = false
    @State private var deviceToDelete: DeviceInventoryItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Device Inventory")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // Device List
                if inventory.devices.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No devices in inventory")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("Devices will appear here once they are detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(inventory.devices, selection: $selectedDevice) { device in
                        DeviceRowView(device: device, inventory: inventory)
                            .contextMenu {
                                Button("Edit Name") {
                                    selectedDevice = device
                                }
                                
                                Button("Delete", role: .destructive) {
                                    deviceToDelete = device
                                    showingDeleteAlert = true
                                }
                            }
                    }
                }
            }
        }
        .frame(width: 600, height: 500)
        .sheet(item: $selectedDevice) { device in
            EditDeviceNameView(device: device, inventory: inventory)
        }
        .alert("Delete Device", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let device = deviceToDelete {
                    deleteDevice(device)
                }
            }
        } message: {
            if let device = deviceToDelete {
                Text("Are you sure you want to delete '\(device.displayName)' from the inventory? This action cannot be undone.")
            }
        }
    }
    
    private func deleteDevice(_ device: DeviceInventoryItem) {
        inventory.removeDevice(with: device.mediaUUID)
    }
}

struct DeviceRowView: View {
    let device: DeviceInventoryItem
    @ObservedObject var inventory: DeviceInventory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.headline)
                    
                    if device.customName != nil {
                        Text("Original: \(device.originalName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(device.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("ID: \(device.mediaUUID)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("First seen: \(device.firstSeen.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Last seen: \(device.lastSeen.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditDeviceNameView: View {
    let device: DeviceInventoryItem
    @ObservedObject var inventory: DeviceInventory
    @Environment(\.dismiss) private var dismiss
    @State private var customName: String
    
    init(device: DeviceInventoryItem, inventory: DeviceInventory) {
        self.device = device
        self.inventory = inventory
        self._customName = State(initialValue: device.customName ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Device Name")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Original Name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(device.originalName)
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Name:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter custom name", text: $customName)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    if customName.isEmpty {
                        inventory.setCustomName(for: device.mediaUUID, customName: nil)
                    } else {
                        inventory.setCustomName(for: device.mediaUUID, customName: customName)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(customName == device.customName)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    SettingsView(inventory: DeviceInventory())
} 