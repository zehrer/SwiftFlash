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
    
    // MARK: - DeviceInfo derived logic

    func testDeviceInfoDiskImageDetection() throws {
        let diskImage = createMockDiskImage()
        XCTAssertTrue(diskImage.isDiskImage)

        let realDevice = createMockRealDevice()
        XCTAssertFalse(realDevice.isDiskImage)

        let unknown = DeviceInfo(
            name: "Unknown Device",
            devicePath: "/dev/disk777",
            size: 0,
            isRemovable: false,
            isEjectable: false,
            isReadOnly: false,
            mediaUUID: nil,
            mediaName: nil,
            vendor: nil,
            revision: nil
        )
        XCTAssertFalse(unknown.isDiskImage)
    }

    func testDeviceInfoMainDeviceDetection() throws {
        let main = DeviceInfo(name: "disk3", devicePath: "/dev/disk3", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil)
        XCTAssertTrue(main.isMainDevice)

        let partition = DeviceInfo(name: "disk3s1", devicePath: "/dev/disk3s1", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil)
        XCTAssertFalse(partition.isMainDevice)

        let nested = DeviceInfo(name: "disk3s1s1", devicePath: "/dev/disk3s1s1", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil)
        XCTAssertFalse(nested.isMainDevice)
    }

    func testDeviceInfoInferredDeviceType() throws {
        XCTAssertEqual(DeviceInfo(name: "microSD Adapter", devicePath: "/dev/disk1", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil).inferredDeviceType, .microSDCard)
        XCTAssertEqual(DeviceInfo(name: "SD Transcend", devicePath: "/dev/disk2", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil).inferredDeviceType, .sdCard)
        XCTAssertEqual(DeviceInfo(name: "Udisk Mass Storage", devicePath: "/dev/disk3", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil).inferredDeviceType, .usbStick)
        XCTAssertEqual(DeviceInfo(name: "Portable SSD", devicePath: "/dev/disk4", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil).inferredDeviceType, .externalSSD)
        XCTAssertEqual(DeviceInfo(name: "External Drive", devicePath: "/dev/disk5", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil).inferredDeviceType, .externalHDD)
        XCTAssertEqual(DeviceInfo(name: "Unknown Gadget", devicePath: "/dev/disk6", size: 0, isRemovable: true, isEjectable: true, isReadOnly: false, mediaUUID: nil, mediaName: nil, vendor: nil, revision: nil).inferredDeviceType, .unknown)
    }
    
    // MARK: - Real device filtering (hardware dependent)

    func testDetectDrivesExcludesDiskImages() async throws {
        // Opt-in only: avoid blocking CI/local runs by default
        guard ProcessInfo.processInfo.environment["SWIFTFLASH_HW_TESTS"] == "1" else {
            throw XCTSkip("Hardware-dependent tests are disabled. Set SWIFTFLASH_HW_TESTS=1 to enable.")
        }
        driveDetectionService = DriveDetectionService()
        guard let service = driveDetectionService else {
            XCTFail("DriveDetectionService could not be created")
            return
        }
        let drives = await service.detectDrives()
        if drives.isEmpty {
            throw XCTSkip("No external drives detected on this machine – skipping hardware-dependent assertion")
        }
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
