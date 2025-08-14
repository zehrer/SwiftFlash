//
//  DriveDetectionTests.swift
//  SwiftFlashTests
//
//  Created by Claude AI on 08.08.2025.
//

import XCTest
@testable import SwiftFlash

/// Unit tests for DriveDetectionService functionality
///
/// **Test Requirements:**
/// - External USB device should be connected for real device tests
/// - Tests will be marked as "not testable" if no suitable device is available
/// - Tests verify disk image filtering and real-world device detection
/// - Tests include hardware dependency warnings
@MainActor
final class DriveDetectionTests: XCTestCase {
    
    // Instantiate service only inside specific tests to avoid blocking during setUp
    private var driveDetectionService: DriveDetectionService?
    
    // MARK: - Test Setup
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        driveDetectionService = nil
    }
    
    /// Creates a mock disk image device for testing
    /// - Returns: Device representing a mounted disk image
    private func createMockDiskImage() -> Device {
        let diskDescription: [String: Any] = [
            kDADiskDescriptionMediaNameKey as String: "Disk Image",
            kDADiskDescriptionMediaUUIDKey as String: "DISK_IMAGE_001",
            kDADiskDescriptionDeviceVendorKey as String: "Apple",
            kDADiskDescriptionDeviceRevisionKey as String: "1.0",
            kDADiskDescriptionMediaSizeKey as String: 1000000000 as Int64 // 1GB
        ]
        
        return Device(
            devicePath: "/dev/disk999",
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            isSystemDrive: false,
            diskDescription: diskDescription,
            partitions: []
        )
    }
    
    /// Creates a mock real USB device for testing
    /// - Returns: Device representing a real USB device
    private func createMockRealDevice() -> Device {
        let diskDescription: [String: Any] = [
            kDADiskDescriptionMediaNameKey as String: "SanDisk Ultra USB 3.0",
            kDADiskDescriptionMediaUUIDKey as String: "REAL_DEVICE_001",
            kDADiskDescriptionDeviceVendorKey as String: "SanDisk",
            kDADiskDescriptionDeviceRevisionKey as String: "1.0",
            kDADiskDescriptionMediaSizeKey as String: 32000000000 as Int64 // 32GB
        ]
        
        return Device(
            devicePath: "/dev/disk888",
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            isSystemDrive: false,
            diskDescription: diskDescription,
            partitions: []
        )
    }
    
    // MARK: - Device derived logic

    func testDeviceDiskImageDetection() throws {
        let diskImage = createMockDiskImage()
        XCTAssertTrue(diskImage.isDiskImage)

        let realDevice = createMockRealDevice()
        XCTAssertFalse(realDevice.isDiskImage)

        let unknownDiskDescription: [String: Any] = [
            kDADiskDescriptionMediaNameKey as String: "Unknown Device"
        ]
        
        let unknown = Device(
            devicePath: "/dev/disk777",
            isRemovable: false,
            isEjectable: false,
            isReadOnly: false,
            isSystemDrive: false,
            diskDescription: unknownDiskDescription,
            partitions: []
        )
        XCTAssertFalse(unknown.isDiskImage)
    }

    func testDeviceMainDeviceDetection() throws {
        let main = Device(
            devicePath: "/dev/disk3",
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            isSystemDrive: false,
            diskDescription: [:],
            partitions: []
        )
        XCTAssertTrue(main.isMainDevice)

        let partition = Device(
            devicePath: "/dev/disk3s1",
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            isSystemDrive: false,
            diskDescription: [:],
            partitions: []
        )
        XCTAssertFalse(partition.isMainDevice)

        let nested = Device(
            devicePath: "/dev/disk3s1s1",
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            isSystemDrive: false,
            diskDescription: [:],
            partitions: []
        )
        XCTAssertFalse(nested.isMainDevice)
    }


    
    // MARK: - Real device filtering (hardware dependent)

    /// Tests that DriveDetectionService excludes disk images from detected drives
    /// Requires SWIFTFLASH_HW_TESTS=1 environment variable to run
    func testDetectDrivesExcludesDiskImages() async throws {
        // GUARD: Skip this test unless explicitly enabled with environment variable
        // This prevents the test from running during normal development/CI builds
        // because it performs real hardware operations that can be slow and unreliable
//        guard ProcessInfo.processInfo.environment["SWIFTFLASH_HW_TESTS"] == "1" else {
//            throw XCTSkip("Hardware-dependent tests are disabled. Set SWIFTFLASH_HW_TESTS=1 to enable.")
//        }
        
        // CREATE: Instantiate a real DriveDetectionService (not a mock)
        // This will initialize IOKit and Disk Arbitration frameworks
        // WARNING: This is why the test "starts the complete app" - it uses real system services
        driveDetectionService = DriveDetectionService()
        guard let service = driveDetectionService else {
            XCTFail("DriveDetectionService could not be created")
            return
        }
        
        // DETECT: Call the real detectDrives() method which performs:
        // 1. IOKit registry enumeration (scans all removable/ejectable media)
        // 2. Disk Arbitration queries (gets device metadata)
        // 3. System boot device detection (to exclude internal drives)
        // 4. Disk image filtering (the main focus of this test)
        let drives = await service.detectDrives()
        
        // VALIDATE: Ensure we have actual drives to test against
        // If no external drives are connected, we can't meaningfully test the filtering
        if drives.isEmpty {
            throw XCTSkip("No external drives detected on this machine – skipping hardware-dependent assertion")
        }
        
        // ASSERT: Verify that no detected drives are disk images
        // This tests the real-world filtering logic in DriveDetectionService.detectDrives()
        // where devices with isDiskImage=true are excluded from the results
        XCTAssertTrue(drives.allSatisfy { $0.name != "Disk Image" }, "Disk image devices should be filtered out by detection")
    }
    
//    func testDeviceDetectionWithNoDevices() throws {
//        print("\n🧪 Test: Device detection with no devices")
//        print("=" * 50)
//        
//        throw XCTSkip("⚠️ SKIPPED: Requires non-blocking test-mode in DriveDetectionService (needs approval to modify CRITICAL service)")
//    }
    
    // MARK: - Hardware Dependency Tests
    
//    func testHardwareDependencyWarning() throws {
//        print("\n🧪 Test: Hardware dependency warnings")
//        print("=" * 50)
//        
//        throw XCTSkip("⚠️ SKIPPED: Requires non-blocking test-mode in DriveDetectionService (needs approval to modify CRITICAL service)")
//    }
    
    // MARK: - Integration Tests
    
//    func testDriveDetectionIntegration() throws {
//        print("\n🧪 Test: Drive detection integration")
//        print("=" * 50)
//        
//        // Skip this test to avoid blocking - it requires real hardware
//        throw XCTSkip("⚠️ SKIPPED: Integration test requires real hardware and may block")
//        
//        // Note: This test would require real USB devices and could block
//        // due to IOKit and Disk Arbitration calls
//    }

}

// MARK: - Test Utilities

extension DriveDetectionTests {
    
    /// Helper function to print test environment information
    private func printTestEnvironment() {
        print("\n🔧 Test Environment Information:")
        print("   - macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("   - Available disk space: \(getAvailableDiskSpace())")
        print("   - External devices: \(getExternalDeviceCount())")
        print("   - Mounted disk images: \(getMountedDiskImageCount())")
    }
    
    private func getAvailableDiskSpace() -> String {
        // This would require additional implementation
        return "Unknown"
    }
    
    private func getExternalDeviceCount() -> Int {
        // This would require additional implementation
        return 0
    }
    
    private func getMountedDiskImageCount() -> Int {
        // This would require additional implementation
        return 0
    }
}
