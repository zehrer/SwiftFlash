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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Drive Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Divider()
            }
            
            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Enter device name", text: $editableName)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
                    .cornerRadius(4)
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
            
            // Media Name (from Disk Arbitration)
            VStack(alignment: .leading, spacing: 4) {
                Text("Media Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.mediaName ?? "No media name")
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(4)
            }
            
            // Vendor
            VStack(alignment: .leading, spacing: 4) {
                Text("Vendor")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.vendor ?? "No vendor info")
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(4)
            }
            
            // Revision
            VStack(alignment: .leading, spacing: 4) {
                Text("Revision")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.revision ?? "No revision info")
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(4)
            }
            
            // Size
            VStack(alignment: .leading, spacing: 4) {
                Text("Capacity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.formattedSize)
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(4)
            }
            
            // Device path
            VStack(alignment: .leading, spacing: 4) {
                Text("Device Path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.mountPoint)
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(4)
            }
            
            // Read-only status
            VStack(alignment: .leading, spacing: 4) {
                Text("Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    Image(systemName: drive.isReadOnly ? "lock.fill" : "lock.open.fill")
                        .foregroundColor(drive.isReadOnly ? .red : .green)
                    
                    Text(drive.isReadOnly ? "Read-only" : "Writable")
                        .font(.body)
                        .foregroundColor(drive.isReadOnly ? .red : .green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.textBackgroundColor))
                .cornerRadius(4)
            }
            
            // Device Type
            VStack(alignment: .leading, spacing: 4) {
                Text("Device Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: selectedDeviceType.icon)
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Picker("", selection: $selectedDeviceType) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedDeviceType) { newValue in
                        if let mediaUUID = drive.mediaUUID {
                            deviceInventory.setDeviceType(for: mediaUUID, deviceType: newValue)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )
                .cornerRadius(4)
            }
            
            // Media UUID (if available)
            if let mediaUUID = drive.mediaUUID {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Media UUID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(mediaUUID)
                        .font(.body)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(4)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Media UUID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Not available")
                        .font(.body)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
        }
        .padding()
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