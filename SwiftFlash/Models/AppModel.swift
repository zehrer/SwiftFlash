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
    @Published var isScanning: Bool = false

    init() {
        let inventory = DeviceInventory()
        let driveService = DriveDetectionService(deviceInventory: inventory)

        self.deviceInventory = inventory
        self.driveService = driveService

        // Bridge service state into AppModel so SwiftUI updates when drives change
        // Use the concrete DriveDetectionService for publisher access
        if let concreteService = driveService as? DriveDetectionService {
            concreteService.$drives
                .receive(on: RunLoop.main)
                .assign(to: &self.$drives)

            concreteService.$isScanning
                .receive(on: RunLoop.main)
                .assign(to: &self.$isScanning)
        }
    }
}
