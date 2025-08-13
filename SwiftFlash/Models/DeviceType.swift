//
//  DeviceType.swift
//  SwiftFlash
//
//  Enum defining the different types of storage devices supported by SwiftFlash.
//  This enum is used throughout the application for device categorization and UI display.
//

import Foundation

/// Represents the type of storage device detected by the system
enum DeviceType: String, CaseIterable, Codable {
    case usbStick = "USB Stick"
    case sdCard = "SD Card"
    case microSDCard = "microSD Card"
    case externalHDD = "external HDD"
    case externalSSD = "external SSD"
    case unknown = "unknown"
    
    /// Returns the appropriate SF Symbol icon name for this device type
    var icon: String {
        switch self {
        case .usbStick, .sdCard, .microSDCard:
            return "mediastick"
        case .externalHDD, .externalSSD:
            return "externaldrive"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    /// Returns a human-readable description of the device type
    var description: String {
        switch self {
        case .usbStick:
            return "USB flash drive or memory stick"
        case .sdCard:
            return "Secure Digital memory card"
        case .microSDCard:
            return "Micro Secure Digital memory card"
        case .externalHDD:
            return "External hard disk drive"
        case .externalSSD:
            return "External solid state drive"
        case .unknown:
            return "Unknown or unrecognized device type"
        }
    }
}

