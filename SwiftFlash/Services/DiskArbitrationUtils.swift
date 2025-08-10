//
//  DiskArbitrationUtils.swift
//  SwiftFlash
//
//  Shared utilities for Disk Arbitration operations that can be used
//  across different parts of the application (DriveDetectionService, DriveModel, etc.)
//

import Foundation
import DiskArbitration

/// Shared Disk Arbitration utilities for device description access
struct DiskArbitrationUtils {
    
    /// Converts a device path to BSD name format
    /// - Parameter devicePath: Absolute device path such as "/dev/disk4"
    /// - Returns: BSD name suitable for Disk Arbitration APIs (e.g. "disk4")
    static func toBSDName(_ devicePath: String) -> String {
        return devicePath.replacingOccurrences(of: "/dev/", with: "")
    }
    
    /// Gets Disk Arbitration description dictionary for a given device path
    /// - Parameters:
    ///   - devicePath: Absolute device path (e.g. "/dev/disk4")
    ///   - session: Disk Arbitration session (optional, will create temporary one if nil)
    /// - Returns: Dictionary of description keys or `nil` if unavailable
    static func getDiskDescription(for devicePath: String, session: DASession? = nil) -> [String: Any]? {
        let bsdName = toBSDName(devicePath)
        
        // Use provided session or create a temporary one
        let daSession: DASession
        let shouldReleaseSession: Bool
        
        if let session = session {
            daSession = session
            shouldReleaseSession = false
        } else {
            guard let tempSession = DASessionCreate(kCFAllocatorDefault) else {
                return nil
            }
            daSession = tempSession
            shouldReleaseSession = true
        }
        
        defer {
            if shouldReleaseSession {
                // Note: DASession is a CF type, but we don't need to release it
                // as it's managed by the framework
            }
        }
        
        guard let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, daSession, bsdName) else {
            return nil
        }
        
        guard let description = DADiskCopyDescription(disk) as? [String: Any] else {
            return nil
        }
        
        return description
    }
    
    /// Gets a specific value from Disk Arbitration description
    /// - Parameters:
    ///   - devicePath: Absolute device path (e.g. "/dev/disk4")
    ///   - key: The Disk Arbitration key to retrieve
    ///   - session: Disk Arbitration session (optional)
    /// - Returns: The value for the specified key or `nil` if not found
    static func getValue<T>(for devicePath: String, key: String, session: DASession? = nil) -> T? {
        guard let description = getDiskDescription(for: devicePath, session: session) else {
            return nil
        }
        return description[key] as? T
    }
    
    /// Gets a string value from Disk Arbitration description
    /// - Parameters:
    ///   - devicePath: Absolute device path (e.g. "/dev/disk4")
    ///   - key: The Disk Arbitration key to retrieve
    ///   - session: Disk Arbitration session (optional)
    /// - Returns: The string value for the specified key or `nil` if not found or empty
    static func getStringValue(for devicePath: String, key: String, session: DASession? = nil) -> String? {
        guard let value: String = getValue(for: devicePath, key: key, session: session),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
