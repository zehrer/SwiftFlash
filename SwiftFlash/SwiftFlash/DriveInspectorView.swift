import SwiftUI

// MARK: - Reusable Components

struct LabelAndText: View {
    let label: String
    let value: String
    let labelWidth: CGFloat
    
    init(label: String, value: String, labelWidth: CGFloat = 80) {
        self.label = label
        self.value = value
        self.labelWidth = labelWidth
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12))
        }
    }
}

struct LabelAndTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let labelWidth: CGFloat
    
    init(label: String, text: Binding<String>, placeholder: String, labelWidth: CGFloat = 80) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.labelWidth = labelWidth
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }
}

struct LabelAndPicker: View {
    let label: String
    @Binding var selection: DeviceType
    let labelWidth: CGFloat
    
    init(label: String, selection: Binding<DeviceType>, labelWidth: CGFloat = 80) {
        self.label = label
        self._selection = selection
        self.labelWidth = labelWidth
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            HStack(spacing: 8) {
                Image(systemName: selection.icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Picker("", selection: $selection) {
                    ForEach(DeviceType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 12))
            }
        }
    }
}

struct LabelAndStatus: View {
    let label: String
    let isReadOnly: Bool
    let labelWidth: CGFloat
    
    init(label: String, isReadOnly: Bool, labelWidth: CGFloat = 80) {
        self.label = label
        self.isReadOnly = isReadOnly
        self.labelWidth = labelWidth
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            HStack(spacing: 6) {
                Image(systemName: isReadOnly ? "lock.fill" : "lock.open.fill")
                    .foregroundColor(isReadOnly ? .red : .green)
                    .font(.system(size: 12))
                
                Text(isReadOnly ? "Read-only" : "Writable")
                    .font(.system(size: 12))
            }
        }
    }
}

// MARK: - Inspector Section View

struct InspectorSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Text(isExpanded ? "Hide" : "Show")
                        .font(.system(size: 13))
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
        ScrollView {
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
            deviceType: .microSDCard
        ),
        deviceInventory: DeviceInventory()
    )
    .frame(width: 300)
}
