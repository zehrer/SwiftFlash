import SwiftUI
import Foundation
import Combine

// MARK: - Inspector Section View

struct InspectorSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(InspectorFonts.sectionHeader)
                Spacer()
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Text(isExpanded ? "Hide" : "Show")
                        .font(InspectorFonts.value)
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.accentColor)
            }
            .padding(.horizontal, 8)  // left and right !!
            .padding(.vertical, 8)
            //.frame(height: 24)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    content
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            
            Divider()
                .padding(.horizontal, 8)
                .padding(.bottom,0)
        } // VStack
        .padding(.vertical, 0)
    }
}

// MARK: - Drive Inspector View

struct DriveInspectorView: View {
    let device: Device
    var deviceInventory: any DeviceInventoryManager
    @State private var selectedDeviceType: DeviceType
    @State private var editableName: String
    
    init(drive: Device, deviceInventory: any DeviceInventoryManager) {
        self.device = drive
        self.deviceInventory = deviceInventory
        self._selectedDeviceType = State(initialValue: drive.deviceType)
        self._editableName = State(initialValue: drive.name)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Identity and Type Section
            InspectorSectionView(title: "Identity and Type") {
                // Name
                LabelAndTextField(
                    label: "Name",
                    text: $editableName,
                    placeholder: "Enter device name"
                ) {
                    // Update inventory when Enter is pressed
                    let mediaUUID = device.mediaUUID
                    if editableName.isEmpty {
                        deviceInventory.setCustomName(for: mediaUUID, customName: nil as String?)
                    } else {
                        deviceInventory.setCustomName(for: mediaUUID, customName: editableName)
                    }
                }
                
                // Device Type
                LabelAndPicker(
                    label: "Type",
                    selection: $selectedDeviceType
                )
                .onChange(of: selectedDeviceType) { _, newValue in
                    let mediaUUID = device.mediaUUID
                    deviceInventory.setDeviceType(for: mediaUUID, deviceType: newValue)
                }
                
                // Capacity
                LabelAndText(
                    label: "Capacity",
                    value: device.formattedSize
                )
            }
            
            // Status Section
            InspectorSectionView(title: "Status") {
                // Device Path
                LabelAndText(
                    label: "Device Path",
                    value: device.devicePath
                )
                
                // Partition Scheme
                LabelAndText(
                    label: "Partition Scheme",
                    value: device.partitionSchemeDisplay
                )
                
                // Status
                LabelAndStatus(
                    label: "Status",
                    isReadOnly: device.isReadOnly
                )
            }
            
            // Media Details Section
            InspectorSectionView(title: "Media Details") {
                // Media Name
                LabelAndText(
                    label: "Media Name",
                    value: device.daMediaName ?? "No media name"
                )
                
                // Vendor
                LabelAndText(
                    label: "Vendor",
                    value: device.daVendor ?? "Unknown"
                )
                
                // Revision
                LabelAndText(
                    label: "Revision",
                    value: device.daRevision ?? "Unknown"
                )
                
                // UUID
                LabelAndText(
                    label: "UUID",
                    value: device.mediaUUID
                )
            }
            
            // History Section
            InspectorSectionView(title: "History") {
                // First Seen
                let mediaUUID = device.mediaUUID
                if let inventoryDevice = deviceInventory.devices.first(where: { $0.mediaUUID == mediaUUID }) {
                    LabelAndText(
                        label: "First Seen",
                        value: inventoryDevice.firstSeen.formatted(date: .abbreviated, time: .shortened)
                    )
                    
                    // Last Seen
                    LabelAndText(
                        label: "Last Seen",
                        value: inventoryDevice.lastSeen.formatted(date: .abbreviated, time: .shortened)
                    )
                } else {
                    LabelAndText(
                        label: "First Seen",
                        value: "Not in inventory"
                    )
                    
                    LabelAndText(
                        label: "Last Seen",
                        value: "Not in inventory"
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DriveInspectorView(
        drive: Device(
            devicePath: "/dev/disk4",
            isRemovable: true,
            isEjectable: true,
            isReadOnly: true,
            isSystemDrive: false,
            diskDescription: nil,
            partitions: []
        ),
        deviceInventory: DeviceInventory()
    )
    .frame(width: 250)
}
