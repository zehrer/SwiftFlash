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
        let mountedVolumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeTotalCapacityKey], options: [])
        
        for volumeURL in mountedVolumes ?? [] {
            guard let volumeName = try? volumeURL.resourceValues(forKeys: [.volumeNameKey]).volumeName,
                  let totalCapacity = try? volumeURL.resourceValues(forKeys: [.volumeTotalCapacityKey]).volumeTotalCapacity else {
                continue
            }
            
            let mountPoint = volumeURL.path
            let isRemovable = isRemovableDrive(at: mountPoint)
            let isSystemDrive = isSystemDrive(at: mountPoint)
            
            // Only include removable drives that are not system drives
            if isRemovable && !isSystemDrive {
                let drive = Drive(
                    name: volumeName,
                    mountPoint: mountPoint,
                    size: Int64(totalCapacity),
                    isRemovable: isRemovable,
                    isSystemDrive: isSystemDrive
                )
                drives.append(drive)
            }
        }
        
        return drives
    }
    
    private func isRemovableDrive(at mountPoint: String) -> Bool {
        // More robust check for removable drives
        
        // Skip system volumes and network drives
        if mountPoint.hasPrefix("/System") || 
           mountPoint.hasPrefix("/Volumes/Data") ||
           mountPoint.hasPrefix("/private/var") ||
           mountPoint.hasPrefix("/tmp") {
            return false
        }
        
        // Check if it's a mounted volume that's not the root filesystem
        if mountPoint.hasPrefix("/Volumes/") && mountPoint != "/" {
            // Additional check: try to get volume properties
            let volumeURL = URL(fileURLWithPath: mountPoint)
            if let resourceValues = try? volumeURL.resourceValues(forKeys: [.volumeIsRemovableKey]),
               let isRemovable = resourceValues.volumeIsRemovable {
                return isRemovable
            }
            
            // Fallback: if we can't determine, assume it's removable if it's in /Volumes/
            return true
        }
        
        return false
    }
    
    private func isSystemDrive(at mountPoint: String) -> Bool {
        // Check if this is the system drive
        let systemDrive = "/System/Volumes/Data"
        let rootDrive = "/"
        
        // Check for system-related paths
        if mountPoint == systemDrive || 
           mountPoint == rootDrive || 
           mountPoint.hasPrefix("/System") ||
           mountPoint.hasPrefix("/private/var") ||
           mountPoint.hasPrefix("/tmp") ||
           mountPoint.hasPrefix("/usr") ||
           mountPoint.hasPrefix("/bin") ||
           mountPoint.hasPrefix("/sbin") {
            return true
        }
        
        // Check if it's the boot volume
        if let bootVolume = ProcessInfo.processInfo.environment["BOOT_VOLUME"] {
            return mountPoint.hasPrefix(bootVolume)
        }
        
        return false
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