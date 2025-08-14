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
- **Design Principles** : 
    - **Unit**: Define features in units of functionality
    - **Services** : Services shall be used to encapsulate business logic and provide a clear separation of concerns 
    - **Model** : The model shall be used to represent the data and business logic 
    - **Incjection** : The main app shall use dependency injection to provide the services to the view models.
    - **Protocols** : Protocols shall be used to define the interface of the services and the model.
    - **Views** : Views shall be defined as generic as possible to be reused as much as possible.
    - **ViewModels** : ViewModels shall be used to provide the data and business logic to the views (optional)
    - **Coordinators** : Coordinators shall be used to manage the flow of the application (TODO)
    - **Error Handling** : Error handling shall be implemented to provide a good user experience.
    - **Localization** : Localization shall be implemented to support multiple languages (TODO)
    - **Testing** : Unit tests shall be implemented to ensure the quality of the code.
    - **Modules** : The app shall be divided into modules to improve maintainability and scalability (TODO)
    - **Mockup** : Modules shall provide mockups to test the functionality of the app. 
    


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

## Unit Testing & Dependency Injection

### SwiftUI App Initialization During Unit Tests

**Important Note**: When running unit tests in SwiftUI applications, the entire app initialization process is triggered, including the main `@main` struct and all associated services. This behavior is **normal** for SwiftUI apps but differs from traditional unit testing expectations.

#### Why This Happens

<mcreference link="https://www.steveclarkapps.com/unit-testing-tdd-in-swift/" index="1">1</mcreference> SwiftUI's testing framework initializes the complete application context, which means:
- The main `SwiftFlashApp` struct is instantiated
- `AppModel` and all its dependencies are created
- Services like `DriveDetectionService` are initialized with real system resources
- Debug logging from app initialization appears in test output

#### Current Behavior in SwiftFlash

When running `testDetectDrivesExcludesDiskImages`, you'll see:
```
🚀 [DEBUG] SwiftFlash App Starting
🔍 [DEBUG] Found X external storage devices
🔍 [DEBUG] Checking device...
```

This occurs because:
1. `SwiftFlashApp.init()` prints the startup message
2. `AppModel` initializes `DriveDetectionService`
3. `DriveDetectionService.detectDrives()` performs real IOKit operations with debug logging

### Best Practices for Unit Testing

#### 1. Dependency Injection Patterns

<mcreference link="https://www.avanderlee.com/swift/dependency-injection/" index="2">2</mcreference> <mcreference link="https://swdevnotes.com/swift/2022/use-dependency-injection-to-unit-test-a-viewmodel-in-swift/" index="5">5</mcreference> To achieve proper unit testing isolation:

**Protocol-Based Abstraction**:
```swift
protocol DriveDetectionProtocol {
    func detectDrives() async throws -> [Drive]
}

class DriveDetectionService: DriveDetectionProtocol {
    // Real implementation using IOKit
}

class MockDriveDetectionService: DriveDetectionProtocol {
    // Mock implementation for testing
}
```

**Dependency Injection in Services**:
```swift
class AppModel: ObservableObject {
    private let driveDetection: DriveDetectionProtocol
    
    init(driveDetection: DriveDetectionProtocol = DriveDetectionService()) {
        self.driveDetection = driveDetection
    }
}
```

#### 2. SwiftUI Environment-Based Injection

<mcreference link="https://mokacoding.com/blog/swiftui-dependency-injection/" index="4">4</mcreference> For SwiftUI views, use `@EnvironmentObject` for clean dependency injection:

```swift
@main
struct SwiftFlashApp: App {
    let appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
    }
}
```

#### 3. Conditional App Initialization

<mcreference link="https://www.steveclarkapps.com/unit-testing-tdd-in-swift/" index="1">1</mcreference> To prevent full app initialization during tests:

```swift
@main
struct SwiftFlashApp: App {
    var body: some Scene {
        WindowGroup {
            // Only initialize full app when not running tests
            if NSClassFromString("XCTestCase") == nil {
                ContentView()
                    .environmentObject(AppModel())
            } else {
                Text("Test Mode")
            }
        }
    }
}
```

#### 4. Async/Await Testing Patterns

<mcreference link="https://www.swiftbysundell.com/articles/dependency-injection-and-unit-testing-using-async-await/" index="3">3</mcreference> For testing async operations without complex mocking:

```swift
class ProductLoader {
    private let loadProduct: (Product.ID) async throws -> Product
    
    init(loadProduct: @escaping (Product.ID) async throws -> Product = Self.defaultLoadProduct) {
        self.loadProduct = loadProduct
    }
    
    func load(id: Product.ID) async throws -> Product {
        try await loadProduct(id)
    }
}
```

### Hardware-Dependent Tests

For tests that require real hardware interaction (like `testDetectDrivesExcludesDiskImages`):

1. **Environment Gating**: Use `SWIFTFLASH_HW_TESTS=1` to control execution
2. **Clear Documentation**: Mark tests as hardware-dependent
3. **Separate Test Targets**: Consider separate targets for unit vs. integration tests
4. **CI/CD Considerations**: Hardware tests may need special runners

### Testing Strategy Recommendations

1. **Pure Unit Tests**: Test business logic with mocked dependencies
2. **Integration Tests**: Test service interactions with real or stubbed backends
3. **Hardware Tests**: Test actual device detection and interaction
4. **UI Tests**: Test complete user workflows

### Future Improvements

- Implement dependency injection container
- Create mock implementations for all external services
- Add conditional compilation flags for test vs. production builds
- Consider using a logging framework with configurable levels
- Separate unit tests from integration/hardware tests

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

