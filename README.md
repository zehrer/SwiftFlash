# SwiftFlash

**SwiftFlash** is a lightweight, native macOS application for flashing `.iso` file to a external drive . Built with SwiftUI and Swift 6, SwiftFlash aims to be a minimal, safe, and open-source alternative to tools like balenaEtcher or Raspberry Pi Imager.

⚡️ **Simple. Safe. Swift.**

## Key Features

- 🖥️ **Native macOS Interface** - Built with SwiftUI for seamless integration and a very small app size (just around 4MB)
- 📁 **Drag & Drop Support** - Simply drag your image file onto the app
- 💾 **Device Inventory** - Tracks and remembers your external drives (e.g. USB sticks, SD Cards ...)
    - The app provide and inventory of all externale devices and the user can define a name and a type.
    - A automatic type detection is for the moment not possibe as related informaton are missing. 
     **SHA256 Checksum** - Generate and store integrity checksums
- **LocalAuthentication** to provide access to root rights (flash is only possible under root)


## Supported File Formats

- `.iso` - ISO disk images

## System Requirements

- **macOS**: 15.6 or later
- **Architecture**: Apple Silicon (ARM64) or Intel (x86_64)


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

1. **Select Image File** - Drag and drop your image file, or use the file picker 
3. **Choose Target Drive** - Select the external drive from the list of available drives
5. **Start Flashing** - Click "Flash", confirm  and wait for completion 

⚠️ **Warning**: Flashing will erase all data on the target drive, therefore this requires root rights. 

## SHA256 Checksum Verification

SwiftFlash includes built-in SHA256 checksum functionality to ensure file integrity and verify downloaded images.

## Safety Features

- **Sandboxing**: Sandboxing is for the moment disabled as the access to flash drive require root rights. 
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

see [Structure](notes/directory_structure.md)

### Versioning

SwiftFlash uses a **date-based versioning scheme** with automated build number generation based on git.  

see [Versioning](notes/Versioning.md) for more.  


### Key Technologies

- **Disk Arbitration Framework** - Native macOS disk management
- **IOKit** - Hardware interface and device properties
- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive programming for data flow
- **CryptoKit** - SHA256 checksum generation and verification


### Development Setup

1. Clone the repository
2. Open `SwiftFlash.xcodeproj` in Xcode
3. Select your target device/simulator
4. Build and run

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) (LICENSE) file for details.

## Acknowledgments

- Built with ❤️ using Swift and SwiftUI
- Inspired by the need for a lightweight, native macOS flashing tool
- Thanks to the macOS Disk Arbitration framework for reliable disk management
- Special thanks to [Claude Sonnet 4](https://claude.ai) for AI-assisted development and code improvements
- Developed using [Cursor](https://cursor.sh) - the AI-first code editor

---

**SwiftFlash** - Making disk flashing simple and safe on macOS.

