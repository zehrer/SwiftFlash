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
│   └── DeviceInventory.swift        # Device tracking
```

### Key Technologies

- **Disk Arbitration Framework** - Native macOS disk management
- **IOKit** - Hardware interface and device properties
- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming for data flow

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

---

**SwiftFlash** - Making disk flashing simple and safe on macOS.
