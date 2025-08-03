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
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Flashing Image to Device")
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
                
                if case .completed = flashState {
                    Button("Done") {
                        onCancel()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                if case .failed = flashState {
                    Button("Close") {
                        onCancel()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(24)
        .frame(width: 500)
    }
    
    // MARK: - Computed Properties
    
    private var progressValue: Double {
        switch flashState {
        case .idle, .preparing:
            return 0.0
        case .flashing(let progress):
            return progress
        case .completed:
            return 1.0
        case .failed:
            return 0.0
        }
    }
    
    private var statusText: String {
        switch flashState {
        case .idle:
            return "Ready to flash"
        case .preparing:
            return "Preparing device..."
        case .flashing:
            return "Writing image to device..."
        case .completed:
            return "Flash completed successfully! ✅"
        case .failed(let error):
            return "Flash failed: \(error.localizedDescription) ❌"
        }
    }
    
    private var statusColor: Color {
        switch flashState {
        case .idle, .preparing, .flashing:
            return .primary
        case .completed:
            return .green
        case .failed:
            return .red
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
            mediaUUID: "DEMO_USB_001",
            mediaName: "SanDisk Ultra USB 3.0",
            vendor: "SanDisk",
            revision: "1.0",
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
            mediaUUID: "DEMO_USB_001",
            mediaName: "SanDisk Ultra USB 3.0",
            vendor: "SanDisk",
            revision: "1.0",
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
            mediaUUID: "DEMO_USB_001",
            mediaName: "SanDisk Ultra USB 3.0",
            vendor: "SanDisk",
            revision: "1.0",
            deviceType: .usbStick
        ),
        flashState: .failed(.deviceReadOnly),
        onCancel: { print("Close") }
    )
} 