//
//  AppModel.swift
//  SwiftFlash
//
//  Central application model that coordinates shared state and services.
//  Manages the relationship between DeviceInventory and DriveDetectionService.
//

import Combine
import DiskArbitration
// Import the protocol definitions
import Foundation
import IOKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    // the following properties need to be typed, to implemated bindings.
    @Published var deviceInventory: DeviceInventory  // DON'T CHANGE THIS TYPE
    @Published var driveService: DriveDetectionService  // DON'T CHANGE THIS TYPE

    // Mirror service state for SwiftUI reactivity
    @Published var drives: [Device] = []
    @Published var isScanning: Bool = false  // check if we need this status 

    init() {
        self.driveService = DriveDetectionService()
        self.deviceInventory  = DeviceInventory()
       
        // Inject DeviceInventory
        self.driveService.deviceInventory = self.deviceInventory
        

        // Bridge service state into AppModel so SwiftUI updates when drives change
        // Use the concrete DriveDetectionService for publisher access
        driveService.$drives
            .receive(on: RunLoop.main)
            .assign(to: &self.$drives)

//        driveService.$isScanning
//            .receive(on: RunLoop.main)
//            .assign(to: &self.$isScanning)
    }
    
    /// Refreshes the list of drives by calling detectDrives()
    /// This is a convenience method for SwiftUI views to call
    func refreshDrives() {
        isScanning = true
        
        // Detect drives and update the published array
        let allDrives = driveService.detectDrives()
    
        self.drives = allDrives.filter { !($0.isDiskImage) }
        
        isScanning = false
    }
    
}
