//
//  DriveModel.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation

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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(mountPoint)
    }
    
    static func == (lhs: Drive, rhs: Drive) -> Bool {
        return lhs.mountPoint == rhs.mountPoint
    }
} 