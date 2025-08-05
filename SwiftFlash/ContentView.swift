import SwiftUI

struct ContentView: View {
    @StateObject private var imageService = ImageFileService()
    @State private var imageHistoryService = ImageHistoryService()
    @State private var flashService: ImageFlashService
    @State private var toolbarConfig = ToolbarConfigurationService()
    @EnvironmentObject var deviceInventory: DeviceInventory
    @StateObject private var driveService: DriveDetectionService
    @State private var selectedDrive: Drive?
    @State private var selectedImage: ImageFile?
    
    init() {
        let driveService = DriveDetectionService()
        self._driveService = StateObject(wrappedValue: driveService)
        
        let imageHistoryService = ImageHistoryService()
        let flashService = ImageFlashService(imageHistoryService: imageHistoryService)
        self._imageHistoryService = State(wrappedValue: imageHistoryService)
        self._flashService = State(wrappedValue: flashService)
    }
    
    private func setupDriveService() {
        driveService.inventory = deviceInventory
    }
    @State private var isDropTargeted = false
    @State private var showInspector = false  // Hidden by default
    @State private var showAboutDialog = false
    @State private var showCustomNameDialog = false
    @State private var showFlashConfirmation = false
    @State private var showFlashProgress = false
    @State private var customNameText = ""
    @State private var deviceToRename: Drive?
    @AppStorage("showStatusBar") private var showStatusBar = true // User can toggle this
    
    // MARK: - Computed Properties
    
