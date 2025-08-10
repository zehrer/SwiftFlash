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

    init() {
        let inventory = DeviceInventory()
        let driveService = DriveDetectionService()

        self.deviceInventory = inventory
        self.driveService = driveService

        // Inject inventory reference for name/type resolution during detection
        // while keeping ownership centralized here.
        self.driveService.inventory = inventory
    }
}


