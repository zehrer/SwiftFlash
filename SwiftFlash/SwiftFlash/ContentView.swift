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
                if let selectedDrive = selectedDrive {
                    ScrollView {
                        DriveInspectorView(drive: selectedDrive, deviceInventory: deviceInventory)
                            .frame(minWidth: 250, idealWidth: 300)
                    }
                } else {
                    VStack {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Drive Selected")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Select a drive from the list to view its details")
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
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                refreshButton
                Divider()
                debugButton
                aboutButton
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
            // Drive icon - use device type icon
            Image(systemName: drive.deviceType.icon)
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
            
            // Status indicator
            if drive.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(isSelected ? Color.blue : Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
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
            deviceInventory: createDemoInventory()
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
            deviceInventory: createDemoInventory()
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
            deviceInventory: createDemoInventory()
        )
    ]
}

// MARK: - Preview ContentView

struct PreviewContentView: View {
    @StateObject private var imageService = ImageFileService()
    @EnvironmentObject var deviceInventory: DeviceInventory
    @State private var selectedDrive: Drive?
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
                if let selectedDrive = selectedDrive {
                    ScrollView {
                        DriveInspectorView(drive: selectedDrive, deviceInventory: deviceInventory)
                            .frame(minWidth: 300, idealWidth: 350)
                    }
                } else {
                    VStack {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Drive Selected")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Select a drive from the list to view its details")
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
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                refreshButton
                Divider()
                debugButton
                aboutButton
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
    
    private var imageFileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step 1: Select Image File")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            DropZoneView(isTargeted: $isDropTargeted) { url in
                if let imageFile = imageService.validateAndLoadImage(from: url) {
                    imageService.selectedImage = imageFile
                }
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
            
            VStack(spacing: 12) {
                ForEach(demoDrives) { drive in
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
}

#Preview("ContentView with Demo Data") {
    PreviewContentView(demoDrives: createDemoDrives(), defaultSelectedIndex: 0)
        .environmentObject(createDemoInventory())
}
