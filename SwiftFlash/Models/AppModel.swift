//
//  AppModel.swift
//  SwiftFlash
//
//  Central application model that coordinates shared state and services.
//

import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var deviceInventory: DeviceInventory
    @Published var driveService: DriveDetectionService
    // Mirror service state for SwiftUI reactivity
    @Published var drives: [Drive] = []
    @Published var isScanning: Bool = false

    init() {
        let inventory = DeviceInventory()
        let driveService = DriveDetectionService()

        self.deviceInventory = inventory
        self.driveService = driveService

        // Bridge service state into AppModel so SwiftUI updates when drives change
        self.driveService.$drives
            .receive(on: RunLoop.main)
            .assign(to: &self.$drives)

        self.driveService.$isScanning
            .receive(on: RunLoop.main)
            .assign(to: &self.$isScanning)
    }
}


