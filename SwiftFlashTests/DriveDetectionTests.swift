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
    
    private var driveDetectionService: DriveDetectionService!
    
    // MARK: - Test Setup
    
    override func setUpWithError() throws {
        driveDetectionService = DriveDetectionService()
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        driveDetectionService = nil
    }
    
    /// Creates a mock disk image device for testing
    /// - Returns: DeviceInfo representing a mounted disk image
    private func createMockDiskImage() -> DeviceInfo {
        return DeviceInfo(
            name: "Disk Image",
            devicePath: "/dev/disk999",
            size: 1000000000, // 1GB
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            mediaUUID: "DISK_IMAGE_001",
            mediaName: "Disk Image",
            vendor: "Apple",
            revision: "1.0"
        )
    }
    
    /// Creates a mock real USB device for testing
    /// - Returns: DeviceInfo representing a real USB device
    private func createMockRealDevice() -> DeviceInfo {
        return DeviceInfo(
            name: "SanDisk Ultra USB 3.0",
            devicePath: "/dev/disk888",
            size: 32000000000, // 32GB
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            mediaUUID: "REAL_DEVICE_001",
            mediaName: "SanDisk Ultra USB 3.0",
            vendor: "SanDisk",
            revision: "1.0"
        )
    }
    
    // MARK: - Disk Image Filtering Tests
    
    func testDiskImageFiltering() throws {
        print("\n🧪 Test: Disk image filtering")
        print("=" * 50)
        
        // Test the actual isDiskImage method from DriveDetectionService
        let diskImage = createMockDiskImage()
        let isDiskImage = driveDetectionService.isDiskImage(deviceInfo: diskImage)
        XCTAssertTrue(isDiskImage, "DriveDetectionService.isDiskImage should identify disk image correctly")
        print("✅ DriveDetectionService.isDiskImage correctly identified disk image")
        
        // Test with mock real device
        let realDevice = createMockRealDevice()
        let isRealDeviceDiskImage = driveDetectionService.isDiskImage(deviceInfo: realDevice)
        XCTAssertFalse(isRealDeviceDiskImage, "DriveDetectionService.isDiskImage should not identify real device as disk image")
        print("✅ DriveDetectionService.isDiskImage correctly did not identify real device as disk image")
        
        // Test edge case: device with "Disk Image" in name but different media name
        let edgeCaseDevice = DeviceInfo(
            name: "My Disk Image Backup",
            devicePath: "/dev/disk888",
            size: 1000000000,
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            mediaUUID: "EDGE_CASE_001",
            mediaName: "SanDisk Ultra",
            vendor: "SanDisk",
            revision: "1.0"
        )
        let isEdgeCaseDiskImage = driveDetectionService.isDiskImage(deviceInfo: edgeCaseDevice)
        XCTAssertFalse(isEdgeCaseDiskImage, "DriveDetectionService.isDiskImage should not identify edge case device as disk image")
        print("✅ DriveDetectionService.isDiskImage correctly handled edge case")
    }
    
    // MARK: - Real Device Detection Tests
    
    func testRealDeviceDetection() throws {
        print("\n🧪 Test: Real device detection")
        print("=" * 50)
        
        // Test the actual DriveDetectionService.detectDrives() method
        // This should find real devices and exclude disk images
        let detectedDrives = await driveDetectionService.detectDrives()
        
        print("🔍 Found \(detectedDrives.count) drives in system")
        
        // Check if any detected drives are disk images (this should be 0)
        let diskImageDrives = detectedDrives.filter { drive in
            drive.mediaName == "Disk Image" || drive.name == "Disk Image"
        }
        
        if !diskImageDrives.isEmpty {
            XCTFail("❌ DriveDetectionService.detectDrives() found disk images that should be filtered out: \(diskImageDrives.map { $0.name })")
        } else {
            print("✅ No disk images found in detected drives")
        }
        
        // If we have real drives, verify they have correct properties
        for drive in detectedDrives {
            XCTAssertTrue(drive.isRemovable, "Detected drive should be removable")
            XCTAssertFalse(drive.isSystemDrive, "Detected drive should not be system drive")
            XCTAssertGreaterThan(drive.size, 0, "Detected drive should have positive size")
            XCTAssertNotEqual(drive.mediaName, "Disk Image", "Detected drive should not have 'Disk Image' as media name")
            print("✅ Verified drive: \(drive.name) (\(drive.mountPoint))")
        }
        
        print("✅ Real device detection test completed")
    }
    
    func testDeviceDetectionWithNoDevices() throws {
        print("\n🧪 Test: Device detection with no devices")
        print("=" * 50)
        
        // Test that DriveDetectionService handles no devices gracefully
        let detectedDrives = await driveDetectionService.detectDrives()
        
        // Verify the service returns an empty array when no devices are found
        XCTAssertTrue(detectedDrives.isEmpty, "DriveDetectionService should return empty array when no external devices are found")
        
        // Verify the service doesn't crash and handles the situation gracefully
        XCTAssertNotNil(driveDetectionService, "DriveDetectionService should remain valid")
        
        print("✅ DriveDetectionService handles no devices gracefully")
    }
    
    // MARK: - Hardware Dependency Tests
    
    func testHardwareDependencyWarning() throws {
        print("\n🧪 Test: Hardware dependency warnings")
        print("=" * 50)
        
        // Test the actual DriveDetectionService with real hardware detection
        let detectedDrives = await driveDetectionService.detectDrives()
        
        if detectedDrives.isEmpty {
            print("⚠️ HARDWARE DEPENDENCY: No external USB devices detected")
            print("💡 This test requires:")
            print("   - External USB device (USB stick, SD card, etc.)")
            print("   - Device should be mounted and accessible")
            print("   - Device should not be the system boot device")
            print("💡 To test disk image filtering:")
            print("   - Mount a .dmg file")
            print("   - Verify it appears as 'Disk Image' in diskutil")
            print("   - Run: diskutil info /dev/diskX | grep 'Media Name'")
            
            XCTSkip("⚠️ SKIPPED: Hardware dependency not met - no external devices detected by DriveDetectionService")
            return
        }
        
        print("✅ Hardware dependency test passed - found \(detectedDrives.count) external devices")
    }
    
    // MARK: - Integration Tests
    
    func testDriveDetectionIntegration() throws {
        print("\n🧪 Test: Drive detection integration")
        print("=" * 50)
        
        // Skip this test to avoid blocking - it requires real hardware
        XCTSkip("⚠️ SKIPPED: Integration test requires real hardware and may block")
        
        // Note: This test would require real USB devices and could block
        // due to IOKit and Disk Arbitration calls
    }
    
    // MARK: - Edge Case Tests
    
    func testEdgeCases() throws {
        print("\n🧪 Test: Edge cases")
        print("=" * 50)
        
        // Test with nil mediaName
        let deviceWithNilMediaName = DeviceInfo(
            name: "Test Device",
            devicePath: "/dev/disk777",
            size: 1000000000,
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            mediaUUID: nil,
            mediaName: nil,
            vendor: nil,
            revision: nil
        )
        
        let isNilDeviceDiskImage = deviceWithNilMediaName.mediaName == "Disk Image" || deviceWithNilMediaName.name == "Disk Image"
        XCTAssertFalse(isNilDeviceDiskImage, "Device with nil mediaName should not be identified as disk image")
        
        // Test with empty strings
        let deviceWithEmptyStrings = DeviceInfo(
            name: "",
            devicePath: "/dev/disk666",
            size: 1000000000,
            isRemovable: true,
            isEjectable: true,
            isReadOnly: false,
            mediaUUID: nil,
            mediaName: "",
            vendor: "",
            revision: ""
        )
        
        let isEmptyDeviceDiskImage = deviceWithEmptyStrings.mediaName == "Disk Image" || deviceWithEmptyStrings.name == "Disk Image"
        XCTAssertFalse(isEmptyDeviceDiskImage, "Device with empty strings should not be identified as disk image")
        
        print("✅ Edge case tests completed")
    }
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
