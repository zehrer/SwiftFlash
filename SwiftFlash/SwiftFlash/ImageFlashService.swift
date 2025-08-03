import Foundation
import DiskArbitration
import IOKit

// MARK: - CRITICAL ERROR ENUM (DO NOT MODIFY - Flash error definitions)
// This enum defines all possible flash operation errors and their descriptions.
// Changes here affect error handling and user feedback throughout the app.
// Any modifications require testing of error handling and user messaging.
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
// END: CRITICAL ERROR ENUM

// MARK: - CRITICAL SERVICE (DO NOT MODIFY - Core flash functionality)
// This service handles the critical flash operations and state management.
// Changes here affect the core functionality of writing images to devices.
// Any modifications require thorough testing of flash operations and safety.
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
        print("🔍 [DEBUG] Validating flash preconditions")
        print("   - Image: \(image.displayName) (\(image.formattedSize))")
        print("   - Device: \(device.displayName) (\(device.formattedSize))")
        print("   - Device Path: \(device.mountPoint)")
        
        // Check if device exists and is accessible
        guard FileManager.default.fileExists(atPath: device.mountPoint) else {
            print("❌ [DEBUG] Validation failed: Device mount point not found")
            throw FlashError.deviceNotFound
        }
        print("✅ [DEBUG] Device mount point exists")
        
        // Check if image file exists
        guard FileManager.default.fileExists(atPath: image.path) else {
            print("❌ [DEBUG] Validation failed: Image file not found")
            throw FlashError.imageNotFound
        }
        print("✅ [DEBUG] Image file exists")
        
        // Check if device is read-only
        guard !device.isReadOnly else {
            print("❌ [DEBUG] Validation failed: Device is read-only")
            throw FlashError.deviceReadOnly
        }
        print("✅ [DEBUG] Device is not read-only")
        
        // Check if image fits on device
        guard image.size < device.size else {
            print("❌ [DEBUG] Validation failed: Image too large")
            print("   - Image size: \(image.formattedSize) (\(image.size) bytes)")
            print("   - Device size: \(device.formattedSize) (\(device.size) bytes)")
            throw FlashError.imageTooLarge
        }
        print("✅ [DEBUG] Image fits on device")
        
        // Check if device is mounted and writable
        print("🔍 [DEBUG] Checking device writability...")
        guard isDeviceWritable(device) else {
            print("❌ [DEBUG] Validation failed: Insufficient permissions")
            throw FlashError.insufficientPermissions
        }
        print("✅ [DEBUG] Device is writable")
        
        print("✅ [DEBUG] All flash preconditions validated successfully")
    }
    
    private func isDeviceWritable(_ device: Drive) -> Bool {
        // Check if device is mounted and writable
        // This is a simplified check - in a real implementation, you'd use DiskArbitration
        // to get more detailed information about the device's mount status and permissions
        
        let fileManager = FileManager.default
        
        print("🔍 [DEBUG] Checking device writability for: \(device.displayName)")
        print("   - Mount Point: \(device.mountPoint)")
        print("   - Device Size: \(device.formattedSize)")
        print("   - Is Read Only: \(device.isReadOnly)")
        print("   - Is Removable: \(device.isRemovable)")
        
        // Check if mount point exists
        guard fileManager.fileExists(atPath: device.mountPoint) else {
            print("❌ [DEBUG] Mount point does not exist: \(device.mountPoint)")
            return false
        }
        
        // Check if path is writable using FileManager
        let isWritableByFileManager = fileManager.isWritableFile(atPath: device.mountPoint)
        print("📋 [DEBUG] FileManager.isWritableFile result: \(isWritableByFileManager)")
        
        // Try to create a test file to check write permissions
        let testFile = device.mountPoint + "/.swiftflash_test"
        let testData = "test".data(using: .utf8)!
        
        print("🧪 [DEBUG] Attempting write test to: \(testFile)")
        
        do {
            // Try to write test file
            try testData.write(to: URL(fileURLWithPath: testFile))
            print("✅ [DEBUG] Successfully wrote test file")
            
            // Try to remove test file
            try fileManager.removeItem(atPath: testFile)
            print("✅ [DEBUG] Successfully removed test file")
            
            print("✅ [DEBUG] Device is writable - all tests passed")
            return true
            
        } catch {
            let nsError = error as NSError
            print("❌ [DEBUG] Write permission test failed")
            print("   - Error: \(error.localizedDescription)")
            print("   - Error Domain: \(nsError.domain)")
            print("   - Error Code: \(nsError.code)")
            print("   - Error User Info: \(nsError.userInfo)")
            
            // Log specific error codes for common permission issues
            switch nsError.code {
            case 1: // Operation not permitted
                print("   - Likely cause: Operation not permitted (EACCES)")
            case 13: // Permission denied
                print("   - Likely cause: Permission denied (EACCES)")
            case 30: // Read-only file system
                print("   - Likely cause: Read-only file system (EROFS)")
            case 2: // No such file or directory
                print("   - Likely cause: No such file or directory (ENOENT)")
            case 16: // Device or resource busy
                print("   - Likely cause: Device or resource busy (EBUSY)")
            default:
                print("   - Unknown error code: \(nsError.code)")
            }
            
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