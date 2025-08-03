import Foundation
import DiskArbitration
import IOKit

// Move FlashError outside the class to avoid actor isolation issues
enum FlashError: Error {
    case deviceNotFound
    case imageNotFound
    case deviceReadOnly
    case imageTooLarge
    case insufficientPermissions
    case flashFailed(String)
    case deviceBusy

    var description: String {
        switch self {
        case .deviceNotFound:
            return "Device not found"
        case .imageNotFound:
            return "Image file not found"
        case .deviceReadOnly:
            return "Device is read-only"
        case .imageTooLarge:
            return "Image is too large for the selected device"
        case .insufficientPermissions:
            return "Insufficient permissions to write to device"
        case .flashFailed(let reason):
            return "Flash failed: \(reason)"
        case .deviceBusy:
            return "Device is currently in use"
        }
    }
}

@Observable
class ImageFlashService {
    enum FlashState {
        case idle
        case preparing
        case flashing(progress: Double)
        case completed
        case failed(FlashError)
    }
    
    var flashState: FlashState = .idle
    var isFlashing: Bool = false
    
    // MARK: - Public Methods
    
    func flashImage(_ image: ImageFile, to device: Drive) async throws {
        guard !isFlashing else {
            throw FlashError.deviceBusy
        }
        
        // Validate preconditions
        try validateFlashPreconditions(image: image, device: device)
        
        isFlashing = true
        flashState = .preparing
        
        do {
            // Simulate flash process with progress updates
            try await performFlash(image: image, device: device)
            flashState = .completed
        } catch {
            let flashError = error as? FlashError ?? .flashFailed("\(error)")
            flashState = .failed(flashError)
            isFlashing = false
            throw flashError
        }
        
        isFlashing = false
    }
    
    func resetState() {
        flashState = .idle
        isFlashing = false
    }
    
    // MARK: - Private Methods
    
    private func validateFlashPreconditions(image: ImageFile, device: Drive) throws {
        // Check if device exists and is accessible
        guard FileManager.default.fileExists(atPath: device.mountPoint) else {
            throw FlashError.deviceNotFound
        }
        
        // Check if image file exists
        guard FileManager.default.fileExists(atPath: image.path) else {
            throw FlashError.imageNotFound
        }
        
        // Check if device is read-only
        guard !device.isReadOnly else {
            throw FlashError.deviceReadOnly
        }
        
        // Check if image fits on device
        guard image.size < device.size else {
            throw FlashError.imageTooLarge
        }
        
        // Check if device is mounted and writable
        guard isDeviceWritable(device) else {
            throw FlashError.insufficientPermissions
        }
    }
    
    private func isDeviceWritable(_ device: Drive) -> Bool {
        // Check if device is mounted and writable
        // This is a simplified check - in a real implementation, you'd use DiskArbitration
        // to get more detailed information about the device's mount status and permissions
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: device.mountPoint) else {
            return false
        }
        
        // Try to create a test file to check write permissions
        let testFile = device.mountPoint + "/.swiftflash_test"
        let testData = "test".data(using: .utf8)!
        
        do {
            try testData.write(to: URL(fileURLWithPath: testFile))
            try fileManager.removeItem(atPath: testFile)
            return true
        } catch {
            return false
        }
    }
    
    private func performFlash(image: ImageFile, device: Drive) async throws {
        // This is a simulation of the flash process
        // In a real implementation, you would:
        // 1. Unmount the device if it's mounted
        // 2. Use dd command or similar to write the image
        // 3. Verify the write operation
        // 4. Remount the device if needed
        
        print("🚀 [DEBUG] Starting flash process")
        print("   - Image: \(image.displayName) (\(image.formattedSize))")
        print("   - Device: \(device.displayName) (\(device.formattedSize))")
        print("   - Device Path: \(device.mountPoint)")
        
        // Simulate progress updates
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            flashState = .flashing(progress: progress)
            
            // Simulate work
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            print("📊 [DEBUG] Flash progress: \(Int(progress * 100))%")
        }
        
        // Simulate completion
        print("✅ [DEBUG] Flash completed successfully")
    }
    
    // MARK: - Utility Methods
    
    func getDeviceInfo(_ device: Drive) -> String {
        return """
        Device: \(device.displayName)
        Size: \(device.formattedSize)
        Mount Point: \(device.mountPoint)
        Read Only: \(device.isReadOnly ? "Yes" : "No")
        Removable: \(device.isRemovable ? "Yes" : "No")
        """
    }
    
    func getImageInfo(_ image: ImageFile) -> String {
        return """
        Image: \(image.displayName)
        Size: \(image.formattedSize)
        Type: \(image.fileType.displayName)
        Path: \(image.path)
        """
    }
} 