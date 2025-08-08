//
//  DriveModel.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation

// MARK: - CRITICAL DATA MODEL (DO NOT MODIFY - Core data structure)
// This Drive model is used throughout the application and changes here
// will affect device detection, UI display, and data persistence.
// Any modifications require thorough testing of all dependent components.
struct Drive: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let mountPoint: String
    let size: Int64
    let isRemovable: Bool
    let isSystemDrive: Bool
    let isReadOnly: Bool
    let mediaUUID: String? // Added for inventory tracking
    let mediaName: String? // Specific DAMediaName from Disk Arbitration
    let vendor: String? // DADeviceVendor from Disk Arbitration
    let revision: String? // DADeviceRevision from Disk Arbitration
    var deviceType: DeviceType = .unknown // Device type for display and settings
    var partitionScheme: ImageFileService.PartitionScheme = .unknown // Cached partition scheme
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var displayName: String {
        if name.isEmpty {
            return "Unknown Drive"
        }
        return name
    }
    
    /// Formatted partition scheme display string
    var partitionSchemeDisplay: String {
        switch partitionScheme {
        case .mbr:
            return "MBR (Master Boot Record)"
        case .gpt:
            return "GPT (GUID Partition Table)"
        case .unknown:
            return "Unknown"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(mountPoint)
    }
    
    static func == (lhs: Drive, rhs: Drive) -> Bool {
        return lhs.mountPoint == rhs.mountPoint
    }
    
    /// Unmount the device using diskutil unmountDisk command with timeout protection
    /// - Returns: Bool indicating success (true) or failure (false)
    /// - Note: This method includes timeout protection and detailed logging
    @discardableResult
    func unmountDevice() -> Bool {
        print("🔄 [DEBUG] Starting unmount for: \(mountPoint)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["unmountDisk", mountPoint]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            print("🚀 [DEBUG] Launching diskutil unmountDisk \(mountPoint)")
            try task.run()

            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading

            outputHandle.readabilityHandler = { handle in
                if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                    print("📤 [diskutil stdout]: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }

            errorHandle.readabilityHandler = { handle in
                if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                    print("🛑 [diskutil stderr]: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }

            let timeoutSeconds: TimeInterval = 10.0
            let deadline = Date().addingTimeInterval(timeoutSeconds)

            while task.isRunning && Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
            }

            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil

            if task.isRunning {
                print("⏰ [DEBUG] Timeout reached, terminating process")
                task.terminate()
                usleep(100_000)
                return false
            }

            print("🏁 [DEBUG] Exit code: \(task.terminationStatus)")
            return task.terminationStatus == 0
        } catch {
            print("❌ [DEBUG] Failed to run diskutil unmount: \(error)")
            return false
        }
    }
    
    /// Mount the device using diskutil mount command with timeout protection
    /// - Returns: Bool indicating success (true) or failure (false)
    /// - Note: Uses same reliable pattern as unmountDevice() with timeout protection
    @discardableResult
    func mountDevice() -> Bool {
        print("🔄 [DEBUG] Starting mount for: \(mountPoint)")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["mount", mountPoint]

        // Don't use pipes - they can cause blocking
        task.standardOutput = nil
        task.standardError = nil

        do {
            print("🚀 [DEBUG] Launching diskutil mount \(mountPoint)")
            try task.run()
            
            // Create a timeout mechanism
            let timeoutSeconds: TimeInterval = 10.0
            let startTime = Date()
            
            // Check if process is still running with timeout
            var lastOutputCheck = Date()
            let outputCheckInterval: TimeInterval = 0.5 // Check output every 0.5 seconds
            
            while task.isRunning {
                if Date().timeIntervalSince(startTime) > timeoutSeconds {
                    print("⏰ [DEBUG] Timeout reached (\(timeoutSeconds)s), terminating process")
                    task.terminate()
                    
                    // Give it a moment to clean up
                    usleep(100000) // 0.1 seconds
                    
                    if task.isRunning {
                        print("🔪 [DEBUG] Process still running after terminate, waiting...")
                        // Process.kill() doesn't exist in Swift, terminate() should be sufficient
                    }
                    
                    print("❌ [DEBUG] mountDevice timed out for \(mountPoint)")
                    return false
                }
                
                // Show progress indicator periodically
                let now = Date()
                if now.timeIntervalSince(lastOutputCheck) >= outputCheckInterval {
                    let elapsed = now.timeIntervalSince(startTime)
                    print("⏳ [DEBUG] Process running for \(String(format: "%.1f", elapsed))s...")
                    lastOutputCheck = now
                }
                
                // Small sleep to prevent busy waiting
                usleep(50000) // 0.05 seconds
            }
            
            print("✅ [DEBUG] Process completed")
            print("🏁 [DEBUG] Exit code: \(task.terminationStatus)")

            return task.terminationStatus == 0
        } catch {
            print("❌ [DEBUG] Failed to run diskutil mount: \(error)")
            return false
        }
    }
}
// END: CRITICAL DATA MODEL 
