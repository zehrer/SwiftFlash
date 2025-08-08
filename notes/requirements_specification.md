# SwiftFlash Technical Requirements Specification

## Overview
This document defines SMART (Specific, Measurable, Achievable, Relevant, Time-bound) technical requirements for all SwiftFlash components, organized by architectural layer.

## Document Structure
- **FR-XXX**: Functional Requirements
- **NFR-XXX**: Non-Functional Requirements  
- **API-XXX**: API/Interface Requirements
- **UI-XXX**: User Interface Requirements
- **DATA-XXX**: Data Model Requirements

---

## 1. Data Models Requirements

### 1.1 Drive Model (PROTECTED)
**File**: `SwiftFlash/DriveModel.swift`

#### DATA-001: Drive Structure Requirements
**Requirement**: Drive struct MUST contain all required properties for external drive representation
- **Properties Required**:
  - `id: UUID` - Unique identifier (auto-generated)
  - `name: String` - Display name from system (currently called customName)
  - `mountPoint: String` - File system mount path
  - `size: Int64` - Total capacity in bytes
  - `isRemovable: Bool` - System removable flag
  - `isSystemDrive: Bool` - Internal drive protection flag
  - `isReadOnly: Bool` - Write protection status
  - `mediaUUID: String?` - Hardware UUID for tracking  (custom identifyer TODO improve: risk for duplicates )
  - `mediaName: String?` - DAMediaName from Disk Arbitration 
  - `vendor: String?` - Device manufacturer
  - `revision: String?` - Firmware/hardware revision
  - `deviceType: DeviceType` - Classification (USB, SD, etc.)  (see DeviceType Enum)
  - `partitionScheme: PartitionScheme` - MBR/GPT detection

#### DATA-002: Drive Computed Properties
**Requirement**: Drive MUST provide formatted display properties
- `formattedSize: String` - Human-readable size (GB/MB)
- `displayName: String` - Safe display name with fallback
- `partitionSchemeDisplay: String` - User-friendly scheme description

#### DATA-003: Drive Safety Methods
**Requirement**: Drive MUST provide safety validation methods
- `unmountDevice() -> Bool` - Safely unmount before operations
- Hash/Equality based on `mountPoint` for Set operations
- MUST restrict operations to external drives only (`isSystemDrive == false`)

#### DATA-004: Drive Validation Rules
**Requirement**: Drive validation MUST enforce safety constraints
```swift
// REQUIRED validation logic
func isValidForFlashing() -> Bool {
    return !isSystemDrive && isRemovable && !isReadOnly
}

func requiresUnmount() -> Bool {
    return !mountPoint.isEmpty
}
```

### 1.2 ImageFile Model (PROTECTED)
**File**: `SwiftFlash/ImageFileModel.swift`

#### DATA-005: ImageFile Structure Requirements
**Requirement**: ImageFile struct MUST support secure file operations
- **Properties Required**:
  - `id: UUID` - Unique identifier
  - `name: String` - File name
  - `path: String` - File system path
  - `size: Int64` - File size in bytes
  - `fileType: ImageFileType` - Format classification
  - `sha256Checksum: String?` - Integrity verification
  - `bookmarkData: Data?` - Security-scoped bookmark

#### DATA-006: ImageFile Security Requirements
**Requirement**: ImageFile MUST provide secure file access
```swift
// REQUIRED method signature
func getSecureURL() throws -> URL
// MUST use bookmarkData when available
// MUST fallback to path-based URL
// MUST throw SecurityError for access failures
```

#### DATA-007: ImageFile Validation Requirements
**Requirement**: ImageFile MUST validate file integrity and compatibility
- `partitionScheme: PartitionScheme` - Computed property for scheme detection
- `checksumStatus: String` - Display-friendly checksum info
- `formattedSize: String` - Human-readable file size

### 1.3 DeviceInventory Model (PROTECTED)
**File**: `SwiftFlash/DeviceInventory.swift`

