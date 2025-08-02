import SwiftUI

struct ContentView: View {
    @StateObject private var imageService = ImageFileService()
    @EnvironmentObject var deviceInventory: DeviceInventory
    @StateObject private var driveService: DriveDetectionService
    @State private var selectedDrive: Drive?
    
    init() {
        let driveService = DriveDetectionService()
        self._driveService = StateObject(wrappedValue: driveService)
    }
    
    private func setupDriveService() {
        driveService.inventory = deviceInventory
    }
    @State private var isDropTargeted = false
    @State private var showInspector = true
    @State private var showAboutDialog = false
    @State private var showCustomNameDialog = false
    @State private var customNameText = ""
    @State private var deviceToRename: Drive?
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 30) {
                        imageFileSection
                        errorMessageSection
                        driveSelectionSection
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                
                // Inspector Panel
                if showInspector, let selectedDrive = selectedDrive {
                    DriveInspectorView(drive: selectedDrive)
                        .frame(width: 300)
                        .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                inspectorToggleButton
                refreshButton
                Divider()
                debugButton
                aboutButton
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
        .onAppear {
            setupDriveService()
        }

    }
    
    // MARK: - View Sections
    
    private var imageFileSection: some View {
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
    }
    
    private var errorMessageSection: some View {
        Group {
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
        }
    }
    
    private var driveSelectionSection: some View {
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
                VStack(spacing: 12) {
                    ForEach(driveService.drives) { drive in
                        DriveRowView(drive: drive, isSelected: selectedDrive?.id == drive.id)
                            .onTapGesture {
                                selectedDrive = drive
                            }
                            .contextMenu {
                                Button("Set Custom Name") {
                                    deviceToRename = drive
                                    showCustomNameDialog = true
                                }
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    
    private var inspectorToggleButton: some View {
        Button(action: {
            showInspector.toggle()
        }) {
            Image(systemName: showInspector ? "sidebar.right" : "sidebar.right")
                .opacity(showInspector ? 1.0 : 0.5)
        }
        .help("Toggle Inspector")
    }
    
    private var refreshButton: some View {
        Button(action: {
            driveService.refreshDrives()
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .help("Refresh Drives")
        .disabled(driveService.isScanning)
    }
    
    private var debugButton: some View {
        Group {
            if let selectedDrive = selectedDrive {
                Button(action: {
                    printDiskArbitrationInfo(for: selectedDrive)
                }) {
                    Image(systemName: "ladybug")
                }
                .help("Print Disk Arbitration Debug Info")
            }
        }
    }
    

    
    private var aboutButton: some View {
        Button(action: {
            showAboutDialog = true
        }) {
            Image(systemName: "info.circle")
        }
        .help("About SwiftFlash")
    }
    
    // MARK: - Helper Functions
    
    /// Helper function to get the media UUID for a drive
    private func getMediaUUIDForDrive(_ drive: Drive) -> String? {
        return drive.mediaUUID
    }
    
    /// Debug function to print all Disk Arbitration information for a drive
    private func printDiskArbitrationInfo(for drive: Drive) {
        driveService.printDiskArbitrationInfo(for: drive)
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