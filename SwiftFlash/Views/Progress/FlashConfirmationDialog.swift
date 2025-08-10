import SwiftUI

struct FlashConfirmationDialog: View {
    let image: ImageFile
    let device: Drive
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Warning Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            // Title
            Text("⚠️ Warning: Data Loss")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)
            
            // Warning Message
            VStack(spacing: 12) {
                Text("You are about to flash an image to a device. This operation will:")
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                        Text("**Permanently delete ALL data** on the selected device")
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text("Write the image file to the device")
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This action **cannot be undone**")
                    }
                }
                .font(.body)
            }
            
            // Device and Image Information
            VStack(spacing: 16) {
                // Target Device
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Device:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        Image(systemName: device.deviceType.icon)
                            .font(.title2)
                            .foregroundColor(device.isReadOnly ? .red : .blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("\(device.formattedSize) • \(device.mountPoint)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Image File
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image File:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(image.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Text("\(image.formattedSize) • \(image.fileType.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            // Size Check
            if image.size >= device.size {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("⚠️ Warning: Image size (\(image.formattedSize)) is larger than device capacity (\(device.formattedSize))")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Flash Image") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(image.size >= device.size)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 500)
    }
}

#Preview {
    FlashConfirmationDialog(
        image: ImageFile.demoImage,
        device: Drive(
            name: "Demo USB Stick",
            mountPoint: "/dev/disk2",
            size: 32000000000,
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: false,
            mediaUUID: "DEMO_USB_001",
            mediaName: "SanDisk Ultra USB 3.0",
            vendor: "SanDisk",
            revision: "1.0",
            diskDescription: nil,
            deviceType: .usbStick
        ),
        onConfirm: { print("Confirmed") },
        onCancel: { print("Cancelled") }
    )
} 