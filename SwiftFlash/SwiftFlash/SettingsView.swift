import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var inventory: DeviceInventory
    @State private var selectedTopic: SettingsTopic = .general
    @State private var selectedDevice: DeviceInventoryItem?
    @State private var showingDeleteAlert = false
    @State private var deviceToDelete: DeviceInventoryItem?
    
    enum SettingsTopic: String, CaseIterable {
        case general = "General"
        case devices = "Devices"
        
        var icon: String {
            switch self {
            case .general:
                return "gear"
            case .devices:
                return "externaldrive"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            // Left Sidebar - Topics
            List(SettingsTopic.allCases, id: \.self, selection: $selectedTopic) { topic in
                HStack(spacing: 8) {
                    Image(systemName: topic.icon)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text(topic.rawValue)
                        .font(.body)
                }
                .padding(.vertical, 4)
            }
            .listStyle(SidebarListStyle())
            .frame(width: 200)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right Content Area
            VStack(spacing: 0) {
                // Header with navigation arrows
                HStack {
                    HStack(spacing: 8) {
                        Button(action: previousTopic) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedTopic == SettingsTopic.allCases.first)
                        
                        Button(action: nextTopic) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedTopic == SettingsTopic.allCases.last)
                    }
                    .foregroundColor(.secondary)
                    
                    Text(selectedTopic.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Content based on selected topic
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTopic {
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
        }
        .frame(width: 800, height: 600)
        .background(Color(NSColor.controlBackgroundColor))
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
    
    private func previousTopic() {
        if let currentIndex = SettingsTopic.allCases.firstIndex(of: selectedTopic),
           currentIndex > 0 {
            selectedTopic = SettingsTopic.allCases[currentIndex - 1]
        }
    }
    
    private func nextTopic() {
        if let currentIndex = SettingsTopic.allCases.firstIndex(of: selectedTopic),
           currentIndex < SettingsTopic.allCases.count - 1 {
            selectedTopic = SettingsTopic.allCases[currentIndex + 1]
        }
    }
    
    private func deleteDevice(_ device: DeviceInventoryItem) {
        inventory.removeDevice(with: device.mediaUUID)
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
                VStack(spacing: 0) {
                    // Table Header
                    HStack(spacing: 0) {
                        Text("Display Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        Text("Size")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 100, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        Text("Type")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 80, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        Text("Device Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
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
                    .frame(maxHeight: 300)
                    
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
                    .padding(.top, 12)
                }
            }
        }
    }
}

struct DeviceTableRowView: View {
    let device: DeviceInventoryItem
    
    var body: some View {
        HStack(spacing: 0) {
            // Display Name
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Size
            Text(device.formattedSize)
                .font(.body)
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
            
            // Type
            Text("—")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
            
            // Device Name
            Text(device.originalName)
                .font(.body)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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