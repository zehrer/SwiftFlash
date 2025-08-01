//
//  ContentView.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var driveService = DriveDetectionService()
    @StateObject private var imageService = ImageFileService()
    @State private var isDropTargeted = false
    @State private var selectedDrive: Drive?
    @State private var showCustomNameDialog = false
    @State private var deviceToRename: Drive?
    @State private var customNameText = ""
    @State private var showInspector = true
    @State private var showAboutDialog = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 30) {
                    // Image File Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Step 1: Select Image File")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        if let selectedImage = imageService.selectedImage {
                            ImageFileView(
                                imageFile: selectedImage,
                                onRemove: {
                                    imageService.clearSelection()
                                },
                                onSelectDifferent: {
                                    imageService.clearSelection()
                                }
                            )
                        } else {
                            DropZoneView(isTargeted: $isDropTargeted) { url in
                                if let imageFile = imageService.validateAndLoadImage(from: url) {
                                    imageService.selectedImage = imageFile
                                }
                            }
                        }
                    }
                
                    // Error Message
                    if let errorMessage = imageService.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                
                    // Drive Selection Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Step 2: Select USB Drive")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            
                            Button(action: {
                                driveService.refreshDrives()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .disabled(driveService.isScanning)
                        }
                        
                        if driveService.isScanning {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Scanning for drives...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                        } else if driveService.drives.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "externaldrive.badge.exclamationmark")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                
                                Text("No USB drives detected")
                                    .font(.headline)
                                
                                Text("Connect a USB drive and click refresh")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("Refresh") {
                                    driveService.refreshDrives()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(driveService.drives) { drive in
                                    DriveRowView(
                                        drive: drive,
                                        isSelected: selectedDrive?.id == drive.id
                                    )
                                                    .onTapGesture {
                    // Don't allow selection of read-only drives
                    if !drive.isReadOnly {
                        selectedDrive = drive
                    }
                }
                .contextMenu {
                    Button("Set Custom Name") {
                        showCustomNameDialog = true
                        deviceToRename = drive
                    }
                }
                                }
                            }
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                
                    // Flash Button
                    if let selectedImage = imageService.selectedImage, let selectedDrive = selectedDrive {
                        VStack(spacing: 16) {
                            // Validation
                            if imageService.validateImageForDrive(selectedImage, drive: selectedDrive) {
                                Button(action: {
                                    // TODO: Implement flashing functionality
                                    print("Flashing \(selectedImage.displayName) to \(selectedDrive.displayName)")
                                }) {
                                    HStack {
                                        Image(systemName: "bolt.fill")
                                        Text("Flash to \(selectedDrive.displayName)")
                                    }
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("Image too large for selected drive")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
                
                }
                .frame(maxWidth: .infinity)
                
                // Inspector Panel
                if let selectedDrive = selectedDrive, showInspector {
                    DriveInspectorView(drive: selectedDrive)
                        .frame(width: 280)
                        .background(Color(.controlBackgroundColor))
                        .border(Color(.separatorColor), width: 1)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Inspector toggle
                Button(action: {
                    showInspector.toggle()
                }) {
                    Image(systemName: showInspector ? "sidebar.right" : "sidebar.right")
                        .opacity(showInspector ? 1.0 : 0.5)
                }
                .help("Toggle Inspector")
                
                // Refresh drives
                Button(action: {
                    driveService.refreshDrives()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Drives")
                .disabled(driveService.isScanning)
                
                Divider()
                
                // About
                Button(action: {
                    showAboutDialog = true
                }) {
                    Image(systemName: "info.circle")
                }
                .help("About SwiftFlash")
            }
        }
        .alert("Set Custom Name", isPresented: $showCustomNameDialog) {
            TextField("Enter custom name", text: $customNameText)
            Button("Cancel", role: .cancel) {
                customNameText = ""
                deviceToRename = nil
            }
            Button("Save") {
                if let drive = deviceToRename, !customNameText.isEmpty {
                    print("🔧 [DEBUG] Attempting to set custom name: '\(customNameText)' for drive: '\(drive.displayName)'")
                    // Find the media UUID for this drive and set the custom name
                    if let mediaUUID = getMediaUUIDForDrive(drive) {
                        print("🔧 [DEBUG] Found media UUID: \(mediaUUID)")
                        driveService.setCustomName(for: mediaUUID, customName: customNameText)
                    } else {
                        print("❌ [DEBUG] Could not find media UUID for drive: \(drive.displayName)")
                    }
                } else {
                    print("❌ [DEBUG] Invalid custom name attempt - drive: \(deviceToRename?.displayName ?? "nil"), text: '\(customNameText)'")
                }
                customNameText = ""
                deviceToRename = nil
            }
        } message: {
            if let drive = deviceToRename {
                Text("Set a custom name for '\(drive.displayName)'")
            }
        }
        .onChange(of: showCustomNameDialog) { _, showDialog in
            if showDialog, let drive = deviceToRename {
                customNameText = drive.displayName
            }
        }
        .sheet(isPresented: $showAboutDialog) {
            AboutView()
        }
    }
    
    /// Helper function to get the media UUID for a drive
    private func getMediaUUIDForDrive(_ drive: Drive) -> String? {
        // Now we have the mediaUUID directly in the Drive model
        return drive.mediaUUID
    }
}

struct DriveRowView: View {
    let drive: Drive
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Drive icon
            Image(systemName: "externaldrive.fill")
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 32)
            
            // Drive info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(drive.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    if drive.isReadOnly {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                HStack {
                    Text(drive.formattedSize)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    if drive.isReadOnly {
                        Text("Read-only")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
}
