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
    /// Icons defined by DATA-009 requirement in notes/requirements_specification.md
    /// DO NOT CHANGE unless DATA-009 requirement is updated
    var icon: String {
        switch self {
        case .usbStick:
            return "mediastick"  // DATA-009: user preference
        case .sdCard:
            return "sdcard"      // DATA-009: specific icon for SD cards
        case .microSDCard:
            return "sdcard.fill" // DATA-009: filled variant for microSD
        case .externalHDD, .externalSSD:
            return "externaldrive.fill" // DATA-009: filled variant for external drives
        case .unknown:
            return "questionmark.circle" // DATA-009: question mark for unknown devices
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

