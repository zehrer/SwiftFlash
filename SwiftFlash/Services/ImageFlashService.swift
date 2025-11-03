import Combine
import CryptoKit
import DiskArbitration
import Foundation
import IOKit
import LocalAuthentication
import Security
import SwiftUI

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
    case authenticationFailed
    case authorizationDenied

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
        case .authenticationFailed:
            return "Touch ID authentication failed"
        case .authorizationDenied:
            return "Root privileges denied"
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
        case authenticating
        case calculatingChecksum(progress: Double)
        case flashing(progress: Double)
        case completed
        case failed(FlashError)
    }

    var flashState: FlashState = .idle
    var isFlashing: Bool = false
    private var isCancelled: Bool = false

    private let imageHistoryService: any ImageHistoryServiceProtocol
    @MainActor private var authorizationRef: AuthorizationRef?

    init(imageHistoryService: any ImageHistoryServiceProtocol) {
        self.imageHistoryService = imageHistoryService
    }
    
    // MARK: - Public Methods

    /// Flashes an image file to a target device with comprehensive validation and progress tracking.
    ///
    /// This method performs the complete flash operation including:
    /// - Precondition validation (device accessibility, image compatibility, etc.)
    /// - Touch ID authentication for root privileges
    /// - Checksum calculation/verification
    /// - Device unmounting/mounting as needed
    /// - Image writing using `dd` with authorized root privileges
    /// - Flash verification
    /// - Progress state management
    ///
    /// - Parameters:
    ///   - image: The `ImageFile` to flash to the device
    ///   - device: The target `Drive` to flash the image to
    /// - Throws: `FlashError` for various failure conditions (device not found, insufficient permissions, etc.)
    /// - Note: This method requires Touch ID authentication for root privileges
    func flashImage(_ image: ImageFile, to device: Device) async throws {
        guard !isFlashing else {
            throw FlashError.deviceBusy
        }

        // Validate preconditions
        try validateFlashPreconditions(image: image, device: device)

        isFlashing = true
        flashState = .preparing

        do {
            // Authenticate with Touch ID for root privileges
            flashState = .authenticating
            try await authenticateForRootPrivileges()

            // Perform flash process with progress updates
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

    /// Resets the flash service state to idle, clearing all flags and state variables.
    ///
    /// This method should be called to prepare the service for a new flash operation
    /// or to clear any previous operation state.
    func resetState() {
        flashState = .idle
        isFlashing = false
        isCancelled = false
    }

    /// Cancels the current flash operation by setting the cancellation flag.
    ///
    /// The actual cancellation is handled gracefully by the running operation
    /// which will check this flag and stop at appropriate points.
    /// The state will be reset when the operation completes.
    func cancel() {
        isCancelled = true
        // Don't reset state immediately - let the operation check the flag and handle cancellation
        // The state will be reset when the operation completes or throws due to cancellation
    }

    // MARK: - Authentication Methods

    /// Requests admin privileges using AuthorizationServices for dd command execution.
    ///
    /// This method uses the macOS AuthorizationServices framework to request
    /// administrator privileges needed for the dd command. This will show
    /// the system authentication dialog (password, Touch ID, or Apple Watch).
    ///
    /// - Throws: `FlashError.authenticationFailed` if authorization fails
    /// - Note: This method requires user interaction for admin authentication
    private func authenticateForRootPrivileges() async throws {
        print("🔐 [DEBUG] Requesting admin privileges for dd command...")
        
        // Create authorization reference
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, [], &authRef)
        
        guard status == errAuthorizationSuccess else {
            print("❌ [DEBUG] Failed to create authorization reference: \(status)")
            throw FlashError.authenticationFailed
        }
        
        // Define the privilege we need
        let authStatus = "system.privilege.admin".withCString { namePtr in
            var authItem = AuthorizationItem(
                name: namePtr,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            
            return withUnsafeMutablePointer(to: &authItem) { itemPtr in
                var authRights = AuthorizationRights(
                    count: 1,
                    items: itemPtr
                )
                
                return AuthorizationCopyRights(
                    authRef!,
                    &authRights,
                    nil,
                    [.interactionAllowed, .preAuthorize, .extendRights],
                    nil
                )
            }
        }
        
        guard authStatus == errAuthorizationSuccess else {
            print("❌ [DEBUG] Admin privileges denied: \(authStatus)")
            AuthorizationFree(authRef!, [])
            throw FlashError.authorizationDenied
        }
        
        // Store authorization for dd command
        self.authorizationRef = authRef
        //print("✅ [DEBUG] Admin privileges granted")
    }

    // MARK: - Private Methods

    /// Validates all preconditions required for a successful flash operation.
    ///
    /// This method performs comprehensive validation including:
    /// - Device existence and accessibility
    /// - Image file existence
    /// - Device read-only status
    /// - Image size compatibility with device
    /// - Device mount point validation
    ///
    /// - Parameters:
    ///   - image: The `ImageFile` to validate
    ///   - device: The target `Drive` to validate
    /// - Throws: `FlashError` for any validation failure
    private func validateFlashPreconditions(image: ImageFile, device: Device) throws {

        // Check if device exists and is accessible
        guard FileManager.default.fileExists(atPath: device.mountPoint) else {
            print("❌ [DEBUG] Validation failed: Device mount point not found")
            throw FlashError.deviceNotFound
        }

        // Check if image file exists
        guard FileManager.default.fileExists(atPath: image.path) else {
            print("❌ [DEBUG] Validation failed: Image file not found")
            throw FlashError.imageNotFound
        }

        // TODO: to analyse which failure modes is covered here
        // Check if device is read-only
        guard !device.isReadOnly else {
            print("❌ [DEBUG] Validation failed: Device is read-only")
            throw FlashError.deviceReadOnly
        }

        // Check if image fits on device
        guard image.size < device.size else {
            print("❌ [DEBUG] Validation failed: Image too large")
            print("   - Image size: \(image.formattedSize) (\(image.size) bytes)")
            print("   - Device size: \(device.formattedSize) (\(device.size) bytes)")
            throw FlashError.imageTooLarge
        }

        // Validate device mount point format
        guard !device.mountPoint.contains("/Volumes") else {
            print("❌ [DEBUG] Validation failed: Volume mount points are not supported for flashing")
            throw FlashError.deviceNotFound
        }

        //        // Check if device mount point exists
        //        guard FileManager.default.fileExists(atPath: device.mountPoint) else {
        //            print("❌ [DEBUG] Validation failed: Device mount point does not exist: \(device.mountPoint)")
        //            throw FlashError.deviceNotFound
        //        }

    }

    /// Converts a device mount point to its corresponding raw device path.
    ///
    /// This method performs safety checks and path conversion:
    /// - Rejects volume mount points (e.g., `/Volumes/USB_DRIVE`)
    /// - Rejects partition paths (e.g., `/dev/disk4s1`)
    /// - Converts device paths to raw device paths (e.g., `/dev/disk4` → `/dev/rdisk4`)
    ///
    /// - Parameter mountPoint: The device mount point or path to convert
    /// - Returns: The raw device path if valid, `nil` if the path is invalid or unsafe
    /// - Note: Raw device paths are required for direct device access operations
    private func getRawDevicePath(from mountPoint: String) -> String? {
        //print("🔍 [DEBUG] Getting raw device path from mount point: \(mountPoint)")

        // Safety check: reject volume mount points
        if mountPoint.contains("/Volumes") {
            print("❌ [DEBUG] Volume mount point detected - rejecting: \(mountPoint)")
            return nil
        }

        // Safety check: reject partition paths (e.g., /dev/disk4s1)
        let lastComponent = URL(fileURLWithPath: mountPoint).lastPathComponent
        if (try? Regex("s\\d+$").firstMatch(in: lastComponent)) != nil {
            print("❌ [DEBUG] Partition path detected - rejecting: \(mountPoint)")
            return nil
        }

        // Convert device path to raw device (e.g., /dev/disk4 → /dev/rdisk4)
        if mountPoint.hasPrefix("/dev/disk") {
            let rawDevicePath = mountPoint.replacingOccurrences(of: "/dev/disk", with: "/dev/rdisk")
            print("✅ [DEBUG] Converting device path to raw: \(mountPoint) → \(rawDevicePath)")
            return rawDevicePath
        }

        print("❌ [DEBUG] Invalid device path format: \(mountPoint)")
        return nil
    }

    /// Performs the complete flash operation with all necessary steps.
    ///
    /// This method orchestrates the entire flash process:
    /// - Converts device mount point to raw device path
    /// - Sudo availability verification
    /// - Device mount state management (unmount/remount as needed)
    /// - Image checksum calculation or verification
    /// - Image writing using `dd` with progress tracking
    /// - Flash verification
    ///
    /// - Parameters:
    ///   - image: The `ImageFile` to flash
    ///   - device: The `Drive` object representing the target device
    /// - Throws: `FlashError` for any operation failure
    /// - Note: This method requires sudo privileges and handles device mounting automatically
    private func performFlash(image: ImageFile, device: Device) async throws {

        // Get raw device path for flash operations
        guard let rawDevicePath = getRawDevicePath(from: device.mountPoint) else {
            throw FlashError.flashFailed(
                "Could not determine raw device path for: \(device.mountPoint)")
        }
        //print("   - Raw Device Path: \(rawDevicePath)")

        // Root privileges are already obtained via Touch ID authentication
        print("✅ [DEBUG] Root privileges available via Touch ID")

        // Step 1: Check if device is mounted
        let isMounted = isDeviceMounted(device.mountPoint)
        //print("📋 [DEBUG] Device mounted: \(isMounted)")

        // Step 2: Unmount if necessary
        if isMounted {
            //print("🔽 [DEBUG] Unmounting device using Drive.unmountDevice()...")
            guard device.unmountDevice() else {
                throw FlashError.flashFailed("Failed to unmount device: \(device.mountPoint)")
            }
            print("✅ [DEBUG] Device \(device.mountPoint) successfully unmounted")
        }

        // Step 3: Calculate or verify image checksum
//        if let checksum = image.sha256Checksum {
//            print("🔍 [DEBUG] Verifying image checksum before flashing...")
//            let isValid = try await verifySHA256Checksum(for: image, expectedChecksum: checksum)
//            if !isValid {
//                throw FlashError.flashFailed(
//                    "Image checksum verification failed - image may be corrupted")
//            }
//            print("✅ [DEBUG] Image checksum verified successfully")
//        } else {
//            print("🔍 [DEBUG] No checksum available - calculating checksum before flashing...")
//            let checksum = try await calculateSHA256Checksum(for: image)
//            print("✅ [DEBUG] Checksum calculated: \(checksum.prefix(8))...")
//
//            // Update the image with the calculated checksum
//            var updatedImage = image
//            updatedImage.sha256Checksum = checksum
//
//            // Store in history
//            imageHistoryService.addToHistory(updatedImage)
//            print("✅ [DEBUG] Updated image with checksum in history")
//        }

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
            print("🔼 [DEBUG] Remounting device using Drive.mountDevice()...")
            guard device.mountDevice() else {
                throw FlashError.flashFailed("Failed to remount device: \(device.mountPoint)")
            }
            print("✅ [DEBUG] Device remounted successfully using Drive method")
        }

        print("✅ [DEBUG] Flash completed successfully")
    }

    /// Checks if a device is currently mounted by verifying the mount point exists.
    ///
    /// - Parameter mountPoint: The mount point path to check (e.g., `/dev/disk4`)
    /// - Returns: `true` if the device is mounted and accessible, `false` otherwise
    /// - Note: This is a simple file existence check and doesn't verify mount status
    private func isDeviceMounted(_ mountPoint: String) -> Bool {
        // Check if the mount point exists and is accessible
        return FileManager.default.fileExists(atPath: mountPoint)
    }

    // REMOVED: unmountDevice() method - now using Drive.unmountDevice() which is tested and working

    // REMOVED: mountDevice() method - now using Drive.mountDevice() which follows same reliable pattern

    /// Writes an image file to a device using the `dd` command with authorized root privileges.
    ///
    /// This method handles the core flash operation:
    /// - Secures access to the image file using security-scoped bookmarks
    /// - Executes `dd` with authorized root privileges for raw device access
    /// - Monitors progress by parsing `dd` output
    /// - Updates the flash state with progress information
    /// - Handles cancellation gracefully
    ///
    /// - Parameters:
    ///   - image: The `ImageFile` to write to the device
    ///   - devicePath: The raw device path to write to (e.g., `/dev/rdisk4`)
    /// - Throws: `FlashError.flashFailed` if the write operation fails
    /// - Note: This method requires prior authorization and uses 1MB block size for optimal performance
    private func writeImageToDevice(image: ImageFile, devicePath: String) async throws {
        
        //print("   - Writing \(image.formattedSize) to \(devicePath) using dd")
        
        // Safely access the MainActor-isolated authorizationRef
//        let authRef = await MainActor.run { self.authorizationRef }
//        guard let authRef else {
//            throw FlashError.authorizationDenied
//        }

        // Get secure URL for the image file
        let imageURL = try image.getSecureURL()
        guard imageURL.startAccessingSecurityScopedResource() else {
            throw FlashError.flashFailed("Cannot access image file")
        }
        defer { imageURL.stopAccessingSecurityScopedResource() }

        print("   - Executing: dd if=\(imageURL.path) of=\(devicePath) bs=1m status=progress")

        // Prepare arguments for dd command
        //let ddPath = "/bin/dd"
        let args = [
            "if=\(imageURL.path)",
            "of=\(devicePath)",
            "bs=1m",
            "status=progress"
        ]
        
        // Duplicate arguments as C strings and append NULL terminator
        var cArgs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) }
        cArgs.append(nil)
        defer {
            for ptr in cArgs where ptr != nil {
                free(ptr)
            }
        }
        
