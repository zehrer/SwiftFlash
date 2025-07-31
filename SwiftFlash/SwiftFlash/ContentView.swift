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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("SwiftFlash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Flash images to USB drives")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 30)
                
            // Main Content Area
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
        }
        .frame(minWidth: 600, minHeight: 700)
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
