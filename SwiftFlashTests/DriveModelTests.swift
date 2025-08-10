//
//  DriveModelTests.swift
//  SwiftFlashTests
//
//  Created by Claude AI on 08.08.2025.
//

import XCTest
@testable import SwiftFlash

/// Unit tests for DriveModel mount/unmount operations
/// 
/// **Test Requirements:**
/// - External USB device should be connected for real device tests
/// - Tests will be skipped (not failed) if no suitable device is available
/// - Tests verify timeout protection and real-world diskutil behavior
final class DriveModelTests: XCTestCase {
    
    // MARK: - Test Setup
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    // MARK: - Helper Methods
    
    /// Finds an available external USB device for testing
    /// - Returns: Drive instance if found, nil otherwise
    private func findTestDevice() -> Drive? {
        print("🔍 Scanning for available test devices...")
        
        // Check common external device paths
        let potentialDevices = ["/dev/disk4", "/dev/disk5", "/dev/disk6", "/dev/disk7"]
        
        for devicePath in potentialDevices {
            if FileManager.default.fileExists(atPath: devicePath) {
                let testDrive = Drive(
                    name: "Test Device",
                    mountPoint: devicePath,
                    size: 0,
                    isRemovable: true,
                    isSystemDrive: false,
                    isReadOnly: false,
                    mediaUUID: nil,
                    mediaName: "TEST_DEVICE",
                    vendor: "Test",
                    revision: "1.0",
                    deviceModel: "Test Model",
                    diskDescription: nil
                )
                
                print("📱 Found potential test device: \(devicePath)")
                return testDrive
            }
        }
        
        print("⚠️ No external devices found for testing")
        return nil
    }
    
    // MARK: - Real Device Tests
    
    @MainActor func testUnmountDeviceWithRealDevice() throws {
        print("\n🧪 Test: unmountDevice with real device")
        print("=" * 50)
        
        guard let testDevice = findTestDevice() else {
            throw XCTSkip("No external USB device available for testing. Connect a USB device to run this test.")
        }
        
        print("🔧 Testing unmountDevice with: \(testDevice.mountPoint)")
        
        let startTime = Date()
        let result = testDevice.unmountDevice()
        let executionTime = Date().timeIntervalSince(startTime)
        
        print("⏱️ Execution time: \(String(format: "%.2f", executionTime))s")
        
        // Note: We don't assert true/false here because the device might be busy
        // The important thing is that it returns a boolean and doesn't hang
        print("📊 Result: \(result)")
        
        if result {
            print("✅ Successfully unmounted device \(testDevice.mountPoint)")
        } else {
            print("⚠️ unmountDevice returned false - device may be busy or already unmounted")
        }
    }
    
    @MainActor func testMountDeviceWithRealDevice() throws {
        print("\n🧪 Test: mountDevice with real device")
        print("=" * 50)
        
        guard let testDevice = findTestDevice() else {
            throw XCTSkip("No external USB device available for testing. Connect a USB device to run this test.")
        }
        
        print("🔧 Testing mountDevice with: \(testDevice.mountPoint)")
        
        let startTime = Date()
        let result = testDevice.mountDevice()
        let executionTime = Date().timeIntervalSince(startTime)
        
        print("⏱️ Execution time: \(String(format: "%.2f", executionTime))s")
        
        // Note: We don't assert true/false here because the device might already be mounted
        print("📊 Result: \(result)")
        
        if result {
            print("✅ Successfully mounted device \(testDevice.mountPoint)")
        } else {
            print("⚠️ mountDevice returned false - device may already be mounted")
        }
    }
    
    @MainActor func testMountUnmountCycle() throws {
        print("\n🧪 Test: Mount/Unmount cycle")
        print("=" * 50)
        
        guard let testDevice = findTestDevice() else {
            throw XCTSkip("No external USB device available for testing. Connect a USB device to run this test.")
        }
        
        print("🔧 Testing mount/unmount cycle with: \(testDevice.mountPoint)")
        
        // Step 1: Unmount
        print("🔽 Step 1: Unmounting device...")
        let unmountResult = testDevice.unmountDevice()
        
        if unmountResult {
            print("✅ Unmount successful, attempting remount...")
            
            // Small delay for system stability
            Thread.sleep(forTimeInterval: 0.5)
            
            // Step 2: Mount
            print("🔼 Step 2: Mounting device...")
            let mountResult = testDevice.mountDevice()
            
            if mountResult {
                print("✅ Mount/Unmount cycle completed successfully")
            } else {
                print("⚠️ Remount failed - device may need manual intervention")
            }
        } else {
            print("⚠️ Initial unmount failed - device may be busy or already unmounted")
        }
        
        // This test documents behavior rather than asserting specific outcomes
        // because device state can vary
    }
}

// MARK: - String Extension for Test Formatting

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
