# SwiftFlash Design Guidelines

## Disk Arbitration and Drive Information Architecture

### Core Principles

1. **Single Source of Truth**: All Disk Arbitration access is restricted to `DriveDetectionService` only
2. **Complete Data Capture**: The `Drive` struct should contain all necessary information from Disk Arbitration
3. **No Live Lookups**: Once a `Drive` is created, it should not need to access Disk Arbitration again
4. **Clear Separation**: Models should be data containers, services should handle system interactions

### Data Flow

```
DriveDetectionService (IOKit + Disk Arbitration)
    ↓
DeviceInfo (transient, low-level data)
    ↓
Drive (persistent, high-level model)
    ↓
UI Components (display and interaction)
```

### Disk Arbitration Access Rules

- **ONLY** `DriveDetectionService` can access Disk Arbitration APIs
- **NEVER** access Disk Arbitration from UI components or other services
- **ALWAYS** capture all needed information during initial detection
- **STORE** complete `diskDescription` dictionary in `Drive` struct for future access

### Drive Struct Requirements

The `Drive` struct must contain:

#### Essential Properties (from IOKit)
- `name`: Human-readable device name
- `mountPoint`: Device path (e.g., "/dev/disk4")
- `size`: Device size in bytes
- `isRemovable`: Whether device is removable
- `isSystemDrive`: Whether this is the system drive
- `isReadOnly`: Whether device is read-only

#### Disk Arbitration Properties (captured during detection)
- `mediaUUID`: Unique identifier for the media
- `mediaName`: Media name from Disk Arbitration
- `vendor`: Device vendor information
- `revision`: Device revision information
- `diskDescription`: Complete raw Disk Arbitration description dictionary

#### Computed Properties (derived from stored data)
- `daDeviceProtocol`: Device protocol (USB, SATA, etc.)
- `daVendor`: Vendor information (with fallback)
- `daRevision`: Revision information (with fallback)
- `daVolumeName`: Volume name (with fallback chain)
- `daVolumeKind`: Volume/filesystem type
- `daVolumePath`: Mount path as string

### Implementation Guidelines

#### In DriveDetectionService
1. **Capture Complete Data**: Get full `diskDescription` dictionary during detection
2. **Populate All Fields**: Ensure all relevant Disk Arbitration information is stored
3. **Handle Missing Data**: Provide fallbacks for optional information
4. **Log Debug Info**: Include comprehensive logging for troubleshooting

#### In Drive Model
1. **Access Stored Data Only**: Use `diskDescription` dictionary for all Disk Arbitration information
2. **Provide Convenience Methods**: Create computed properties for common access patterns
3. **Handle Missing Data**: Return `nil` gracefully when information is not available
4. **No System Calls**: Never access Disk Arbitration APIs directly

#### In UI Components
1. **Use Drive Properties**: Access information through `Drive` struct properties
2. **Handle Missing Data**: Display appropriate fallbacks when information is unavailable
3. **No Direct Access**: Never access Disk Arbitration or IOKit directly

### Benefits of This Architecture

1. **Performance**: No repeated Disk Arbitration lookups
2. **Reliability**: Consistent data throughout the application lifecycle
3. **Maintainability**: Clear separation of concerns
4. **Testability**: Models can be tested without system dependencies
5. **Thread Safety**: No concurrent access to system APIs

### Common Anti-Patterns to Avoid

- ❌ Accessing Disk Arbitration from UI components
- ❌ Creating shared utilities that access Disk Arbitration
- ❌ Performing live lookups in computed properties
- ❌ Storing incomplete information in Drive struct
- ❌ Mixing IOKit and Disk Arbitration access in models

### Testing Considerations

- Mock `Drive` objects for unit tests
- Test computed properties with various data scenarios
- Verify fallback behavior with missing information
- Ensure no system calls in model tests
