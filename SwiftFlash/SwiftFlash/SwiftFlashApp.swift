//
//  SwiftFlashApp.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import SwiftUI

@main
struct SwiftFlashApp: App {
    @StateObject private var deviceInventory = DeviceInventory()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deviceInventory)
        }
        
        #if os(macOS)
        // Adds a native macOS Settings window accessible via the menu bar.
        Settings {
            SettingsView(inventory: deviceInventory)
        }
        #endif // os(macOS)
    }
}
