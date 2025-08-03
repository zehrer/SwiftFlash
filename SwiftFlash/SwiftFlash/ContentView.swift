import SwiftUI

struct ContentView: View {
    @StateObject private var imageService = ImageFileService()
    @State private var imageHistoryService = ImageHistoryService()
    @EnvironmentObject var deviceInventory: DeviceInventory
    @StateObject private var driveService: DriveDetectionService
    @State private var selectedDrive: Drive?
    @State private var selectedImage: ImageFile?
    
    init() {
        let driveService = DriveDetectionService()
        self._driveService = StateObject(wrappedValue: driveService)
    }
    
    private func setupDriveService() {
        driveService.inventory = deviceInventory
    }
    @State private var isDropTargeted = false
    @State private var showInspector = false  // Hidden by default
    @State private var showAboutDialog = false
    @State private var showCustomNameDialog = false
    @State private var customNameText = ""
    @State private var deviceToRename: Drive?
    
    var body: some View {
        HSplitView {
            // Main Content Area (Left Side)
            ScrollView {
                VStack(spacing: 30) {
                    imageFileSection
                    errorMessageSection
                    driveSelectionSection
                }
                .padding()
            }
            .frame(minWidth: 400, idealWidth: 500)
            .background(Color.white)
            
            // Inspector Area (Right Side) - Only show when showInspector is true
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
        }
        .frame(minWidth: 400)
        .frame(minHeight: 700)
        .toolbar(id: "mainToolbar") {
            ToolbarItem(id: "refresh", placement: .automatic) {
                refreshButton
            }
            
            ToolbarItem(id: "space1", placement: .automatic) {
                Spacer()
            }
            
            ToolbarItem(id: "flash", placement: .automatic) {
                flashButton
            }
            
            ToolbarItem(id: "eject", placement: .automatic) {
                ejectButton
            }
            
            ToolbarItem(id: "flexibleSpace", placement: .automatic) {
                Spacer()
            }
            
            ToolbarItem(id: "tags", placement: .automatic) {
                tagsButton
            }
            
            ToolbarItem(id: "debug", placement: .automatic) {
                debugButton
            }
            
            ToolbarItem(id: "about", placement: .automatic) {
                aboutButton
            }
            
            ToolbarItem(id: "inspector", placement: .automatic) {
                inspectorToggleButton
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
            Task {
                _ = await driveService.detectDrives()
            }
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
                                imageService.clearSelection()
                                self.selectedImage = nil
                                self.selectedDrive = nil
                            },
                            onSelectDifferent: {
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
    
    private var flashButton: some View {
        Button(action: {
            // TODO: Implement flash functionality
            print("🚀 [DEBUG] Flash button pressed")
        }) {
            Image(systemName: "bolt.fill")
        }
        .help("Flash Image to Drive")
        .disabled(!canFlash)
    }
    
    private var canFlash: Bool {
        guard let selectedDrive = selectedDrive,
              let selectedImage = imageService.selectedImage else {
            return false
        }
        
        // Check all preconditions
        return !selectedDrive.isReadOnly && selectedImage.size < selectedDrive.size
    }
    
    private var ejectButton: some View {
        Button(action: {
            // TODO: Implement eject functionality
            print("⏏️ [DEBUG] Eject button pressed for drive: \(selectedDrive?.displayName ?? "none")")
        }) {
            Image(systemName: "eject.fill")
        }
        .help("Eject Drive")
        .disabled(selectedDrive == nil)
    }
    
    private var tagsButton: some View {
        Button(action: {
            // TODO: Implement tags functionality
            print("🏷️ [DEBUG] Tags button pressed")
        }) {
            Image(systemName: "tag")
        }
        .help("Edit Tags")
    }
    
    // MARK: - Helper Functions
    
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

// MARK: - Preview ContentView

struct PreviewContentView: View {
    @StateObject private var imageService = ImageFileService()
    @State private var imageHistoryService = ImageHistoryService()
    @EnvironmentObject var deviceInventory: DeviceInventory
    @State private var selectedDrive: Drive?
    @State private var selectedImage: ImageFile?
    @State private var isDropTargeted = false
    @State private var showInspector = true  // Show by default for preview
    @State private var showAboutDialog = false
    @State private var showCustomNameDialog = false
    @State private var customNameText = ""
    @State private var deviceToRename: Drive?
    
    let demoDrives: [Drive]
    
    init(demoDrives: [Drive], defaultSelectedIndex: Int = 0) {
        self.demoDrives = demoDrives
        // Set default selection if drives are available
        if !demoDrives.isEmpty && defaultSelectedIndex < demoDrives.count {
            self._selectedDrive = State(initialValue: demoDrives[defaultSelectedIndex])
        }
        // Set demo image by default for testing
        self._selectedImage = State(initialValue: ImageFile.demoImage)
    }
    
    var body: some View {
        HSplitView {
            // Main Content Area (Left Side)
            ScrollView {
                VStack(spacing: 30) {
                    imageFileSection
                    errorMessageSection
                    driveSelectionSection
                }
                .padding()
            }
            .frame(minWidth: 400, idealWidth: 500)
            .background(Color.white)
            
            // Inspector Area (Right Side) - Only show when showInspector is true
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
        }
        .frame(minWidth: 400)
        .frame(minHeight: 700)
        .toolbar(id: "previewToolbar") {
            ToolbarItem(id: "refresh", placement: .automatic) {
                refreshButton
            }
            
            ToolbarItem(id: "space1", placement: .automatic) {
                Spacer()
            }
            
            ToolbarItem(id: "flash", placement: .automatic) {
                flashButton
            }
            
            ToolbarItem(id: "eject", placement: .automatic) {
                ejectButton
            }
            
            ToolbarItem(id: "flexibleSpace", placement: .automatic) {
                Spacer()
            }
            
            ToolbarItem(id: "tags", placement: .automatic) {
                tagsButton
            }
            
            ToolbarItem(id: "debug", placement: .automatic) {
                debugButton
            }
            
            ToolbarItem(id: "about", placement: .automatic) {
                aboutButton
            }
            
            ToolbarItem(id: "inspector", placement: .automatic) {
                inspectorToggleButton
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
                    if let mediaUUID = drive.mediaUUID {
                        deviceInventory.setCustomName(for: mediaUUID, customName: customNameText)
                    }
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
    
    // MARK: - View Components
    
    private var driveSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step 2: Select USB Drive")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(demoDrives) { drive in
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
        }
    }
    
    private var imageFileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step 1: Select Image File")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 16) {
                // Left side: Drop zone
                VStack {
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
            // No-op for preview
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .help("Refresh Drives")
    }
    
    private var debugButton: some View {
        Group {
            if selectedDrive != nil {
                Button(action: {
                    // No-op for preview
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
    
    private var flashButton: some View {
        Button(action: {
            // No-op for preview
        }) {
            Image(systemName: "bolt.fill")
        }
        .help("Flash Image to Drive")
        .disabled(!canFlash)
    }
    
    private var canFlash: Bool {
        guard let selectedDrive = selectedDrive,
              let selectedImage = imageService.selectedImage else {
            return false
        }
        
        // Check all preconditions
        return !selectedDrive.isReadOnly && selectedImage.size < selectedDrive.size
    }
    
    private var ejectButton: some View {
        Button(action: {
            // No-op for preview
        }) {
            Image(systemName: "eject.fill")
        }
        .help("Eject Drive")
        .disabled(selectedDrive == nil)
    }
    
    private var tagsButton: some View {
        Button(action: {
            // No-op for preview
        }) {
            Image(systemName: "tag")
        }
        .help("Edit Tags")
    }
}

// MARK: - Preview Helpers

private func createDemoInventory() -> DeviceInventory {
    let demoInventory = DeviceInventory()
    
    // Add demo devices to inventory
    demoInventory.addOrUpdateDevice(
        mediaUUID: "DEMO_USB_001",
        size: 32000000000, // 32 GB
        originalName: "SanDisk Ultra USB 3.0",
        deviceType: .usbStick,
        vendor: "SanDisk",
        revision: "1.0"
    )
    
    demoInventory.addOrUpdateDevice(
        mediaUUID: "DEMO_SD_002",
        size: 64000000000, // 64 GB
        originalName: "Samsung EVO Plus SDXC",
        deviceType: .sdCard,
        vendor: "Samsung",
        revision: "2.1"
    )
    
    demoInventory.addOrUpdateDevice(
        mediaUUID: "DEMO_SSD_003",
        size: 1000000000000, // 1 TB
        originalName: "Samsung T7 Portable SSD",
        deviceType: .externalSSD,
        vendor: "Samsung",
        revision: "3.0"
    )
    
    return demoInventory
}

private func createDemoDrives() -> [Drive] {
    return [
        Drive(
            name: "Demo USB Stick",
            mountPoint: "/dev/disk2",
            size: 32000000000, // 32 GB
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: false,
            mediaUUID: "DEMO_USB_001",
            mediaName: "SanDisk Ultra USB 3.0",
            vendor: "SanDisk",
            revision: "1.0",
            deviceType: .usbStick
        ),
        Drive(
            name: "Demo SD Card",
            mountPoint: "/dev/disk3",
            size: 64000000000, // 64 GB
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: true,
            mediaUUID: "DEMO_SD_002",
            mediaName: "Samsung EVO Plus SDXC",
            vendor: "Samsung",
            revision: "2.1",
            deviceType: .sdCard
        ),
        Drive(
            name: "Demo External SSD",
            mountPoint: "/dev/disk4",
            size: 1000000000000, // 1 TB
            isRemovable: true,
            isSystemDrive: false,
            isReadOnly: false,
            mediaUUID: "DEMO_SSD_003",
            mediaName: "Samsung T7 Portable SSD",
            vendor: "Samsung",
            revision: "3.0",
            deviceType: .externalSSD
        )
    ]
}

// MARK: - Preview

#Preview("ContentView with Demo Data") {
    PreviewContentView(demoDrives: createDemoDrives(), defaultSelectedIndex: 0)
        .environmentObject(createDemoInventory())
}