#### DATA-008: DeviceType Enum Requirements
**Requirement**: DeviceType MUST classify all supported external devices
```swift
// REQUIRED cases (DO NOT MODIFY)
enum DeviceType: String, CaseIterable, Codable {
    case usbStick = "USB Stick"
    case sdCard = "SD Card"
    case microSDCard = "microSD Card"
    case externalHDD = "external HDD"
    case externalSSD = "external SSD"
    case unknown = "unknown"
}
```

#### DATA-009: DeviceType Icon Mapping
**Requirement**: DeviceType MUST provide SF Symbol icons
- `usbStick` → `"mediastick"` (user preference)
- `sdCard` → `"sdcard"`
- `microSDCard` → `"sdcard.fill"`
- `externalHDD/SSD` → `"externaldrive.fill"`
- `unknown` → `"questionmark.circle"`

#### DATA-010: DeviceInventoryItem Structure
**Requirement**: DeviceInventoryItem MUST track device history and metadata
- **Required Properties**: `mediaUUID`, `size`, `originalName`, `firstSeen`, `lastSeen`
- **Optional Properties**: `customName`, `deviceType`, `vendor`, `revision`
- **Display Logic**: `displayName` returns `customName ?? originalName`

---

## 2. Core Services Requirements

### 2.1 DriveDetectionService (PROTECTED)
**File**: `SwiftFlash/DriveDetectionService.swift`

#### FR-001: Device Detection Requirements
**Requirement**: Service MUST detect and monitor external drives in real-time
- **Detection Method**: IOKit-based hardware enumeration
- **Update Frequency**: Real-time via Disk Arbitration callbacks
- **Filtering**: MUST exclude internal/system drives
- **Performance**: Detection updates < 100ms response time

#### API-001: DriveDetectionService Interface
**Required Methods**:
```swift
@Observable
class DriveDetectionService {
    // REQUIRED properties
    var availableDrives: [Drive] { get }
    var selectedDrive: Drive? { get set }
    
    // REQUIRED methods
    func startMonitoring() throws
    func stopMonitoring()
    func refreshDrives() async
    func validateDriveForFlashing(_ drive: Drive) -> ValidationResult
}
```

#### NFR-001: Detection Performance Requirements
- **Startup Time**: Initial drive scan < 500ms
- **Memory Usage**: < 10MB for drive monitoring
- **CPU Usage**: < 5% during idle monitoring
- **Reliability**: 99.9% detection accuracy for supported devices

### 2.2 ImageFlashService (PROTECTED)
**File**: `SwiftFlash/ImageFlashService.swift`

#### FR-002: Flash Operation Requirements
**Requirement**: Service MUST safely flash image files to external drives
- **Safety Checks**: Pre-flight validation of drive and image
- **Progress Tracking**: Real-time progress with ETA calculation
- **Verification**: Post-flash integrity verification
- **Error Recovery**: Graceful handling of interruptions

#### API-002: ImageFlashService Interface
**Required Methods**:
```swift
@Observable
class ImageFlashService {
    // REQUIRED properties
    var isFlashing: Bool { get }
    var progress: FlashProgress { get }
    var currentOperation: FlashOperation? { get }
    
    // REQUIRED methods
    func flashImage(_ image: ImageFile, to drive: Drive) async throws -> FlashResult
    func cancelFlashing() async
    func validateCompatibility(_ image: ImageFile, _ drive: Drive) -> CompatibilityResult
}
```

#### NFR-002: Flash Performance Requirements
- **Write Speed**: Optimal for device capabilities (no artificial limits)
- **Progress Updates**: Every 1% or 10MB, whichever is smaller
- **Cancellation**: < 5 seconds to safely abort operation
- **Verification**: SHA256 checksum validation (optional, user-configurable)

### 2.3 ImageFileService (PROTECTED)
**File**: `SwiftFlash/ImageFileService.swift`

#### FR-003: Image File Validation Requirements
**Requirement**: Service MUST validate and analyze image files
- **Format Support**: .img, .iso, .dmg, .raw formats
- **Metadata Extraction**: Size, checksum, partition scheme detection
- **Integrity Checks**: File corruption detection
- **Compatibility**: Drive size and format compatibility

