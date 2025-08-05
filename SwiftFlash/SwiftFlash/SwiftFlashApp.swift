//
//  SwiftFlashApp.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import SwiftUI

// MARK: - CRITICAL APP STRUCTURE (DO NOT MODIFY - Main app entry point)
// This is the main app entry point and defines the app's scene structure.
// Changes here affect app initialization, environment setup, and window management.
// Any modifications require testing of app startup and window behavior.
@main
struct SwiftFlashApp: App {
    @StateObject private var deviceInventory = DeviceInventory()
    @State private var showAboutDialog = false
    
    init() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        print("🚀 [DEBUG] SwiftFlash App Starting - Version \(version) (\(build))")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deviceInventory)
                .sheet(isPresented: $showAboutDialog) {
                    AboutView()
                }
        }
        .commands {
            // Override the default About menu to use our custom AboutView
            CommandGroup(replacing: .appInfo) {
                Button("About SwiftFlash") {
                    showAboutDialog = true
                }
            }
        }
        
        #if os(macOS)
        // Adds a native macOS Settings window accessible via the menu bar.
        Settings {
            SettingsView(inventory: deviceInventory)
        }
        #endif // os(macOS)
    }
}
// END: CRITICAL APP STRUCTURE
