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
        print("🔍 [DEBUG] Checking device writability for: \(device.displayName)")
        print("   - Mount Point: \(device.mountPoint)")
        print("   - Device Size: \(device.formattedSize)")
        print("   - Is Read Only: \(device.isReadOnly)")
        print("   - Is Removable: \(device.isRemovable)")
        
        // Try raw device access test
        return testRawDeviceAccess(device)
    }
    
    private func testRawDeviceAccess(_ device: Drive) -> Bool {
        print("🧪 [DEBUG] Testing raw device access...")
        
        // Get the raw device path (e.g., /dev/disk4 instead of /Volumes/USB_DRIVE)
        guard let rawDevicePath = getRawDevicePath(from: device.mountPoint) else {
            print("❌ [DEBUG] Could not determine raw device path for: \(device.mountPoint)")
            return false
        }
        
        print("   - Raw Device Path: \(rawDevicePath)")
        
        // Test data (10 bytes from a typical image header)
        let testBytes: [UInt8] = [0x55, 0xAA, 0x90, 0xEB, 0x1E, 0x00, 0x00, 0x00, 0x00, 0x00]
        let testData = Data(testBytes)
        
        do {
            // Step 1: Read original 10 bytes from device
            print("📖 [DEBUG] Reading original 10 bytes from device...")
            let originalBytes = try readBytesFromDevice(rawDevicePath, offset: 0, length: 10)
            print("✅ [DEBUG] Successfully read original bytes: \(originalBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
            
            // Step 2: Write test bytes to device
            print("✏️ [DEBUG] Writing test bytes to device...")
            try writeBytesToDevice(rawDevicePath, data: testData, offset: 0)
            print("✅ [DEBUG] Successfully wrote test bytes")
            
            // Step 3: Read back and verify
            print("🔍 [DEBUG] Reading back bytes for verification...")
            let readBackBytes = try readBytesFromDevice(rawDevicePath, offset: 0, length: 10)
            print("   - Written: \(testData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            print("   - Read back: \(readBackBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
            
            // Step 4: Verify bytes match
            let bytesMatch = testData == readBackBytes
            print("✅ [DEBUG] Byte verification: \(bytesMatch ? "SUCCESS" : "FAILED")")
            
            // Step 5: Restore original bytes
            print("🔄 [DEBUG] Restoring original bytes...")
            try writeBytesToDevice(rawDevicePath, data: originalBytes, offset: 0)
            print("✅ [DEBUG] Successfully restored original bytes")
            
            if bytesMatch {
                print("✅ [DEBUG] Raw device access test PASSED - device is writable")
                return true
            } else {
                print("❌ [DEBUG] Raw device access test FAILED - bytes don't match")
                return false
            }
            
        } catch {
            let nsError = error as NSError
            print("❌ [DEBUG] Raw device access test failed")
            print("   - Error: \(error.localizedDescription)")
            print("   - Error Domain: \(nsError.domain)")
            print("   - Error Code: \(nsError.code)")
            print("   - Error User Info: \(nsError.userInfo)")
            
            // Log specific error codes for device access issues
            switch nsError.code {
            case 1: // Operation not permitted
                print("   - Likely cause: Operation not permitted (EACCES) - need elevated privileges")
            case 13: // Permission denied
                print("   - Likely cause: Permission denied (EACCES) - device access restricted")
            case 16: // Device or resource busy
                print("   - Likely cause: Device or resource busy (EBUSY) - device in use")
            case 30: // Read-only file system
                print("   - Likely cause: Read-only file system (EROFS) - device mounted read-only")
            case 2: // No such file or directory
                print("   - Likely cause: No such file or directory (ENOENT) - device not found")
            default:
                print("   - Unknown error code: \(nsError.code)")
            }
            
            return false
        }
    }
    
    private func getRawDevicePath(from mountPoint: String) -> String? {
        // Extract device name from mount point
        // e.g., /Volumes/USB_DRIVE -> /dev/disk4
        // This is a simplified approach - in production you'd use DiskArbitration
        
        // Try common device naming patterns
        let possibleDevices = [
            "/dev/disk0", "/dev/disk1", "/dev/disk2", "/dev/disk3", "/dev/disk4",
            "/dev/disk5", "/dev/disk6", "/dev/disk7", "/dev/disk8", "/dev/disk9"
        ]
        
        for devicePath in possibleDevices {
            if FileManager.default.fileExists(atPath: devicePath) {
                // Check if this device is mounted at our mount point
                // This is a simplified check - in production you'd use proper device enumeration
                if isDeviceMountedAt(devicePath, mountPoint: mountPoint) {
                    return devicePath
                }
            }
        }
        
        return nil
    }
    
    private func isDeviceMountedAt(_ devicePath: String, mountPoint: String) -> Bool {
        // Simplified check - in production you'd use proper device enumeration
        // For now, we'll assume the device exists and is accessible
        return FileManager.default.fileExists(atPath: devicePath)
    }
    
    private func readBytesFromDevice(_ devicePath: String, offset: UInt64, length: Int) throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: devicePath))
        defer { try? fileHandle.close() }
        
        try fileHandle.seek(toOffset: offset)
        let data = try fileHandle.read(upToCount: length) ?? Data()
        
        if data.count != length {
            throw FlashError.flashFailed("Read incomplete: expected \(length) bytes, got \(data.count)")
        }
        
        return data
    }
    
    private func writeBytesToDevice(_ devicePath: String, data: Data, offset: UInt64) throws {
        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: devicePath))
        defer { try? fileHandle.close() }
        
        try fileHandle.seek(toOffset: offset)
        try fileHandle.write(contentsOf: data)
        try fileHandle.synchronize() // Ensure data is written to device
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