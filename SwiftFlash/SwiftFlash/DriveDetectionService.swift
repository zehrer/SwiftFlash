//
//  DriveDetectionService.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation
import Combine

@MainActor
class DriveDetectionService: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var isScanning = false
    
    private var mountedVolumes: Set<String> = []
    
    init() {
        refreshDrives()
    }
    
    deinit {
        // Cleanup will be added when DiskArbitration is re-enabled
    }
    
    private func setupDiskArbitration() {
        // Temporarily disabled for compilation
        // session = DASessionCreate(kCFAllocatorDefault)
        // guard let session = session else { return }
        // 
        // DASessionSetDispatchQueue(session, DispatchQueue.main)
        // DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue as CFString)
        // 
        // // Register callbacks for disk appearance and disappearance
        // DARegisterDiskAppearedCallback(session, nil, diskAppearedCallback, Unmanaged.passUnretained(self).toOpaque())
        // DARegisterDiskDisappearedCallback(session, nil, diskDisappearedCallback, Unmanaged.passUnretained(self).toOpaque())
    }
    
    func refreshDrives() {
        isScanning = true
        
        Task {
            let detectedDrives = await detectDrives()
            self.drives = detectedDrives
            self.isScanning = false
        }
    }
    
    private func detectDrives() async -> [Drive] {
        var drives: [Drive] = []
        
        // Get mounted volumes
        let fileManager = FileManager.default
        let mountedVolumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeNameKey, 
            .volumeTotalCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsLocalKey,
            .volumeIsReadOnlyKey
        ], options: [])
        
        for volumeURL in mountedVolumes ?? [] {
            guard let resourceValues = try? volumeURL.resourceValues(forKeys: [
                .volumeNameKey, 
                .volumeTotalCapacityKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeIsLocalKey,
                .volumeIsReadOnlyKey
            ]),
            let volumeName = resourceValues.volumeName,
            let totalCapacity = resourceValues.volumeTotalCapacity else {
                continue
            }
            
            let mountPoint = volumeURL.path
            
            // Check if this is a valid USB drive
            guard isUSBDrive(resourceValues: resourceValues, mountPoint: mountPoint) else {
                continue
            }
            
            let drive = Drive(
                name: volumeName,
                mountPoint: mountPoint,
                size: Int64(totalCapacity),
                isRemovable: true,
                isSystemDrive: false
            )
            drives.append(drive)
        }
        
        return drives
    }
    
    private func isUSBDrive(resourceValues: URLResourceValues, mountPoint: String) -> Bool {
        // Must be removable and ejectable (typical USB drive characteristics)
        guard let isRemovable = resourceValues.volumeIsRemovable,
              let isEjectable = resourceValues.volumeIsEjectable,
              let isLocal = resourceValues.volumeIsLocal,
              let isReadOnly = resourceValues.volumeIsReadOnly else {
            return false
        }
        
        // Must be removable, ejectable, and local (not network)
        guard isRemovable && isEjectable && isLocal else {
            return false
        }
        
        // Must be writable (not read-only)
        guard !isReadOnly else {
            return false
        }
        
        // Skip system volumes and known non-USB paths
        if mountPoint.hasPrefix("/System") || 
           mountPoint.hasPrefix("/Volumes/Data") ||
           mountPoint.hasPrefix("/private/var") ||
           mountPoint.hasPrefix("/tmp") ||
           mountPoint.hasPrefix("/usr") ||
           mountPoint.hasPrefix("/bin") ||
           mountPoint.hasPrefix("/sbin") ||
           mountPoint == "/" {
            return false
        }
        
        // Must be in /Volumes/ (standard mount point for external drives)
        guard mountPoint.hasPrefix("/Volumes/") else {
            return false
        }
        
        // Additional check: try to get the device path to verify it's a physical USB device
        if let devicePath = getDevicePath(for: mountPoint) {
            // Check if it's a USB device (typically starts with /dev/disk)
            return devicePath.hasPrefix("/dev/disk") && !devicePath.contains("virtual")
        }
        
        // If we can't determine the device path, rely on the volume properties
        return true
    }
    
    private func getDevicePath(for mountPoint: String) -> String? {
        // Use diskutil to get the device path for a mount point
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", mountPoint]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for the device identifier
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("Device Identifier:") {
                        let parts = line.components(separatedBy: ":")
                        if parts.count > 1 {
                            let deviceId = parts[1].trimmingCharacters(in: .whitespaces)
                            return "/dev/\(deviceId)"
                        }
                    }
                }
            }
        } catch {
            // If diskutil fails, we'll fall back to the volume properties
            return nil
        }
        
        return nil
    }
}

// MARK: - Disk Arbitration Callbacks (temporarily disabled)

// private func diskAppearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
//     guard let context = context else { return }
//     let service = Unmanaged<DriveDetectionService>.fromOpaque(context).takeUnretainedValue()
//     Task { @MainActor in
//         service.refreshDrives()
//     }
// }
// 
// private func diskDisappearedCallback(disk: DADisk, context: UnsafeMutableRawPointer?) {
//     guard let context = context else { return }
//     let service = Unmanaged<DriveDetectionService>.fromOpaque(context).takeUnretainedValue()
//     Task { @MainActor in
//         service.refreshDrives()
//     }
// } 