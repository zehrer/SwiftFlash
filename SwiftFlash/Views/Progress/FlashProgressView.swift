import SwiftUI

struct FlashProgressView: View {
    let image: ImageFile
    let device: Drive
    let flashState: ImageFlashService.FlashState
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: headerIcon)
                    .font(.system(size: 48))
                    .foregroundColor(headerColor)
                
                Text(headerTitle)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Progress Section
            VStack(spacing: 16) {
                // Progress Bar
                ProgressView(value: progressValue, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                // Status Text
                Text(statusText)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                
                // Progress Percentage
                if case .flashing(let progress) = flashState {
                    Text("\(Int(progress * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                } else if case .calculatingChecksum(let progress) = flashState {
                    Text("\(Int(progress * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            // Device and Image Info
            VStack(spacing: 16) {
                // Target Device
                HStack(spacing: 12) {
                    Image(systemName: device.deviceType.icon)
                        .font(.title2)
                        .foregroundColor(device.isReadOnly ? .red : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(device.mountPoint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
                
                // Image File
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
            
            // Action Buttons
            HStack(spacing: 16) {
                if case .flashing = flashState {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                if case .calculatingChecksum = flashState {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .padding(32)
        .frame(width: 500)
    }
    
    // MARK: - Computed Properties
    
    private var headerIcon: String {
        switch flashState {
        case .idle, .preparing:
            return "bolt.fill"
        case .authenticating:
            return "touchid"
        case .calculatingChecksum:
            return "checkmark.shield.fill"
        case .flashing:
            return "bolt.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private var headerColor: Color {
        switch flashState {
        case .idle, .preparing:
            return .blue
        case .authenticating:
            return .orange
        case .calculatingChecksum:
            return .green
        case .flashing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var headerTitle: String {
        switch flashState {
        case .idle, .preparing:
            return "Preparing to Flash"
        case .authenticating:
            return "Touch ID Authentication"
        case .calculatingChecksum:
            return "Calculating Checksum"
        case .flashing:
            return "Flashing Image to Device"
        case .completed:
            return "Flash Completed"
        case .failed:
            return "Flash Failed"
        }
    }
    
    private var statusText: String {
        switch flashState {
        case .idle:
            return "Ready to start"
        case .preparing:
            return "Preparing device and validating image..."
        case .authenticating:
            return "Please authenticate with Touch ID to continue..."
        case .calculatingChecksum:
            return "Verifying image integrity..."
        case .flashing:
            return "Writing image to device..."
        case .completed:
            return "Image successfully written to device"
        case .failed(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private var statusColor: Color {
        switch flashState {
        case .idle, .preparing:
            return .primary
        case .authenticating:
            return .orange
        case .calculatingChecksum:
            return .green
        case .flashing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var progressValue: Double {
        switch flashState {
        case .idle:
            return 0.0
        case .preparing:
            return 0.0
        case .authenticating:
            return 0.0
        case .calculatingChecksum(let progress):
            return progress
        case .flashing(let progress):
            return progress
        case .completed:
            return 1.0
        case .failed:
            return 0.0
        }
    }
}

#Preview("Flashing") {
    FlashProgressView(
        image: ImageFile.demoImage,
        device: Drive(
            name: "Demo USB Stick",
            mountPoint: "/dev/disk2",
            size: 32000000000,
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: false,
            diskDescription: nil,
            deviceType: .usbStick
        ),
        flashState: .flashing(progress: 0.45),
        onCancel: { print("Cancelled") }
    )
}

#Preview("Completed") {
    FlashProgressView(
        image: ImageFile.demoImage,
        device: Drive(
            name: "Demo USB Stick",
            mountPoint: "/dev/disk2",
            size: 32000000000,
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: false,
            diskDescription: nil,
            deviceType: .usbStick
        ),
        flashState: .completed,
        onCancel: { print("Done") }
    )
}

#Preview("Failed") {
    FlashProgressView(
        image: ImageFile.demoImage,
        device: Drive(
            name: "Demo USB Stick",
            mountPoint: "/dev/disk2",
            size: 32000000000,
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: false,
            diskDescription: nil,
            deviceType: .usbStick
        ),
        flashState: .failed(.deviceReadOnly),
        onCancel: { print("Close") }
    )
} 