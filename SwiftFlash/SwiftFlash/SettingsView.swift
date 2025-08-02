import SwiftUI

struct SettingsView: View {
    @ObservedObject var inventory: DeviceInventory
    @State private var selectedTab: Tab = .general
    @State private var selectedDevice: DeviceInventoryItem?
    @State private var showingDeleteAlert = false
    @State private var deviceToDelete: DeviceInventoryItem?
    
    enum Tab {
        case general
        case devices
    }
    
    private var selectedTabTitle: String {
        switch selectedTab {
        case .general:
            return "General"
        case .devices:
            return "Devices"
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("General", systemImage: "gearshape")
                    .tag(Tab.general)
                Label("Devices", systemImage: "externaldrive")
                    .tag(Tab.devices)
            }
            .listStyle(.sidebar)
        } detail: {
            VStack(spacing: 0) {
                // Entferne den eigenen Header komplett
                // Die Toolbar kommt jetzt unten
                // Content based on selected tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .general:
                            GeneralSettingsView()
                        case .devices:
                            DevicesSettingsView(
                                inventory: inventory,
                                selectedDevice: $selectedDevice,
                                showingDeleteAlert: $showingDeleteAlert,
                                deviceToDelete: $deviceToDelete
                            )
                        }
                    }
                    .padding(20)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 8) {
                        Button(action: previousTab) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedTab == Tab.general)
                        Button(action: nextTab) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedTab == Tab.devices)
                        Text(selectedTabTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $selectedDevice) { device in
            EditDeviceNameView(device: device, inventory: inventory)
        }
        .alert("Delete Device", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let device = deviceToDelete {
                    inventory.removeDevice(with: device.mediaUUID)
                    selectedDevice = nil
                }
            }
        } message: {
            if let device = deviceToDelete {
                Text("Are you sure you want to delete '\(device.displayName)' from the inventory? This action cannot be undone.")
            }
        }
    }
    
    private func previousTab() {
        if selectedTab == .devices {
            selectedTab = .general
        }
    }
    
    private func nextTab() {
        if selectedTab == .general {
            selectedTab = .devices
        }
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Appearance Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 16) {
                    AppearanceOption(
                        title: "System",
                        description: "Follow system appearance",
                        isSelected: true,
                        preview: "system"
                    )
                    
                    AppearanceOption(
                        title: "Light",
                        description: "Always use light mode",
                        isSelected: false,
                        preview: "light"
                    )
                    
                    AppearanceOption(
                        title: "Dark",
                        description: "Always use dark mode",
                        isSelected: false,
                        preview: "dark"
                    )
                }
            }
            
            Divider()
            
            // Behavior Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Behavior")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show inspector by default", isOn: .constant(true))
                    
                    Toggle("Auto-refresh drives on app launch", isOn: .constant(false))
                    
                    Toggle("Remember last selected drive", isOn: .constant(true))
                }
            }
        }
    }
}

struct AppearanceOption: View {
    let title: String
    let description: String
    let isSelected: Bool
    let preview: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color(NSColor.separatorColor), lineWidth: isSelected ? 2 : 1)
                )
                .frame(width: 120, height: 80)
                .overlay(
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Circle().fill(Color.yellow).frame(width: 8, height: 8)
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                        }
                        Text("Preview")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120)
    }
}

struct DevicesSettingsView: View {
    @ObservedObject var inventory: DeviceInventory
    @Binding var selectedDevice: DeviceInventoryItem?
    @Binding var showingDeleteAlert: Bool
    @Binding var deviceToDelete: DeviceInventoryItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Inventory")
                .font(.headline)
                .fontWeight(.semibold)
            
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
                LazyVStack(spacing: 0) {
                    ForEach(inventory.devices) { device in
                        DeviceListRowView(device: device) {
                            selectedDevice = device
                        }
                        
                        if device.id != inventory.devices.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
        }
    }
}

struct DeviceListRowView: View {
    let device: DeviceInventoryItem
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Device Icon
            Image(systemName: device.deviceType.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            // Device Info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(device.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let vendor = device.vendor {
                        Text("• \(vendor)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let revision = device.revision {
                        Text("• \(revision)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Device Type
            Text(device.deviceType.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            
            // Info Button
            Button(action: onEdit) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .contentShape(Rectangle())
    }
}

struct EditDeviceNameView: View {
    let device: DeviceInventoryItem
    @ObservedObject var inventory: DeviceInventory
    @Environment(\.dismiss) private var dismiss
    @State private var customName: String
    @State private var selectedDeviceType: DeviceType
    @State private var vendor: String
    @State private var revision: String
    @State private var showingDeleteAlert = false
    
    init(device: DeviceInventoryItem, inventory: DeviceInventory) {
        self.device = device
        self.inventory = inventory
        self._customName = State(initialValue: device.customName ?? "")
        self._selectedDeviceType = State(initialValue: device.deviceType)
        self._vendor = State(initialValue: device.vendor ?? "")
        self._revision = State(initialValue: device.revision ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Device")
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
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Device Type:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("Device Type", selection: $selectedDeviceType) {
                    ForEach(DeviceType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Vendor:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter vendor", text: $vendor)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Revision:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter revision", text: $revision)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                Button("Delete Device", role: .destructive) {
                    showingDeleteAlert = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save") {
                    if customName.isEmpty {
                        inventory.setCustomName(for: device.mediaUUID, customName: nil)
                    } else {
                        inventory.setCustomName(for: device.mediaUUID, customName: customName)
                    }
                    inventory.setDeviceType(for: device.mediaUUID, deviceType: selectedDeviceType)
                    inventory.setVendor(for: device.mediaUUID, vendor: vendor.isEmpty ? nil : vendor)
                    inventory.setRevision(for: device.mediaUUID, revision: revision.isEmpty ? nil : revision)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(customName == device.customName && 
                         selectedDeviceType == device.deviceType && 
                         vendor == (device.vendor ?? "") && 
                         revision == (device.revision ?? ""))
            }
        }
        .padding()
        .frame(width: 400)
        .alert("Delete Device", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                inventory.removeDevice(with: device.mediaUUID)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(device.displayName)' from the inventory? This action cannot be undone.")
        }
    }
    
}

#Preview {
    SettingsView(inventory: DeviceInventory())
} 