#### API-003: ImageFileService Interface
**Required Methods**:
```swift
class ImageFileService {
    // REQUIRED methods
    static func validateImageFile(at url: URL) async throws -> ImageFile
    static func calculateChecksum(for imageFile: ImageFile) async throws -> String
    static func detectPartitionScheme(for imageFile: ImageFile) -> PartitionScheme
    static func estimateFlashTime(_ image: ImageFile, to drive: Drive) -> TimeInterval
}
```

### 2.4 ImageHistoryService (PROTECTED)
**File**: `SwiftFlash/ImageHistoryService.swift`

#### FR-004: History Management Requirements
**Requirement**: Service MUST track flash operations for user reference
- **Persistence**: Core Data or UserDefaults-based storage
- **Data Retention**: Configurable history limit (default: 100 operations)
- **Search/Filter**: By date, drive, image, or status
- **Privacy**: No sensitive data in history logs

#### API-004: ImageHistoryService Interface
**Required Methods**:
```swift
@Observable
class ImageHistoryService {
    var flashHistory: [FlashHistoryEntry] { get }
    
    func addHistoryEntry(_ entry: FlashHistoryEntry)
    func clearHistory()
    func exportHistory() throws -> URL
    func searchHistory(query: String) -> [FlashHistoryEntry]
}
```

---

## 3. User Interface Requirements

### 3.1 ContentView (PROTECTED Layout)
**File**: `SwiftFlash/ContentView.swift`

#### UI-001: Main Layout Requirements
**Requirement**: ContentView MUST provide efficient split-view interface
- **Layout**: NavigationSplitView with sidebar and detail areas
- **Responsive**: Adapt to window resizing (min 800x600)
- **State Management**: @Observable pattern for reactive updates
- **Accessibility**: Full VoiceOver support (future requirement)

#### UI-002: Navigation Structure
**Required Components**:
```swift
NavigationSplitView {
    // Sidebar: Drive list and image selection
    DriveListView()
    ImageSelectionView()
} detail: {
    // Detail: Inspector views and controls
    if selectedDrive != nil {
        DriveInspectorView()
    }
    if selectedImage != nil {
        ImageInspectorView()
    }
}
```

### 3.2 Inspector Views
**Files**: `SwiftFlash/DriveInspectorView.swift`, `SwiftFlash/ImageInspectorView.swift`

#### UI-003: DriveInspectorView Requirements
**Requirement**: MUST display comprehensive drive information and controls
- **Information Display**: Name, size, type, partition scheme, vendor info
- **Safety Indicators**: System drive warning, read-only status
- **Actions**: Unmount, refresh, flash controls
- **Real-time Updates**: Reflect drive state changes immediately

#### UI-004: ImageInspectorView Requirements
**Requirement**: MUST display image file details and validation status
- **File Information**: Name, size, type, path, checksum
- **Validation Status**: Integrity check results, compatibility warnings
- **Actions**: Checksum calculation, file selection, flash initiation
- **Progress Display**: Checksum calculation progress

### 3.3 Progress and Feedback
**Files**: `SwiftFlash/FlashProgressView.swift`, `SwiftFlash/FlashConfirmationDialog.swift`

#### UI-005: Flash Progress Requirements
**Requirement**: MUST provide clear, real-time operation feedback
- **Progress Indicators**: Percentage, data transferred, ETA, speed
- **Visual Design**: Progress bar, animated indicators
- **Controls**: Cancel button with confirmation
- **Status Messages**: Current operation phase description

#### UI-006: Confirmation Dialog Requirements
**Requirement**: MUST prevent accidental data loss through clear confirmations
- **Warning Content**: Drive name, data loss warning, operation summary
- **Confirmation Steps**: Two-step confirmation for destructive operations
- **Visual Design**: Clear warning icons and danger styling
- **Accessibility**: Screen reader friendly descriptions

---

## 4. Integration Requirements

### 4.1 System Integration
**Files**: Various service files

