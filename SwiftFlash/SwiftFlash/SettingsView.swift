import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var inventory: DeviceInventory
    @State private var selectedDevice: DeviceInventoryItem?
    @State private var showingDeleteAlert = false
    @State private var deviceToDelete: DeviceInventoryItem?
    
    var body: some View {
        NavigationView {
            // Left side - Device Library
            VStack(alignment: .leading, spacing: 0) {
                Text("Device Library")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Manage your device inventory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Devices are automatically added when detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Spacer()
            }
            .frame(width: 200)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right side - Device Table
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Devices")
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
                
                // Device Table
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
                    VStack(spacing: 0) {
                        // Table Header
                        HStack(spacing: 0) {
                            Text("Anzeigename")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color(NSColor.controlBackgroundColor))
                            
                            Divider()
                            
                            Text("Größe")
                                .font(.headline)
                                .frame(width: 100, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color(NSColor.controlBackgroundColor))
                            
                            Divider()
                            
                            Text("Type")
                                .font(.headline)
                                .frame(width: 80, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color(NSColor.controlBackgroundColor))
                            
                            Divider()
                            
                            Text("Device Name")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .background(Color(NSColor.controlBackgroundColor))
                        }
                        .border(Color(NSColor.separatorColor), width: 1)
                        
                        // Table Content
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(inventory.devices) { device in
                                    DeviceTableRowView(device: device)
                                        .onTapGesture {
                                            selectedDevice = device
                                        }
                                        .contextMenu {
                                            Button("Edit Name") {
                                                selectedDevice = device
                                            }
                                            
                                            Button("Delete", role: .destructive) {
                                                deviceToDelete = device
                                                showingDeleteAlert = true
                                            }
                                        }
                                    
                                    Divider()
                                }
                            }
                        }
                        
                        // Delete Button
                        HStack {
                            Button(action: {
                                if let selected = selectedDevice {
                                    deviceToDelete = selected
                                    showingDeleteAlert = true
                                }
                            }) {
                                Image(systemName: "minus.circle")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedDevice == nil)
                            .foregroundColor(selectedDevice == nil ? .secondary : .red)
                            
                            if selectedDevice != nil {
                                Text("Delete selected device")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
        .sheet(item: $selectedDevice) { device in
            EditDeviceNameView(device: device, inventory: inventory)
        }
        .alert("Delete Device", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let device = deviceToDelete {
                    deleteDevice(device)
                    selectedDevice = nil
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

struct DeviceTableRowView: View {
    let device: DeviceInventoryItem
    
    var body: some View {
        HStack(spacing: 0) {
            // Anzeigename (Display Name)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.body)
                    .lineLimit(1)
                
                if device.customName != nil {
                    Text("Custom name set")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            
            Divider()
            
            // Größe (Size)
            Text(device.formattedSize)
                .font(.body)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            
            Divider()
            
            // Type (placeholder for later)
            Text("—")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            
            Divider()
            
            // Device Name (original name)
            Text(device.originalName)
                .font(.body)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .contentShape(Rectangle())
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