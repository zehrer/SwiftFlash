//
//  SwiftFlashApp.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import SwiftUI

@main
struct SwiftFlashApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