#### FR-005: macOS Integration Requirements
**Requirement**: App MUST integrate properly with macOS system services
- **Disk Arbitration**: Real-time mount/unmount notifications
- **IOKit**: Hardware device enumeration and properties
- **Security**: Sandbox compliance, no privileged operations
- **Permissions**: Request file access permissions as needed

#### NFR-003: System Resource Requirements
- **Memory**: < 50MB baseline, < 200MB during flash operations
- **CPU**: < 10% during idle, < 30% during active operations
- **Disk I/O**: Optimal throughput without system impact
- **Network**: No network access required for core functionality

### 4.2 Error Handling Requirements
**Files**: All service and view files

#### FR-006: Error Handling Requirements
**Requirement**: MUST provide comprehensive error handling and recovery
- **Error Categories**: Critical, Recoverable, Warning, Info
- **User Communication**: Clear, actionable error messages
- **Recovery Options**: Automatic retry, manual intervention, safe fallbacks
- **Logging**: Debug logs for troubleshooting (no sensitive data)

#### API-005: Error Types Definition
**Required Error Types**:
```swift
enum SwiftFlashError: LocalizedError {
    case driveNotFound
    case driveNotRemovable
    case imageFileCorrupted
    case insufficientSpace
    case operationCancelled
    case systemPermissionDenied
    case hardwareError(String)
    
    var errorDescription: String? { /* User-friendly messages */ }
    var recoverySuggestion: String? { /* Actionable recovery steps */ }
}
```

---

## 5. Quality Assurance Requirements

### 5.1 Code Quality Standards

#### NFR-004: Swift 6 Compliance
**Requirement**: ALL code MUST use Swift 6 latest syntax and features
- **Concurrency**: async/await for all asynchronous operations
- **State Management**: @Observable instead of ObservableObject
- **Type Safety**: Strict typing, no force unwrapping in production code
- **Documentation**: Comprehensive doc comments for all public APIs

#### NFR-005: Testing Requirements
**Requirement**: Core functionality MUST have test coverage
- **Unit Tests**: All service classes and data models
- **Integration Tests**: Device detection and flash operations (mocked)
- **UI Tests**: Critical user workflows
- **Coverage Target**: > 80% for protected/critical components

### 5.2 Performance Standards

#### NFR-006: Response Time Requirements
- **UI Responsiveness**: < 16ms for smooth 60fps interactions
- **Drive Detection**: < 500ms initial scan, < 100ms updates
- **File Validation**: < 2 seconds for files up to 4GB
- **Flash Operations**: Optimal speed for hardware capabilities

#### NFR-007: Reliability Requirements
- **Crash Rate**: < 0.1% of operations
- **Data Integrity**: 100% for completed flash operations
- **Operation Success**: > 99% for valid drive/image combinations
- **Recovery**: Graceful handling of 95% of error conditions

---

## 6. Implementation Guidelines

### 6.1 Development Workflow
1. **Requirements Review**: Validate requirement against this document
2. **Design Approval**: Get approval for protected component changes
3. **Implementation**: Follow Swift 6 and SwiftUI best practices
4. **Testing**: Validate against requirements and quality standards
5. **Documentation**: Update requirements if changes are necessary

### 6.2 Change Management
- **Protected Components**: Require explicit approval before modification
- **API Changes**: Update this document before implementation
- **New Features**: Add requirements before development
- **Bug Fixes**: Verify fix meets original requirements

### 6.3 Validation Checklist
For each component implementation:
- [ ] Meets all SMART requirements defined above
- [ ] Follows Swift 6 syntax and modern patterns
- [ ] Includes comprehensive error handling
- [ ] Provides appropriate user feedback
- [ ] Maintains data safety and integrity
- [ ] Includes proper documentation
- [ ] Passes performance benchmarks
- [ ] Respects protection markers and safety constraints

---

## Document Maintenance
- **Last Updated**: [Current Date]
- **Version**: 1.0
- **Next Review**: When significant architectural changes are proposed
- **Owner**: SwiftFlash Development Team

This document serves as the single source of truth for all technical requirements. Any implementation MUST conform to these specifications unless explicitly approved changes are made to this document first.
