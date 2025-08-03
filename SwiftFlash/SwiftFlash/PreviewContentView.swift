// PreviewContentView.swift
// Preview-View für SwiftFlash - NUR bei wichtigen HMI-Änderungen aktualisieren
// Author: AI (Refactoring)
// Created: 2025-08-03
// 
// WICHTIG: Diese Datei dient nur zur Validierung von HMI-Änderungen
// und sollte NUR bei entscheidenden UI/UX-Änderungen aktualisiert werden.
// Für normale Entwicklung und Bugfixes diese Datei IGNORIEREN.

import SwiftUI

/// Preview-View für SwiftFlash
/// 
/// Diese View wird nur für Xcode-Previews verwendet und sollte
/// bei normaler Entwicklung NICHT bearbeitet werden.
/// 
/// Nur aktualisieren bei:
/// - Großen HMI-Änderungen (Layout, Navigation, etc.)
/// - Neuen UI-Komponenten die in Preview getestet werden müssen
/// - Wichtigen UI/UX-Validierungen
struct PreviewContentView: View {
    // MARK: - Preview Data (ObservableObject Services)
    @StateObject private var driveService = DriveDetectionService()
    @StateObject private var imageService = ImageFileService()
    @StateObject private var deviceInventory = DeviceInventory()
    
    // MARK: - Preview Data (Regular Services)
    private let flashService: ImageFlashService
    private let historyService = ImageHistoryService()
    private let toolbarConfig = ToolbarConfigurationService()
    
    init() {
        // Initialize flash service with history service
        self.flashService = ImageFlashService(imageHistoryService: ImageHistoryService())
    }
    
    // MARK: - Preview State
    @State private var selectedDrive: Drive?
    @State private var showInspector = true
    @State private var showFlashConfirmation = false
    @State private var showAboutDialog = false
    @State private var deviceToRename: Drive?
    @State private var isDropTargeted = false
    
    // MARK: - Computed Properties
    
    private var canFlash: Bool {
        guard let selectedDrive = selectedDrive,
              let selectedImage = imageService.selectedImage else {
            return false
        }
        
        // Check all preconditions
        return !selectedDrive.isReadOnly && selectedImage.size < selectedDrive.size
    }
    
    // MARK: - Body
    var body: some View {
        NavigationSplitView {
            // Sidebar with drives
            List(driveService.drives, selection: $selectedDrive) { drive in
                DriveInspectorView(drive: drive, deviceInventory: deviceInventory)
            }
            .navigationTitle("Drives")
        } content: {
            // Main content area
            VStack {
                // Drop zone for images
                DropZoneView(isTargeted: $isDropTargeted) { url in
                    if let imageFile = imageService.validateAndLoadImage(from: url) {
                        imageService.selectedImage = imageFile
                    }
                }
                
                // Image selection area
                if let selectedImage = imageService.selectedImage {
                    VStack {
                        Text("Selected Image:")
                            .font(.headline)
                        ImageFileView(
                            imageFile: selectedImage,
                            onRemove: { 
                                imageService.clearSelection()
                            },
                            onSelectDifferent: { 
                                // TODO: Implement select different
                                print("🔄 [DEBUG] Select different image")
                            }
                        )
                    }
                    .padding()
                } else {
                    Text("Drop an image file here")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Images")
        } detail: {
            // Detail view
            if let selectedDrive = selectedDrive {
                DriveInspectorView(drive: selectedDrive, deviceInventory: deviceInventory)
            } else {
                Text("Select a drive")
                    .foregroundColor(.secondary)
            }
        }
        .toolbar(id: "previewToolbar") {
            Group {
                if toolbarConfig.toolbarItems.contains("refresh") {
                    ToolbarItem(id: "refresh", placement: .automatic) {
                        refreshButton(driveService: driveService)
                    }
                }
                
                if toolbarConfig.toolbarItems.contains("flexibleSpace") {
                    ToolbarItem(id: "flexibleSpace", placement: .automatic) {
                        Spacer()
                    }
                }
                
                if toolbarConfig.toolbarItems.contains("flash") {
                    ToolbarItem(id: "flash", placement: .automatic) {
                        flashButton(showFlashConfirmation: $showFlashConfirmation, canFlash: canFlash)
                    }
                }
                
                if toolbarConfig.toolbarItems.contains("eject") {
                    ToolbarItem(id: "eject", placement: .automatic) {
                        ejectButton(selectedDrive: selectedDrive) {
                            // TODO: Implement eject functionality
                            print("⏏️ [DEBUG] Eject button pressed for drive: \(selectedDrive?.displayName ?? "none")")
                        }
                    }
                }
                
                if toolbarConfig.toolbarItems.contains("checksum") {
                    ToolbarItem(id: "checksum", placement: .automatic) {
                        checksumButton(selectedImage: imageService.selectedImage) {
                            // TODO: Implement checksum functionality for preview
                            print("🔍 [DEBUG] Checksum button pressed for preview")
                        }
                    }
                }
                
                if toolbarConfig.toolbarItems.contains("tags") {
                    ToolbarItem(id: "tags", placement: .automatic) {
                        tagsButton {
                            // TODO: Implement tags functionality
                            print("🏷️ [DEBUG] Tags button pressed")
                        }
                    }
                }
                
                if toolbarConfig.toolbarItems.contains("debug") {
                    ToolbarItem(id: "debug", placement: .automatic) {
                        debugButton(selectedDrive: selectedDrive) {
                            if let selectedDrive = selectedDrive {
                                print("🔍 [DEBUG] Debug button pressed for drive: \(selectedDrive.displayName)")
                            }
                        }
                    }
                }
                
                if toolbarConfig.toolbarItems.contains("about") {
                    ToolbarItem(id: "about", placement: .automatic) {
                        aboutButton(showAboutDialog: $showAboutDialog)
                    }
                }
                
                if toolbarConfig.toolbarItems.contains("inspector") {
                    ToolbarItem(id: "inspector", placement: .automatic) {
                        inspectorToggleButton(showInspector: $showInspector)
                    }
                }
            }
        }
        .sheet(isPresented: $showAboutDialog) {
            AboutView()
        }
        .sheet(isPresented: $showFlashConfirmation) {
            if let selectedDrive = selectedDrive,
               let selectedImage = imageService.selectedImage {
                FlashConfirmationDialog(
                    image: selectedImage,
                    device: selectedDrive,
                    onConfirm: {
                        showFlashConfirmation = false
                        // TODO: Implement flash functionality
                        print("⚡ [DEBUG] Flash confirmed for: \(selectedDrive.displayName)")
                    },
                    onCancel: {
                        showFlashConfirmation = false
                    }
                )
            }
        }
        .onAppear {
            // Load preview data
            driveService.refreshDrives()
        }
    }
}

// MARK: - Preview
#Preview {
    PreviewContentView()
} 