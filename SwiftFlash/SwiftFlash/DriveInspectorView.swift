import SwiftUI

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
                // Basic Information Section
                DisclosureGroup("Basic Information") {
                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding(.top, 8)
                }
                .font(.system(size: 13, weight: .bold))
                
                // Device Details Section
                DisclosureGroup("Device Details") {
                    VStack(alignment: .leading, spacing: 12) {
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
                        
                        // Device Type
                        HStack {
                            Text("Device Type")
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
                    }
                    .padding(.top, 8)
                }
                .font(.system(size: 13, weight: .bold))
                
                // Media UUID Section
                if let mediaUUID = drive.mediaUUID {
                    DisclosureGroup("Media UUID") {
                        VStack(alignment: .leading, spacing: 12) {
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
                        .padding(.top, 8)
                    }
                    .font(.system(size: 13, weight: .bold))
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
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