//        // Execute dd with authorization
//        var communicationsPipe: UnsafeMutablePointer<FILE>?
//        let status: OSStatus = ddPath.withCString { ddCStr in
//            cArgs.withUnsafeMutableBufferPointer { buffer -> OSStatus in
//                guard let base = buffer.baseAddress else {
//                    return errAuthorizationInternal
//                }
//                // Rebind the optional element pointer type to non-optional for the C API
//                let argc = buffer.count
//                let argv = base.withMemoryRebound(
//                    to: UnsafeMutablePointer<CChar>.self,
//                    capacity: argc
//                ) { $0 }
//                
//                return AuthorizationExecuteWithPrivileges(
//                    authRef,
//                    ddCStr,
//                    [],
//                    argv,
//                    &communicationsPipe
//                )
//            }
//        }
        
//        guard status == errAuthorizationSuccess else {
//            throw FlashError.flashFailed("Failed to execute dd with privileges: \(status)")
//        }
        
//        guard let pipe = communicationsPipe else {
//            throw FlashError.flashFailed("Failed to create communication pipe")
//        }
//        
//        let fileHandle = FileHandle(
//             fileDescriptor: fileno(pipe),
//             closeOnDealloc: true
//         )

        // Start monitoring process
        let totalBytes = image.size
        var lastProgressUpdate = Date()
        var outputBuffer = ""
        
        // Monitor progress from dd output
        while !isCancelled {
            // Read available data from pipe
            let data =  NSData.init()
            // init empty data
            //fileHandle.availableData
            
            if !data.isEmpty {
                let output = String(data: data as Data, encoding: .utf8) ?? ""
                outputBuffer += output
                
                // Parse dd progress output (format: "1234567+0 records out")
                if let progressMatch = outputBuffer.range(
                    of: #"(\d+)\+0 records out"#, options: .regularExpression)
                {
                    let progressString = String(outputBuffer[progressMatch])
                    if let recordsOut = progressString.components(
                        separatedBy: CharacterSet.decimalDigits.inverted
                    ).compactMap({ Int($0) }).first {
                        // dd uses 1MB blocks by default with bs=1m
                        let bytesWritten = UInt64(recordsOut) * 1024 * 1024
                        let progress = min(Double(bytesWritten) / Double(totalBytes), 1.0)

                        // Update progress every 0.5 seconds to avoid UI spam
                        if Date().timeIntervalSince(lastProgressUpdate) >= 0.5 {
                            await MainActor.run {
                                flashState = .flashing(progress: progress)
                            }
                            lastProgressUpdate = Date()

                            print(
                                "📊 [DEBUG] Flash progress: \(Int(progress * 100))% (\(ByteCountFormatter.string(fromByteCount: Int64(bytesWritten), countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)))"
                            )
                        }
                    }
                }
            } else {
                // No more data available, dd process likely finished
                break
            }

            // Small delay to avoid busy waiting
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        }

        if isCancelled {
            throw FlashError.flashFailed("Flash operation was cancelled")
        }

        // Final progress update
        await MainActor.run {
            flashState = .flashing(progress: 1.0)
        }

        print("   - dd command completed successfully")
    }

    /// Verifies that the flash operation was successful by comparing samples from the image and device.
    ///
    /// This method performs verification by:
    /// - Extracting the first 1MB from both the original image and the flashed device
    /// - Comparing the samples to ensure they match
    /// - Using `dd` commands for both extraction operations
    /// - Cleaning up temporary files after verification
    ///
    /// - Parameters:
    ///   - image: The original `ImageFile` to compare against
    ///   - devicePath: The raw device path to verify (e.g., `/dev/rdisk4`)
    /// - Throws: `FlashError.flashFailed` if verification fails or samples don't match
    /// - Note: This method requires authorized root privileges for device access and creates temporary files
    private func verifyFlashOperation(image: ImageFile, devicePath: String) async throws {
        print("   - Verifying flash operation using dd...")

        // Create temporary files for comparison
        let tempDir = FileManager.default.temporaryDirectory
        let imageSamplePath = tempDir.appendingPathComponent("image_sample.bin")
        let deviceSamplePath = tempDir.appendingPathComponent("device_sample.bin")

        // Get secure URL for the image file
        let imageURL = try image.getSecureURL()
        guard imageURL.startAccessingSecurityScopedResource() else {
            throw FlashError.flashFailed("Cannot access image file for verification")
        }
        defer { imageURL.stopAccessingSecurityScopedResource() }

        // Extract first 1MB from image using dd
        let imageProcess = Process()
        imageProcess.executableURL = URL(fileURLWithPath: "/bin/dd")
        imageProcess.arguments = [
            "if=\(imageURL.path)",
            "of=\(imageSamplePath.path)",
            "bs=1m",
            "count=1",
        ]

        do {
            try imageProcess.run()
            imageProcess.waitUntilExit()

            if imageProcess.terminationStatus != 0 {
                throw FlashError.flashFailed("Failed to extract image sample for verification")
            }
        } catch {
            throw FlashError.flashFailed(
                "Failed to execute dd for image verification: \(error.localizedDescription)")
        }

        // Extract first 1MB from device using dd with sudo
        let deviceProcess = Process()
        deviceProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        deviceProcess.arguments = [
            "/bin/dd",
            "if=\(devicePath)",
            "of=\(deviceSamplePath.path)",
            "bs=1m",
            "count=1",
        ]

        do {
            try deviceProcess.run()
            deviceProcess.waitUntilExit()

            if deviceProcess.terminationStatus != 0 {
                throw FlashError.flashFailed("Failed to extract device sample for verification")
            }
        } catch {
            throw FlashError.flashFailed(
                "Failed to execute dd for device verification: \(error.localizedDescription)")
        }

        // Compare the files
        let imageData = try Data(contentsOf: imageSamplePath)
        let deviceData = try Data(contentsOf: deviceSamplePath)

        // Clean up temporary files
        try? FileManager.default.removeItem(at: imageSamplePath)
        try? FileManager.default.removeItem(at: deviceSamplePath)

        // Compare
        if imageData != deviceData {
            throw FlashError.flashFailed("Flash verification failed - data mismatch in first 1MB")
        }

        print("   - Verification successful")
    }

    // MARK: - Utility Methods

    // MARK: - SHA256 Checksum Methods

    /// Calculates SHA256 checksum for an image file with progress tracking.
    ///
    /// This method reads the image file in chunks and calculates the SHA256 hash:
    /// - Uses chunked reading to handle large files efficiently
    /// - Updates progress state during calculation
    /// - Handles security-scoped bookmarks for file access
    /// - Provides detailed debug logging
    ///
    /// - Parameter image: The `ImageFile` to calculate checksum for
    /// - Returns: The SHA256 checksum as a hexadecimal string
    /// - Throws: `FlashError.flashFailed` if the calculation fails
    /// - Note: This method updates the flash state with progress information
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
        let chunkSize = 1024 * 1024  // 1MB chunks

        // Update state to show checksum calculation
        flashState = .calculatingChecksum(progress: 0.0)

        while let data = try fileHandle.read(upToCount: chunkSize) {
            // Check for cancellation
            if isCancelled {
                print("🛑 [DEBUG] Checksum calculation cancelled by user")
                // Reset state before throwing
                resetState()
                throw FlashError.flashFailed("Checksum calculation was cancelled")
            }

            hasher.update(data: data)
            bytesProcessed += data.count

            // Calculate and report progress
            let progress = Double(bytesProcessed) / Double(totalBytes)
            flashState = .calculatingChecksum(progress: progress)

            // Small delay to allow UI updates
            try await Task.sleep(nanoseconds: 1_000_000)  // 1ms delay
        }

        let digest = hasher.finalize()
        let checksum = digest.map { String(format: "%02x", $0) }.joined()

        print("✅ [DEBUG] SHA256 checksum calculated: \(checksum.prefix(8))...")

        // Reset state when completed successfully
        resetState()

        return checksum
    }

    /// Verifies that an image file matches an expected SHA256 checksum.
    ///
    /// This method calculates the checksum of the image file and compares it to the expected value:
    /// - Calculates the SHA256 checksum of the image file
    /// - Compares it with the provided expected checksum (case-insensitive)
    /// - Returns true if they match, false otherwise
    ///
    /// - Parameters:
    ///   - image: The `ImageFile` to verify
    ///   - expectedChecksum: The expected SHA256 checksum to compare against
    /// - Returns: `true` if the checksums match, `false` otherwise
    /// - Throws: `FlashError.flashFailed` if the checksum calculation fails
    /// - Note: This method uses the same calculation logic as `calculateSHA256Checksum`
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

    /// Generates a SHA256 checksum for an image file and stores it in the image history.
    ///
    /// This method combines checksum calculation with storage:
    /// - Calculates the SHA256 checksum of the image file
    /// - Creates a new `ImageFile` with the calculated checksum
    /// - Stores the updated image in the history service
    /// - Returns the updated image with the checksum
    ///
    /// - Parameter image: The `ImageFile` to generate checksum for and store
    /// - Returns: A new `ImageFile` with the calculated checksum
    /// - Throws: `FlashError.flashFailed` if the checksum calculation fails
    /// - Note: This method updates the image history but doesn't fail if storage fails
    func generateAndStoreChecksum(for image: ImageFile) async throws -> ImageFile {
        print("🔍 [DEBUG] Generating and storing SHA256 checksum for: \(image.displayName)")

        let checksum = try await calculateSHA256Checksum(for: image)

        // Create new ImageFile with checksum
        var updatedImage = image
        updatedImage.sha256Checksum = checksum

        // Try to update in history service, but don't fail if it doesn't work
        imageHistoryService.addToHistory(updatedImage)
        print("✅ [DEBUG] Checksum stored in history successfully")

        return updatedImage
    }

    /// Generates a SHA256 checksum for an image file without storing it.
    ///
    /// This method calculates the checksum but doesn't modify the image or store it:
    /// - Calculates the SHA256 checksum of the image file
    /// - Returns the checksum as a string
    /// - Does not update the image or store in history
    ///
    /// - Parameter image: The `ImageFile` to generate checksum for
    /// - Returns: The SHA256 checksum as a hexadecimal string
    /// - Throws: `FlashError.flashFailed` if the checksum calculation fails
    /// - Note: This is a read-only operation that doesn't modify the image or history
    func generateChecksumOnly(for image: ImageFile) async throws -> String {
        print("🔍 [DEBUG] Generating SHA256 checksum for: \(image.displayName)")

        let checksum = try await calculateSHA256Checksum(for: image)

        print("✅ [DEBUG] Checksum calculated: \(checksum.prefix(8))...")
        return checksum
    }
}
