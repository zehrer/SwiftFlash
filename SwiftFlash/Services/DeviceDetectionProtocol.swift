//
//  DeviceDetectionProtocol.swift
//  SwiftFlash
//
//  Protocol defining the relationship between device detection services and inventory management.
//  This file establishes a clear contract between the device detection service (DriveDetectionService)
//  and the inventory management system (DeviceInventory), allowing for better separation of concerns
//  and future extensibility. The DriveDetectionService is responsible for detecting devices and
//  reporting them to the DeviceInventory, which is responsible for persisting device information.
//

import Foundation
import SwiftUI

/// Protocol that defines the requirements for a device detection service
protocol DeviceDetectionService: ObservableObject {
    /// The current list of detected devices
    var drives: [Device] { get }
    
    /// Indicates whether a scan is currently in progress
    var isScanning: Bool { get }
    
    /// The inventory manager that this service reports to
    var deviceInventory: (any DeviceInventoryManager)? { get set }
    
    /// Refreshes the list of drives
    func refreshDrives()
    
    /// Detects all available devices
    func detectDrives() -> [Device]
}

/// Protocol that defines the requirements for a device inventory manager
protocol DeviceInventoryManager: ObservableObject {
    /// The list of devices in the inventory
    var devices: [DeviceInventoryItem] { get set }
    
    func setCustomName(for mediaUUID: String, customName: String?)
    
    func setDeviceType(for mediaUUID: String, deviceType: DeviceType)
    
    /// Adds or updates a device in the inventory
    func addOrUpdateDevice(
        mediaUUID: String,
        size: Int64,
        originalName: String,
        deviceType: DeviceType,
        vendor: String?,
        revision: String?
    )
    
    /// Gets an inventory item by its media UUID
    func getInventoryItem(for mediaUUID: String) -> DeviceInventoryItem?
    
    /// Saves the current inventory state
    func saveInventory()
}
