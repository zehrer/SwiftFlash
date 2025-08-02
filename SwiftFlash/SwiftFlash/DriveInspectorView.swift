import SwiftUI

struct DriveInspectorView: View {
    let drive: Drive
    
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
                Text(drive.displayName)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            // Media Name (from Disk Arbitration)
            VStack(alignment: .leading, spacing: 4) {
                Text("Media Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.mediaName ?? "No media name")
                    .font(.body)
                    .foregroundColor(drive.mediaName == nil ? .red : .secondary)
            }
            
            // Vendor
            VStack(alignment: .leading, spacing: 4) {
                Text("Vendor")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.vendor ?? "No vendor info")
                    .font(.body)
                    .foregroundColor(drive.vendor == nil ? .red : .secondary)
            }
            
            // Revision
            VStack(alignment: .leading, spacing: 4) {
                Text("Revision")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.revision ?? "No revision info")
                    .font(.body)
                    .foregroundColor(drive.revision == nil ? .red : .secondary)
            }
            
            // Size
            VStack(alignment: .leading, spacing: 4) {
                Text("Capacity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.formattedSize)
                    .font(.body)
            }
            
            // Device path
            VStack(alignment: .leading, spacing: 4) {
                Text("Device Path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.mountPoint)
                    .font(.body)
                    .font(.system(.body, design: .monospaced))
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
            }
            
            // Device type
            VStack(alignment: .leading, spacing: 4) {
                Text("Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(drive.isRemovable ? "Removable" : "Fixed")
                    .font(.body)
            }
            
            // Media UUID (if available)
            if let mediaUUID = drive.mediaUUID {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Media UUID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(mediaUUID)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Media UUID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Not available")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
}

#Preview {
    DriveInspectorView(drive: Drive(
        name: "Test Drive",
        mountPoint: "/dev/disk4",
        size: 32000000000,
        isRemovable: true,
        isSystemDrive: false,
        isReadOnly: false,
        mediaUUID: "12345678-1234-1234-1234-123456789ABC",
        mediaName: "Test Media Name",
        vendor: "Test Vendor",
        revision: "1.0"
    ))
} 