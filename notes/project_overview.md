# SwiftFlash Project Overview

## Project Description
SwiftFlash is a modern macOS application for creating bootable USB drives and flashing disk images. Built with Swift 6 and SwiftUI, it provides a user-friendly interface for device detection, image file management, and secure USB flashing operations.

## Technology Stack
- **Language**: Swift 6 (latest syntax and features)
- **UI Framework**: SwiftUI with modern APIs and patterns
- **Target Platform**: macOS 15.6+
- **Architecture**: MVVM with @Observable pattern
- **Development Environment**: Xcode with Cursor IDE integration

## Core Features
1. **Device Detection**: Automatic USB drive detection and monitoring
2. **Image File Support**: Support for various disk image formats (.img, .iso, .dmg, etc.)
3. **Flash Operations**: Secure and verified USB flashing with progress tracking
4. **Safety Mechanisms**: Multiple confirmation dialogs and safety checks
5. **History Management**: Track previous flashing operations
6. **Inspector Views**: Detailed information about drives and image files

## Architecture Overview

### Data Models (PROTECTED)
- `Drive` struct: Represents USB drives and storage devices
- `ImageFile` struct: Represents disk image files with metadata
- `DeviceInventoryItem` struct: Device inventory management
- `DeviceType` enum: Classification of device types
- `ImageFileType` enum: Supported image file formats

### Core Services (PROTECTED)
- `ImageFlashService`: Handles USB flashing operations and safety checks
- `DriveDetectionService`: Manages device detection and monitoring
- `ImageFileService`: Image file validation and metadata extraction
- `ImageHistoryService`: Tracks and manages flashing history
- `BookmarkManager`: Handles file system bookmarks and permissions

### UI Components (PROTECTED - Layout Only)
- `ContentView`: Main application interface with split view layout
- `DriveInspectorView`: Detailed drive information and controls
- `ImageInspectorView`: Image file details and validation status
- `FlashProgressView`: Progress tracking during flash operations
- `FlashConfirmationDialog`: Safety confirmation dialogs

### Utility Components
- `DropZoneView`: Drag-and-drop interface for image files
- `ToolbarButtons`: Application toolbar functionality
- `InspectorFonts`: Typography and styling utilities
- Various label and input components for consistent UI

## Key Design Principles
1. **Safety First**: Multiple confirmation steps and validation checks
2. **User Experience**: Intuitive drag-and-drop interface with clear feedback
3. **Modern Swift**: Leverage latest Swift 6 and SwiftUI features
4. **Code Reusability**: Modular components and shared utilities
5. **Apple Guidelines**: Follow HIG and official coding standards

## Protected Code Areas
The following areas are marked as CRITICAL and should NOT be modified without explicit permission:

### Data Models
- Core structure and properties of Drive, ImageFile, and DeviceInventory models
- Enum definitions and their cases

### Core Services
- Device detection logic and safety mechanisms
- Flash operation implementation and error handling
- Data persistence and bookmark management

### UI Layout Structure
- Main ScrollView and Inspector area layouts in ContentView
- App structure and scene configuration in SwiftFlashApp

## Development Workflow
1. **Research Phase**: Understand existing code and requirements
2. **Planning Phase**: Create detailed implementation plan with MECE breakdown
3. **Execution Phase**: Implement changes following the approved plan
4. **Review Phase**: Validate changes against plan and test functionality

## File Organization
```
see directory_structure.md

## Version Management
- Uses date-based release versioning (YYYY.M format)
- Build numbers auto-increment from git 
- Beta versions: "YYYY.M beta N" format
- All git commits in English

## Development Notes
- Always generate appropriate comments for files and functions
- Add comments for key implementation steps
- Reuse existing code components when possible
- Ask for clarification before making significant changes
- Stop and request support for recurring problems
