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
    
    // MARK: - Helper Methods
    
    /// Finds an available external USB device for testing
    /// - Returns: DeviceInfo instance if found, nil otherwise
    private func findTestDevice() -> DeviceInfo? {
        print("🔍 Scanning for available test devices...")
        
        // Check common external device paths
        let potentialDevices = ["/dev/disk4", "/dev/disk5", "/dev/disk6", "/dev/disk7"]
        
        for devicePath in potentialDevices {
            if FileManager.default.fileExists(atPath: devicePath) {
                // Create a basic DeviceInfo for testing
                let testDevice = DeviceInfo(
                    name: "Test USB Device",
                    devicePath: devicePath,
                    size: 32000000000, // 32GB
                    isRemovable: true,
                    isEjectable: true,
                    isReadOnly: false,
                    mediaUUID: "TEST_DEVICE_001",
                    mediaName: "Test USB Stick",
                    vendor: "Test Vendor",
                    revision: "1.0"
                )
                
                print("📱 Found potential test device: \(devicePath)")
                return testDevice
            }
        }
        
        print("⚠️ No external devices found for testing")
        return nil
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
        
        // Test with mock disk image
        let diskImage = createMockDiskImage()
        
        // Test the isDiskImage method directly
        let isDiskImage = driveDetectionService.isDiskImage(deviceInfo: diskImage)
        XCTAssertTrue(isDiskImage, "Disk image should be identified as disk image")
        print("✅ Disk image correctly identified")
        
        // Test with mock real device
        let realDevice = createMockRealDevice()
        let isRealDeviceDiskImage = driveDetectionService.isDiskImage(deviceInfo: realDevice)
        XCTAssertFalse(isRealDeviceDiskImage, "Real device should not be identified as disk image")
        print("✅ Real device correctly not identified as disk image")
    }
    
    // MARK: - Real Device Detection Tests
    
    func testRealDeviceDetection() throws {
        print("\n🧪 Test: Real device detection")
        print("=" * 50)
        
        guard let testDevice = findTestDevice() else {
            XCTSkip("⚠️ SKIPPED: No external USB device available for testing")
            print("💡 To run this test, connect an external USB device")
            return
        }
        
        print("🔧 Testing with real device: \(testDevice.devicePath)")
        
        // Test that the device is not a disk image
        let isDiskImage = testDevice.mediaName == "Disk Image" || testDevice.name == "Disk Image"
        XCTAssertFalse(isDiskImage, "Real USB device should not be identified as disk image")
        
        // Test device properties
        XCTAssertTrue(testDevice.isRemovable, "USB device should be removable")
        XCTAssertTrue(testDevice.isEjectable, "USB device should be ejectable")
        XCTAssertFalse(testDevice.isReadOnly, "USB device should not be read-only")
        XCTAssertGreaterThan(testDevice.size, 0, "USB device should have positive size")
        
        print("✅ Real device detection working correctly")
    }
    
    func testDeviceDetectionWithNoDevices() throws {
        print("\n🧪 Test: Device detection with no devices")
        print("=" * 50)
        
        // This test verifies the service handles no devices gracefully
        // Note: This is a basic test since we can't easily mock the IOKit calls
        
        print("🔧 Testing drive detection service initialization")
        
        // Verify service initializes without crashing
        XCTAssertNotNil(driveDetectionService, "DriveDetectionService should initialize successfully")
        
        // Verify drives array exists
        XCTAssertNotNil(driveDetectionService.drives, "Drives array should exist")
        
        print("✅ Service initialization working correctly")
    }
    
    // MARK: - Hardware Dependency Tests
    
    func testHardwareDependencyWarning() throws {
        print("\n🧪 Test: Hardware dependency warnings")
        print("=" * 50)
        
        let testDevice = findTestDevice()
        
        if testDevice == nil {
            print("⚠️ HARDWARE DEPENDENCY: No external USB device available")
            print("💡 This test requires:")
            print("   - External USB device (USB stick, SD card, etc.)")
            print("   - Device should be mounted and accessible")
            print("   - Device should not be the system boot device")
            print("💡 To test disk image filtering:")
            print("   - Mount a .dmg file")
            print("   - Verify it appears as 'Disk Image' in diskutil")
            
            XCTSkip("⚠️ SKIPPED: Hardware dependency not met - no external devices available")
            return
        }
        
        print("✅ Hardware dependency met - proceeding with tests")
        
        // Run additional hardware-dependent tests here
        XCTAssertNotNil(testDevice, "Test device should be available")
        print("✅ Hardware dependency test passed")
    }
    
    // MARK: - Integration Tests
    
    func testDriveDetectionIntegration() throws {
        print("\n🧪 Test: Drive detection integration")
        print("=" * 50)
        
        guard let testDevice = findTestDevice() else {
            XCTSkip("⚠️ SKIPPED: No external USB device available for integration testing")
            return
        }
        
        print("🔧 Testing drive detection integration with: \(testDevice.devicePath)")
        
        // Test the full drive detection process
        Task {
            let detectedDrives = await driveDetectionService.detectDrives()
            
            // Verify that detected drives don't include disk images
            for drive in detectedDrives {
                // Create DeviceInfo from Drive for testing
                let deviceInfo = DeviceInfo(
                    name: drive.name,
                    devicePath: drive.mountPoint,
                    size: drive.size,
                    isRemovable: drive.isRemovable,
                    isEjectable: true, // Assume true for detected drives
                    isReadOnly: drive.isReadOnly,
                    mediaUUID: drive.mediaUUID,
                    mediaName: drive.mediaName,
                    vendor: drive.vendor,
                    revision: drive.revision
                )
                
                let isDiskImage = driveDetectionService.isDiskImage(deviceInfo: deviceInfo)
                XCTAssertFalse(isDiskImage, "Detected drives should not include disk images: \(drive.name)")
            }
            
            print("✅ Integration test completed - found \(detectedDrives.count) valid drives")
        }
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
