# SwiftFlash

**SwiftFlash** is a lightweight, native macOS application for flashing `.img` and `.iso` files to USB drives. Built with SwiftUI and Swift 6, SwiftFlash aims to be a minimal, safe, and open-source alternative to bulky tools like balenaEtcher or Raspberry Pi Imager.

⚡️ **Simple. Safe. Swift.**

## Features

- 🖥️ **Native macOS Interface** - Built with SwiftUI for seamless integration
- 📁 **Drag & Drop Support** - Simply drag your image file onto the app
- 🔍 **Smart Drive Detection** - Automatically lists connected removable drives
- 🛡️ **Built-in Safety Checks** - Prevents accidental flashing to wrong disks
- 📊 **Real-time Progress** - Visual feedback during the flashing process
- 🔐 **Disk Arbitration Integration** - Uses macOS native disk management
- 💾 **Device Inventory** - Tracks and remembers your devices
- 🔒 **SHA256 Checksum Verification** - Generate and verify file integrity checksums

## Supported File Formats

- `.img` - Raw disk images
- `.iso` - ISO disk images
- Other raw disk image formats

## System Requirements

- **macOS**: 15.6 or later
- **Architecture**: Apple Silicon (ARM64) or Intel (x86_64)
- **Memory**: 512MB RAM minimum
- **Storage**: 100MB free space

## Installation

### Download
Download the latest release from the [Releases](https://github.com/yourusername/SwiftFlash/releases) page.

### Build from Source
```bash
git clone https://github.com/yourusername/SwiftFlash.git
cd SwiftFlash
xcodebuild -project SwiftFlash/SwiftFlash.xcodeproj -scheme SwiftFlash -configuration Release build
```

## Usage

1. **Launch SwiftFlash**
2. **Select Image File** - Drag and drop your `.img` or `.iso` file, or use the file picker
3. **Choose Target Drive** - Select the USB drive from the list of available drives
4. **Review Settings** - Verify the selected image and target drive
5. **Start Flashing** - Click "Flash" and wait for completion

⚠️ **Warning**: Flashing will erase all data on the target drive. Make sure to backup any important files.

## SHA256 Checksum Verification

SwiftFlash includes built-in SHA256 checksum functionality to ensure file integrity and verify downloaded images.

### Generating Checksums

1. **Select an Image File** - Choose any `.img` or `.iso` file
2. **Click the Checksum Button** - Use the checksum button in the toolbar (🔒 icon)
3. **View Results** - The checksum appears in the inspector panel
4. **Compare with Official Checksums** - Verify against official download checksums

### Features

- **🔒 SHA256 Algorithm** - Industry-standard cryptographic hashing
- **📁 Network Share Support** - Works with local files and SMB network shares
- **💾 Automatic Storage** - Checksums are saved in the image history
- **🔍 Integrity Verification** - Verify file integrity before flashing
- **📊 Progress Tracking** - Real-time progress for large files

### Supported Locations

- **Local Files** - Any accessible file on your Mac
- **Network Shares** - SMB, AFP, and other network file systems
- **External Drives** - USB drives, external SSDs, etc.
- **Cloud Storage** - Files synced from iCloud, Dropbox, etc.

### Verification Process

The checksum feature automatically verifies image integrity during the flashing process:

1. **Pre-flash Verification** - Checksum is verified before writing to device
2. **Integrity Confirmation** - Ensures the image hasn't been corrupted
3. **Safety Enhancement** - Adds an extra layer of verification

## Safety Features

- **Drive Validation** - Only removable drives are shown as targets
- **System Drive Protection** - System drives are automatically excluded
- **Confirmation Dialogs** - Multiple confirmation steps before flashing
- **Read-only Detection** - Warns about read-only drives

## Development

### Coding Standards

- **Language**: Swift 6
- **Target**: macOS 15.6+
- **UI Framework**: SwiftUI
- **Binary Size**: Optimized for minimal footprint
- **Documentation**: Function-level comments and key step documentation
- **Dependencies**: Prefer system libraries over third-party dependencies
- **APIs**: Use latest libraries and avoid deprecated interfaces

### Project Structure

```
SwiftFlash/
├── SwiftFlash/
│   ├── SwiftFlashApp.swift          # Main app entry point
│   ├── ContentView.swift            # Main UI view
│   ├── DriveDetectionService.swift  # Disk Arbitration integration
│   ├── DriveModel.swift             # Drive data model
│   ├── DriveInspectorView.swift     # Drive details inspector
│   ├── DropZoneView.swift           # Drag & drop interface
│   ├── ImageFileModel.swift         # Image file handling
│   ├── ImageFileService.swift       # Image file operations
│   ├── ImageFlashService.swift      # Flash operations and checksums
│   ├── ImageHistoryService.swift    # Image history and metadata
│   ├── ImageInspectorView.swift     # Image details and checksum display
│   ├── ToolbarButtons.swift         # Reusable toolbar components
│   ├── ToolbarConfigurationService.swift # Toolbar layout management
│   ├── DeviceInventory.swift        # Device tracking
│   ├── SwiftFlash.entitlements      # App sandbox permissions
│   └── Resources/                   # App resources and assets
│       ├── logo.swift               # SwiftUI vector logo (converted from SVG)
│       ├── logo.svg                 # Original SVG source file
│       ├── logo.png                 # PNG version for reference
│       └── logo.jpeg                # JPEG version for reference
```

### Logo Implementation

The app uses a **vector-based logo** approach for optimal performance and quality:

- **Source**: Original SVG file (`logo.svg`) converted to SwiftUI using [SVG to SwiftUI Converter](https://svg-to-swiftui.quassum.com)
- **Implementation**: Pure SwiftUI vector paths in `logo.swift` (9 KB)
- **Benefits**: 
  - Perfect scalability at any size
  - Minimal file size (no image assets)
  - Native SwiftUI rendering
  - No external dependencies
- **Source Files**: Original SVG, PNG, and JPEG files are kept in Resources for reference and future use

### Key Technologies

- **Disk Arbitration Framework** - Native macOS disk management
- **IOKit** - Hardware interface and device properties
- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming for data flow
- **CryptoKit** - SHA256 checksum generation and verification

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Open `SwiftFlash.xcodeproj` in Xcode
3. Select your target device/simulator
4. Build and run

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with ❤️ using Swift and SwiftUI
- Inspired by the need for a lightweight, native macOS flashing tool
- Thanks to the macOS Disk Arbitration framework for reliable disk management
- Special thanks to [Claude Sonnet 4](https://claude.ai) for AI-assisted development and code improvements
- Developed using [Cursor](https://cursor.sh) - the AI-first code editor

---

**SwiftFlash** - Making disk flashing simple and safe on macOS.
