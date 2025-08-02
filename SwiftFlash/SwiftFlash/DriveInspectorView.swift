import SwiftUI

struct InspectorSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: {
                    //TODO: change animation
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
                    HStack {
                        Text("Name")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("Enter device name", text: $editableName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .onChange(of: editableName) { newValue in
                                if let mediaUUID = drive.mediaUUID {
                                    if newValue.isEmpty {
                                        deviceInventory.setCustomName(for: mediaUUID, customName: nil)
                                    } else {
                                        deviceInventory.setCustomName(for: mediaUUID, customName: newValue)
                                    }
                                }
                            }
                    }
                    
                    // Device Type
                    HStack {
                        Text("Type")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        HStack(spacing: 8) {
                            Image(systemName: selectedDeviceType.icon)
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            
                            Picker("", selection: $selectedDeviceType) {
                                ForEach(DeviceType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 12))
                            .onChange(of: selectedDeviceType) { newValue in
                                if let mediaUUID = drive.mediaUUID {
                                    deviceInventory.setDeviceType(for: mediaUUID, deviceType: newValue)
                                }
                            }
                        }
                    }
                    
                    // Capacity
                    HStack {
                        Text("Capacity")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(drive.formattedSize)
                            .font(.system(size: 12))
                    }
                }
                
                // Status Section
                InspectorSectionView(title: "Status") {
                    // Device Path
                    HStack {
                        Text("Device Path")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(drive.mountPoint)
                            .font(.system(size: 12))
                    }
                    
                    // Status
                    HStack {
                        Text("Status")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        HStack(spacing: 6) {
                            Image(systemName: drive.isReadOnly ? "lock.fill" : "lock.open.fill")
                                .foregroundColor(drive.isReadOnly ? .red : .green)
                                .font(.system(size: 12))
                            
                            Text(drive.isReadOnly ? "Read-only" : "Writable")
                                .font(.system(size: 12))
                        }
                    }
                }
                
                // Media Details Section
                InspectorSectionView(title: "Media Details") {
                    // Media Name
                    HStack {
                        Text("Media Name")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(drive.mediaName ?? "No media name")
                            .font(.system(size: 12))
                    }
                    
                    // Vendor
                    HStack {
                        Text("Vendor")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(drive.vendor ?? "No vendor info")
                            .font(.system(size: 12))
                    }
                    
                    // Revision
                    HStack {
                        Text("Revision")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        Text(drive.revision ?? "No revision info")
                            .font(.system(size: 12))
                    }
                    
                    // Media UUID
                    if let mediaUUID = drive.mediaUUID {
                        HStack {
                            Text("UUID")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(mediaUUID)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    DriveInspectorView(
        drive: Drive(
            name: "Test Drive",
            mountPoint: "/dev/disk4",
            size: 32000000000,
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: false,
            mediaUUID: "12345678-1234-1234-1234-123456789ABC",
            mediaName: "Test Media Name",
            vendor: "Test Vendor",
            revision: "1.0",
            deviceType: .usbStick
        ),
        deviceInventory: DeviceInventory()
    )
} 