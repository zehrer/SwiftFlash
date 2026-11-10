# SwiftFlash Directory Structure

## Future Project Layout

```
SwiftFlash/
├── .cursorrules                     # AI interaction rules and protocols
├── notes/                           # Project documentation and context
│   ├── project_overview.md          # High-level project description and architecture
│   ├── task_list.md                 # Current tasks and development priorities
│   ├── CLAUDE.md                    # AI-specific instructions and guidelines
│   └── directory_structure.md       # This file - project layout reference
├── SwiftFlashHelper/                # Privileged helper daemon (runs as root, own target)
│   ├── main.swift                   # XPC listener, client signature check
│   └── FlashHelperService.swift     # Safety checks, unmount, write and verify raw device
├── HelperSupport/
│   └── xyz.zehrer.SwiftFlash.helper.plist # launchd plist, embedded in Contents/Library/LaunchDaemons
├── SwiftFlash/                      # Main application source code
│   ├── SwiftFlashApp.swift          # App entry point and configuration
│   ├── ContentView.swift            # Main application interface (PROTECTED layout)
│   ├── Models/                      # Data models (PROTECTED structures)
│   │   ├── DriveModel.swift         # USB drive representation
│   │   ├── ImageFileModel.swift     # Disk image file model
│   │   └── DeviceInventory.swift    # Device management types
│   ├── Services/                    # Core business logic (PROTECTED)
│   │   ├── ImageFlashService.swift  # Device flashing operations
│   │   ├── PrivilegedHelperClient.swift # Registers and calls the root helper (XPC)
│   │   ├── FlashHelperProtocol.swift # XPC protocol shared with the helper target
│   │   ├── DriveDetectionService.swift # Device detection and monitoring
│   │   ├── ImageFileService.swift   # Image file validation and metadata
│   │   ├── ImageHistoryService.swift # Operation history tracking
│   │   └── BookmarkManager.swift    # File system access management
│   ├── Views/                       # UI components
│   │   ├── Inspector/               # Detail views for drives and images
│   │   │   ├── DriveInspectorView.swift
│   │   │   └── ImageInspectorView.swift
│   │   ├── Progress/                # Operation progress and feedback
│   │   │   ├── FlashProgressView.swift
│   │   │   └── FlashConfirmationDialog.swift
│   │   ├── Components/              # Reusable UI components
│   │   │   ├── DropZoneView.swift
│   │   │   ├── ImageFileView.swift
│   │   │   └── ImageHistoryView.swift
│   │   └── Utilities/               # UI utility components
│   │       ├── LabelAndPicker.swift
│   │       ├── LabelAndStatus.swift
│   │       ├── LabelAndText.swift
│   │       ├── LabelAndTextField.swift
│   │       └── InspectorFonts.swift
│   ├── Toolbar/                     # Application toolbar components
│   │   ├── ToolbarButtons.swift
│   │   └── ToolbarConfigurationService.swift
│   ├── Settings/                    # Application preferences
│   │   ├── SettingsView.swift
│   │   └── AboutView.swift
│   ├── Assets.xcassets/             # Application assets
│   │   ├── AccentColor.colorset/
│   │   ├── AppIcon.appiconset/
│   │   └── Contents.json
│   ├── Resources/                   # Additional resources
│   │   ├── AppIcon.icon/
│   │   ├── logo.png
│   │   ├── logo.svg
│   │   └── logo.swift
│   └── SwiftFlash.entitlements      # App sandbox and permissions
├── SwiftFlash.xcodeproj/            # Xcode project files
│   ├── project.pbxproj
│   ├── project.xcworkspace/
│   └── xcuserdata/
├── LICENSE                          # Project license
└── README.md                        # Project documentation
```

## Component Categories

### 🔒 Protected Components (Require Permission to Modify)
These components contain critical functionality and should not be modified without explicit permission:

#### Data Models
- `DriveModel.swift` - Core drive data structure
- `ImageFileModel.swift` - Image file representation
- `DeviceInventory.swift` - Device type definitions and inventory management

#### Core Services  
- `ImageFlashService.swift` - Critical flashing operations and safety checks
- `DriveDetectionService.swift` - Hardware detection and monitoring
- `PrivilegedHelperClient.swift`, `FlashHelperProtocol.swift` - Root access via the helper (XPC contract is shared with `SwiftFlashHelper/`)
- `BookmarkManager.swift` - File system permission management

#### App Structure
- `SwiftFlashApp.swift` - Application lifecycle and configuration
- `ContentView.swift` - Main UI layout structure (layout only, not content)

### ✅ Safe Components (Can Modify Freely)
These components can be modified without affecting critical functionality:

#### UI Components
- Inspector views (content, not layout structure)
- Progress and confirmation dialogs
- Utility components and labels
- Toolbar buttons and configuration

#### Supporting Services
- `ImageFileService.swift` - File validation and metadata (non-critical parts)
- `ImageHistoryService.swift` - History tracking and management

#### Resources and Configuration
- Assets and icons
- Settings and about views
- Documentation files

### 📁 Directory Organization Principles for future changes

#### `/Models/`
Contains data structures and types. Core models are protected, but extensions and computed properties can be added.

#### `/Services/`
Business logic layer. Core services are protected, but utility methods and extensions are modifiable.

#### `/Views/`
User interface components organized by functionality:
- `Inspector/` - Detail views for objects
- `Progress/` - User feedback during operations  
- `Components/` - Reusable UI elements
- `Utilities/` - Helper views and styling

#### `/Toolbar/`
Application toolbar and menu functionality.

#### `/Settings/`
User preferences and application information views.

#### `/Resources/`
Static assets, icons, and resource files.

#### `/.notes/`
Project documentation and AI context files (not part of compiled app).

## File Naming Conventions

- **Views**: `[Purpose]View.swift` (e.g., `DriveInspectorView.swift`)
- **Services**: `[Domain]Service.swift` (e.g., `ImageFlashService.swift`)
- **Models**: `[Entity]Model.swift` (e.g., `DriveModel.swift`)
- **Utilities**: `[Purpose].swift` (e.g., `InspectorFonts.swift`)

## Dependencies and Relationships

### Data Flow
```
Models ← Services ← Views
  ↑        ↑        ↑
  └── Utilities ────┘
```

### Key Dependencies
- Views depend on Services for business logic
- Services depend on Models for data structures  
- Utilities provide shared functionality across all layers
- Services handle all external system interactions (IOKit, File System)

## Notes for Development

- Always check protection markers before modifying any file
- UI components should be modular and reusable where possible
- Services should handle all business logic and external dependencies
- Models should be lightweight data containers with minimal logic
- Follow SwiftUI modern patterns and Swift 6 syntax throughout
