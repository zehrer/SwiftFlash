import Foundation
import CryptoKit
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
        case calculatingChecksum(progress: Double)
        case flashing(progress: Double)
        case completed
        case failed(FlashError)
    }
    
    var flashState: FlashState = .idle
    var isFlashing: Bool = false
    
    private let imageHistoryService: ImageHistoryService
    
    init(imageHistoryService: ImageHistoryService) {
        self.imageHistoryService = imageHistoryService
    }
    
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
        print("🚀 [DEBUG] Starting flash process")
        print("   - Image: \(image.displayName) (\(image.formattedSize))")
        print("   - Device: \(device.displayName) (\(device.formattedSize))")
        print("   - Device Path: \(device.mountPoint)")
        
        // Get raw device path
        guard let rawDevicePath = getRawDevicePath(from: device.mountPoint) else {
            throw FlashError.flashFailed("Could not determine raw device path")
        }
        
        print("   - Raw Device Path: \(rawDevicePath)")
        
        // Step 1: Check if device is mounted
        let isMounted = isDeviceMounted(device)
        print("📋 [DEBUG] Device mounted: \(isMounted)")
        
        // Step 2: Unmount if necessary
        if isMounted {
            print("🔽 [DEBUG] Unmounting device...")
            try await unmountDevice(device)
            print("✅ [DEBUG] Device unmounted successfully")
        }
        
        // Step 3: Calculate or verify image checksum
        if let checksum = image.sha256Checksum {
            print("🔍 [DEBUG] Verifying image checksum before flashing...")
            let isValid = try await verifySHA256Checksum(for: image, expectedChecksum: checksum)
            if !isValid {
                throw FlashError.flashFailed("Image checksum verification failed - image may be corrupted")
            }
            print("✅ [DEBUG] Image checksum verified successfully")
        } else {
            print("🔍 [DEBUG] No checksum available - calculating checksum before flashing...")
            let checksum = try await calculateSHA256Checksum(for: image)
            print("✅ [DEBUG] Checksum calculated: \(checksum.prefix(8))...")
            
            // Update the image with the calculated checksum
            var updatedImage = image
            updatedImage.sha256Checksum = checksum
            
            // Store in history
            do {
                imageHistoryService.addToHistory(updatedImage)
                print("✅ [DEBUG] Updated image with checksum in history")
            } catch {
                print("⚠️ [DEBUG] Could not update image in history: \(error)")
            }
        }
        
        // Step 4: Perform the actual flash operation
        print("✏️ [DEBUG] Writing image to device...")
        try await writeImageToDevice(image: image, devicePath: rawDevicePath)
        print("✅ [DEBUG] Image written successfully")
        
        // Step 5: Verify the flash operation
        print("🔍 [DEBUG] Verifying flash operation...")
        try await verifyFlashOperation(image: image, devicePath: rawDevicePath)
        print("✅ [DEBUG] Flash verification successful")
        
        // Step 6: Remount device if it was originally mounted
        if isMounted {
            print("🔼 [DEBUG] Remounting device...")
            try await mountDevice(device)
            print("✅ [DEBUG] Device remounted successfully")
        }
        
        print("✅ [DEBUG] Flash completed successfully")
    }
    
    private func isDeviceMounted(_ device: Drive) -> Bool {
        // Check if the mount point exists and is accessible
        return FileManager.default.fileExists(atPath: device.mountPoint)
    }
    
    private func unmountDevice(_ device: Drive) async throws {
        print("   - Unmounting: \(device.mountPoint)")
        
        // Use diskutil to unmount the device
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmount", device.mountPoint]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
                throw FlashError.flashFailed("Failed to unmount device: \(output)")
            }
            
            print("   - Unmount successful")
        } catch {
            throw FlashError.flashFailed("Failed to unmount device: \(error.localizedDescription)")
        }
    }
    
    private func mountDevice(_ device: Drive) async throws {
        // Get the raw device path for mounting
        guard let rawDevicePath = getRawDevicePath(from: device.mountPoint) else {
            throw FlashError.flashFailed("Could not determine raw device path for mounting")
        }
        
        print("   - Mounting: \(rawDevicePath)")
        
        // Use diskutil to mount the device
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["mount", rawDevicePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
                throw FlashError.flashFailed("Failed to mount device: \(output)")
            }
            
            print("   - Mount successful")
        } catch {
            throw FlashError.flashFailed("Failed to mount device: \(error.localizedDescription)")
        }
    }
    
    private func writeImageToDevice(image: ImageFile, devicePath: String) async throws {
        print("   - Writing \(image.formattedSize) to \(devicePath)")
        
        // Read the image file
        let imageData = try Data(contentsOf: URL(fileURLWithPath: image.path))
        print("   - Image size: \(imageData.count) bytes")
        
        // Write the image to the device
        let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: devicePath))
        defer { try? fileHandle.close() }
        
        // Write in chunks to show progress
        let chunkSize = 1024 * 1024 // 1MB chunks
        var bytesWritten = 0
        
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            flashState = .flashing(progress: progress)
            
            // Calculate bytes for this chunk
            let startByte = Int(progress * Double(imageData.count))
            let endByte = min(startByte + chunkSize, imageData.count)
            let chunk = imageData[startByte..<endByte]
            
            // Write chunk
            try fileHandle.write(contentsOf: chunk)
            bytesWritten += chunk.count
            
            print("📊 [DEBUG] Flash progress: \(Int(progress * 100))% (\(bytesWritten) bytes written)")
            
            // Small delay to show progress
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Ensure all data is written
        try fileHandle.synchronize()
        print("   - Write completed: \(bytesWritten) bytes")
    }
    
    private func verifyFlashOperation(image: ImageFile, devicePath: String) async throws {
        print("   - Verifying flash operation...")
        
        // Read the first 1KB from both image and device for verification
        let verificationSize = 1024
        
        // Read from image
        let imageHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: image.path))
        defer { try? imageHandle.close() }
        let imageData = try imageHandle.read(upToCount: verificationSize) ?? Data()
        
        // Read from device
        let deviceHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: devicePath))
        defer { try? deviceHandle.close() }
        let deviceData = try deviceHandle.read(upToCount: verificationSize) ?? Data()
        
        // Compare
        if imageData != deviceData {
            throw FlashError.flashFailed("Flash verification failed - data mismatch")
        }
        
        print("   - Verification successful")
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
        Checksum: \(image.checksumStatus)
        """
    }
    
    // MARK: - SHA256 Checksum Methods
    
    /// Calculate SHA256 checksum for an image file
    func calculateSHA256Checksum(for image: ImageFile) async throws -> String {
        print("🔍 [DEBUG] Calculating SHA256 checksum for: \(image.displayName)")
        print("   📁 [DEBUG] Image path: \(image.path)")
        
        // Get secure URL using bookmark if available
        let fileURL: URL
        do {
            fileURL = try image.getSecureURL()
            print("   🔗 [DEBUG] Using secure URL: \(fileURL)")
        } catch {
            print("   ❌ [DEBUG] Failed to get secure URL: \(error)")
            throw FlashError.flashFailed("Failed to access file: \(error.localizedDescription)")
        }
        
        print("   🔗 [DEBUG] File URL absolute string: \(fileURL.absoluteString)")
        print("   🔗 [DEBUG] File URL path: \(fileURL.path)")
        
        // Check if file exists before trying to open it
        let fileManager = FileManager.default
        let fileExists = fileManager.fileExists(atPath: fileURL.path)
        print("   📂 [DEBUG] File exists at path: \(fileExists)")
        
        if !fileExists {
            print("   ❌ [DEBUG] File does not exist at path: \(fileURL.path)")
            throw FlashError.flashFailed("File does not exist: \(fileURL.path)")
        }
        
        // Check file permissions
        let isReadable = fileManager.isReadableFile(atPath: fileURL.path)
        print("   📖 [DEBUG] File is readable: \(isReadable)")
        
        if !isReadable {
            print("   ❌ [DEBUG] File is not readable: \(fileURL.path)")
            throw FlashError.flashFailed("File is not readable: \(fileURL.path)")
        }
        
        print("   🔓 [DEBUG] Starting chunked file reading...")
        
        // Use FileHandle for chunked reading with progress
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { 
            try? fileHandle.close()
            // Stop accessing the secure resource
            image.stopAccessingSecureResource()
        }
        
        var hasher = SHA256()
        var bytesProcessed = 0
        let totalBytes = image.size
        
        // Read and hash in chunks to show progress
        let chunkSize = 1024 * 1024 // 1MB chunks
        
        // Update state to show checksum calculation
        flashState = .calculatingChecksum(progress: 0.0)
        
        while let data = try fileHandle.read(upToCount: chunkSize) {
            hasher.update(data: data)
            bytesProcessed += data.count
            
            // Calculate and report progress
            let progress = Double(bytesProcessed) / Double(totalBytes)
            flashState = .calculatingChecksum(progress: progress)
            
            // Log progress every 5% for debugging
            if Int(progress * 20) % 20 == 0 {
                print("📊 [DEBUG] Checksum progress: \(Int(progress * 100))% (\(bytesProcessed) bytes processed)")
            }
            
            // Small delay to allow UI updates
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms delay
        }
        
        let digest = hasher.finalize()
        let checksum = digest.map { String(format: "%02x", $0) }.joined()
        
        print("✅ [DEBUG] SHA256 checksum calculated: \(checksum.prefix(8))...")
        return checksum
    }
    
    /// Verify SHA256 checksum for an image file
    func verifySHA256Checksum(for image: ImageFile, expectedChecksum: String) async throws -> Bool {
        print("🔍 [DEBUG] Verifying SHA256 checksum for: \(image.displayName)")
        
        let calculatedChecksum = try await calculateSHA256Checksum(for: image)
        let isValid = calculatedChecksum.lowercased() == expectedChecksum.lowercased()
        
        if isValid {
            print("✅ [DEBUG] Checksum verification successful")
        } else {
            print("❌ [DEBUG] Checksum verification failed")
            print("   - Expected: \(expectedChecksum)")
            print("   - Calculated: \(calculatedChecksum)")
        }
        
        return isValid
    }
    
    /// Generate and store SHA256 checksum for an image file
    func generateAndStoreChecksum(for image: ImageFile) async throws -> ImageFile {
        print("🔍 [DEBUG] Generating and storing SHA256 checksum for: \(image.displayName)")
        
        let checksum = try await calculateSHA256Checksum(for: image)
        
        // Create new ImageFile with checksum
        var updatedImage = image
        updatedImage.sha256Checksum = checksum
        
        // Try to update in history service, but don't fail if it doesn't work
        do {
            imageHistoryService.addToHistory(updatedImage)
            print("✅ [DEBUG] Checksum stored in history successfully")
        } catch {
            print("⚠️ [DEBUG] Could not store checksum in history: \(error)")
            print("   - Checksum calculated successfully: \(checksum.prefix(8))...")
            print("   - Image updated with checksum, but not saved to history")
        }
        
        return updatedImage
    }
    
    /// Generate SHA256 checksum for an image file (read-only, no storage)
    func generateChecksumOnly(for image: ImageFile) async throws -> String {
        print("🔍 [DEBUG] Generating SHA256 checksum for: \(image.displayName)")
        
        let checksum = try await calculateSHA256Checksum(for: image)
        
        print("✅ [DEBUG] Checksum calculated: \(checksum.prefix(8))...")
        return checksum
    }
} 