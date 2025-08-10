import SwiftUI

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
    let drive: Drive
    @ObservedObject var deviceInventory: DeviceInventory
    @State private var selectedDeviceType: DeviceType
    @State private var editableName: String
    
    init(drive: Drive, deviceInventory: DeviceInventory) {
        self.drive = drive
        self.deviceInventory = deviceInventory
        self._selectedDeviceType = State(initialValue: drive.deviceType)
        self._editableName = State(initialValue: drive.displayName)
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
                )
                .onChange(of: editableName) { _, newValue in
                    if let mediaUUID = drive.mediaUUID {
                        if newValue.isEmpty {
                            deviceInventory.setCustomName(for: mediaUUID, customName: nil)
                        } else {
                            deviceInventory.setCustomName(for: mediaUUID, customName: newValue)
                        }
                    }
                }
                
                // Device Type
                LabelAndPicker(
                    label: "Type",
                    selection: $selectedDeviceType
                )
                .onChange(of: selectedDeviceType) { _, newValue in
                    if let mediaUUID = drive.mediaUUID {
                        deviceInventory.setDeviceType(for: mediaUUID, deviceType: newValue)
                    }
                }
                
                // Capacity
                LabelAndText(
                    label: "Capacity",
                    value: drive.formattedSize
                )
            }
            
            // Status Section
            InspectorSectionView(title: "Status") {
                // Device Path
                LabelAndText(
                    label: "Device Path",
                    value: drive.mountPoint
                )
                
                // Partition Scheme
                LabelAndText(
                    label: "Partition Scheme",
                    value: drive.partitionSchemeDisplay
                )
                
                // Status
                LabelAndStatus(
                    label: "Status",
                    isReadOnly: drive.isReadOnly
                )
            }
            
            // Media Details Section
            InspectorSectionView(title: "Media Details") {
                // Media Name
                LabelAndText(
                    label: "Media Name",
                    value: drive.mediaName ?? "No media name"
                )
                
                // Vendor
                LabelAndText(
                    label: "Vendor",
                    value: drive.vendor ?? "Unknown"
                )
                
                // Revision
                LabelAndText(
                    label: "Revision",
                    value: drive.revision ?? "Unknown"
                )
                
                // UUID
                LabelAndText(
                    label: "UUID",
                    value: drive.mediaUUID ?? "Unknown"
                )
            }
            
            // History Section
            InspectorSectionView(title: "History") {
                // First Seen
                if let mediaUUID = drive.mediaUUID,
                   let inventoryDevice = deviceInventory.devices.first(where: { $0.mediaUUID == mediaUUID }) {
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
        drive: Drive(
            name: "Test Drive",
            mountPoint: "/dev/disk4",
            size: 31910000000,
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: true,
            mediaUUID: "TS-RDF5_TS37_3191",
            mediaName: "TS-RDF5 SD Transcend Media",
            vendor: "TS-RDF5",
            revision: "TS37",
            deviceModel: "TS-RDF5 SD Transcend",
            diskDescription: nil,
            deviceType: .microSDCard
        ),
        deviceInventory: DeviceInventory()
    )
    .frame(width: 250)
}
