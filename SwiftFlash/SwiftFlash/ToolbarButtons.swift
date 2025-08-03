// ToolbarButtons.swift
// Gemeinsame Toolbar-Buttons für ContentView und PreviewContentView
// Author: AI (Refactoring)
// Created: 2025-08-03

import SwiftUI

/// Toolbar-Button zum Aktualisieren der Laufwerksliste
func refreshButton(driveService: DriveDetectionService) -> some View {
    Button(action: {
        driveService.refreshDrives()
    }) {
        Label("Refresh", systemImage: "arrow.clockwise")
    }
    .help("Refresh Drives")
    .disabled(driveService.isScanning)
}

/// Toolbar-Button zum Flashen eines Images
func flashButton(showFlashConfirmation: Binding<Bool>, canFlash: Bool) -> some View {
    Button(action: {
        showFlashConfirmation.wrappedValue = true
    }) {
        Label("Flash", systemImage: "bolt.fill")
    }
    .help("Flash Image to Drive")
    .disabled(!canFlash)
}

/// Toolbar-Button zum Auswerfen eines Laufwerks
func ejectButton(selectedDrive: Drive?, onEject: @escaping () -> Void) -> some View {
    Button(action: {
        onEject()
    }) {
        Label("Eject", systemImage: "eject.fill")
    }
    .help("Eject Drive")
    .disabled(selectedDrive == nil)
}

/// Toolbar-Button für Tags
func tagsButton(onTags: @escaping () -> Void) -> some View {
    Button(action: {
        onTags()
    }) {
        Label("Tags", systemImage: "tag")
    }
    .help("Edit Tags")
}

/// Toolbar-Button für Debug-Info
func debugButton(selectedDrive: Drive?, onDebug: @escaping () -> Void) -> some View {
    Group {
        if selectedDrive != nil {
            Button(action: {
                onDebug()
            }) {
                Label("Debug", systemImage: "ladybug")
            }
            .help("Print Disk Arbitration Debug Info")
        }
    }
}

/// Toolbar-Button für About
func aboutButton(showAboutDialog: Binding<Bool>) -> some View {
    Button(action: {
        showAboutDialog.wrappedValue = true
    }) {
        Label("About", systemImage: "info.circle")
    }
    .help("About SwiftFlash")
}

/// Toolbar-Button für Inspector
func inspectorToggleButton(showInspector: Binding<Bool>) -> some View {
    Button(action: {
        showInspector.wrappedValue.toggle()
    }) {
        Label("Inspector", systemImage: "sidebar.right")
            .opacity(showInspector.wrappedValue ? 1.0 : 0.5)
    }
    .help("Toggle Inspector")
}