    private var canFlash: Bool {
        guard let selectedDrive = selectedDrive,
              let selectedImage = imageService.selectedImage else {
            return false
        }
        
        // Check all preconditions
        return !selectedDrive.isReadOnly && selectedImage.size < selectedDrive.size
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
            // MARK: - MAIN CONTENT AREA (DO NOT MODIFY - Tested and verified)
            // This ScrollView section has been thoroughly tested and should not be changed
            // without additional verification. Changes here require re-testing of the entire UI layout.
            ScrollView {
                VStack(spacing: 30) {
                    imageFileSection
                    errorMessageSection
                    driveSelectionSection
                    
                    // Remove version from main content area
                }
                .padding()
            }
            .frame(minWidth: 400, idealWidth: 500)
            .background(Color.white)
            .onReceive(driveService.$drives) { drives in
                print("🔍 [DEBUG] ContentView: drives array changed - count: \(drives.count)")
            }
            .onReceive(driveService.$isScanning) { isScanning in
                print("🔍 [DEBUG] ContentView: isScanning changed - \(isScanning)")
            }
            // END: MAIN CONTENT AREA
            
            // MARK: - INSPECTOR AREA (DO NOT MODIFY - Tested and verified)
            // Inspector layout has been tested and should not be changed without verification
            if showInspector {
                if let selectedImage = selectedImage {
                    ScrollView {
                        ImageInspectorView(image: selectedImage)
                            .frame(minWidth: 250, idealWidth: 300)
                    }
                } else if let selectedDrive = selectedDrive {
                    ScrollView {
                        DriveInspectorView(drive: selectedDrive, deviceInventory: deviceInventory)
                            .frame(minWidth: 250, idealWidth: 300)
                    }
                } else {
                    VStack {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Selection")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Select an image file or drive to view its details")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            // END: INSPECTOR AREA
            }
            
            // Status Bar
            if showStatusBar {
                HStack {
                    // Version info
                    Text("Version : \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2025.8") (build : \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Drive count
                    if !driveService.drives.isEmpty {
                        Text("\(driveService.drives.count) drive\(driveService.drives.count == 1 ? "" : "s") detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separatorColor)),
                    alignment: .top
                )
            }
        }
        .frame(minWidth: 400)
        .frame(minHeight: 700)
        .onReceive(NotificationCenter.default.publisher(for: .toggleStatusBar)) { _ in
            showStatusBar.toggle()
        }
        .toolbar(id: "mainToolbar") {
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
                            if let selectedImage = imageService.selectedImage {
                                Task {
                                    do {
                                        // Calculate checksum with progress updates (service handles state)
                                        let checksum = try await flashService.calculateSHA256Checksum(for: selectedImage)
                                        
                                        // Update the image with the checksum
                                        var updatedImage = selectedImage
                                        updatedImage.sha256Checksum = checksum
                                        imageService.selectedImage = updatedImage
                                        
                                        // Try to store in history, but don't fail if it doesn't work
                                        imageHistoryService.addToHistory(updatedImage)
                                        print("✅ [DEBUG] Checksum generated and stored for: \(selectedImage.displayName)")
                                    } catch {
                                        print("❌ [DEBUG] Failed to generate checksum: \(error)")
                                        // Service already handles state management, no need to set failed state here
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Progress bar for checksum calculation
                if case .calculatingChecksum(let progress) = flashService.flashState {
                    ToolbarItem(id: "checksumProgress", placement: .automatic) {
                        HStack(spacing: 8) {
                            // Progress bar
                            ProgressView(value: progress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 120)
                            
                            // Percentage text
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                            
                            // Cancel button
                            Button(action: {
                                flashService.cancel()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Cancel checksum calculation")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
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
                                printDiskArbitrationInfo(for: selectedDrive)
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
        .sheet(isPresented: $showFlashConfirmation) {
            if let selectedDrive = selectedDrive,
               let selectedImage = imageService.selectedImage {
                FlashConfirmationDialog(
                    image: selectedImage,
                    device: selectedDrive,
                    onConfirm: {
                        showFlashConfirmation = false
                        showFlashProgress = true
                        Task {
                            await performFlash()
                        }
                    },
                    onCancel: {
                        showFlashConfirmation = false
                    }
                )
            }
        }
        .sheet(isPresented: $showFlashProgress) {
            if let selectedDrive = selectedDrive,
               let selectedImage = imageService.selectedImage {
                FlashProgressView(
                    image: selectedImage,
                    device: selectedDrive,
                    flashState: flashService.flashState,
                    onCancel: {
                        showFlashProgress = false
                        flashService.resetState()
                    }
                )
            }
        }
        .onAppear {
            setupDriveService()
            driveService.refreshDrives()
        }
    }
    
    // MARK: - View Components
    
    private var imageFileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step 1: Select Image File")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 16) {
                // Left side: Drop zone or selected image
                VStack {
                    if let selectedImage = imageService.selectedImage {
                        ImageFileView(
                            imageFile: selectedImage,
                            onRemove: {
                                // Stop accessing secure resource before clearing
                                selectedImage.stopAccessingSecureResource()
                                imageService.clearSelection()
                                self.selectedImage = nil
                                self.selectedDrive = nil
                            }
                        )
                        .onTapGesture {
                            self.selectedImage = selectedImage
                            self.selectedDrive = nil
                        }
                    } else {
                        DropZoneView(isTargeted: $isDropTargeted) { url in
                            if let imageFile = imageService.validateAndLoadImage(from: url) {
                                imageService.selectedImage = imageFile
                                self.selectedImage = imageFile
                                self.selectedDrive = nil
                                // Add to history
                                imageHistoryService.addToHistory(imageFile)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right side: Image history
                ImageHistoryView(
                    imageHistoryService: imageHistoryService,
                    onImageSelected: { imageFile in
                        imageService.selectedImage = imageFile
                        self.selectedImage = imageFile
                        self.selectedDrive = nil
                        // Add to history (will move to top)
                        imageHistoryService.addToHistory(imageFile)
                    }
                )
                .frame(width: 300)
            }
        }
    }
    
    private var errorMessageSection: some View {
        Group {
            if let errorMessage = imageService.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
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
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            } else if driveService.drives.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Drives Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Connect a USB drive, SD card, or external storage device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 12) {
                    ForEach(driveService.drives) { drive in
                        DriveRowView(drive: drive, isSelected: selectedDrive?.id == drive.id)
                            .environmentObject(deviceInventory)
                            .onTapGesture {
                                selectedDrive = drive
                                selectedImage = nil
                            }
                            .contextMenu {
                                Button("Set Custom Name") {
                                    deviceToRename = drive
                                    showCustomNameDialog = true
                                }
                            }
                    }
                }
                .onAppear {
                    for (index, drive) in driveService.drives.enumerated() {
                        print("🔍 [DEBUG] UI: Drive \(index): \(drive.displayName)")
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func performFlash() async {
        guard let selectedDrive = selectedDrive,
              let selectedImage = imageService.selectedImage else {
            return
        }
        
        do {
            try await flashService.flashImage(selectedImage, to: selectedDrive)
        } catch {
            print("❌ [DEBUG] Flash failed: \(error)")
        }
    }
    
    private func getMediaUUIDForDrive(_ drive: Drive) -> String? {
        return drive.mediaUUID
    }
    
    private func printDiskArbitrationInfo(for drive: Drive) {
        print("🔍 [DEBUG] Disk Arbitration Info for: \(drive.displayName)")
        print("   - Mount Point: \(drive.mountPoint)")
        print("   - Size: \(drive.formattedSize)")
        print("   - Media UUID: \(drive.mediaUUID ?? "Unknown")")
        print("   - Media Name: \(drive.mediaName ?? "Unknown")")
        print("   - Vendor: \(drive.vendor ?? "Unknown")")
        print("   - Revision: \(drive.revision ?? "Unknown")")
        print("   - Device Type: \(drive.deviceType.rawValue)")
        print("   - Is Read Only: \(drive.isReadOnly)")
        print("   - Is Removable: \(drive.isRemovable)")
    }
}

// MARK: - DriveRowView

struct DriveRowView: View {
    let drive: Drive
    let isSelected: Bool
    @EnvironmentObject var deviceInventory: DeviceInventory
    
    var deviceType: DeviceType {
        if let mediaUUID = drive.mediaUUID,
           let inventoryDevice = deviceInventory.devices.first(where: { $0.mediaUUID == mediaUUID }) {
            return inventoryDevice.deviceType
        }
        return drive.deviceType
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Device Icon
            Image(systemName: deviceType.icon)
                .font(.title2)
                .foregroundColor(drive.isReadOnly ? .red : .blue)
                .frame(width: 32)
            
            // Device Info
            VStack(alignment: .leading, spacing: 2) {
                Text(drive.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(drive.isReadOnly ? .red : .primary)
                
                HStack(spacing: 8) {
                    Text(drive.formattedSize)
                        .font(.caption)
                        .foregroundColor(drive.isReadOnly ? .red.opacity(0.7) : .secondary)
                    
                    if let vendor = drive.vendor {
                        Text("• \(vendor)")
                            .font(.caption)
                            .foregroundColor(drive.isReadOnly ? .red.opacity(0.7) : .secondary)
                    }
                    
                    if let revision = drive.revision {
                        Text("• \(revision)")
                            .font(.caption)
                            .foregroundColor(drive.isReadOnly ? .red.opacity(0.7) : .secondary)
                    }
                    
                    if drive.isReadOnly {
                        Text("• Read Only")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Spacer()
            
            // Device Type
            Text(deviceType.rawValue)
                .font(.caption)
                .foregroundColor(drive.isReadOnly ? .red.opacity(0.7) : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Preview

#Preview("ContentView") {
    ContentView()
}
