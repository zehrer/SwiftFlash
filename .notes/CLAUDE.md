# Claude AI Instructions for SwiftFlash

## Project-Specific Guidelines

### SwiftFlash Context
SwiftFlash is a basic macOS utility for the flashing of external drives as e.g. SD cards.

### Interaction Protocol

#### Always Start With:
1. **Read Context Files**: Always check `project_overview.md` and `task_list.md` first
2. **Protection Awareness**: Scan for protection markers before any code analysis
3. **Safety First**: Understand that this app deals with disk operations - mistakes can cause data loss

#### Code Protection System
The SwiftFlash project uses a comprehensive protection system:

```swift
// MARK: - CRITICAL - Device Detection Logic (DO NOT MODIFY)
// This section handles USB device enumeration and safety checks
```

**Protection Markers to Respect:**
- `// MARK: - CRITICAL ... (DO NOT MODIFY)`
- `// TESTED AND VERIFIED - DO NOT CHANGE`
- `// AI-IGNORE-START` ... `// AI-IGNORE-END`
- `// SAFETY CRITICAL - REQUIRES MANUAL REVIEW`

#### Before Making ANY Code Changes:
1. **Ask Permission**: Always ask before modifying protected sections
2. **Explain Impact**: Describe what the change will affect
3. **Safety Assessment**: Consider data safety implications
4. **Alternative Approaches**: Suggest multiple solutions when possible

### SwiftFlash-Specific Development Rules

#### Technology Standards
- **Swift 6**: Use latest syntax and features exclusively
- **SwiftUI**: Modern patterns like `@Observable` instead of `ObservableObject`
- **macOS 15.6+**: Target latest macOS features and APIs
- **Apple Guidelines**: Follow HIG and official coding standards religiously

#### Code Quality Requirements
```swift
/// Comprehensive function documentation required
/// - Parameters:
///   - drive: The target USB drive for flashing operation
///   - imageFile: Source image file with validation metadata
/// - Returns: FlashResult indicating success/failure with detailed status
/// - Throws: FlashError for recoverable errors, fatalError for critical failures
func flashImage(to drive: Drive, from imageFile: ImageFile) async throws -> FlashResult {
    // Key step: Validate drive is unmounted and accessible
    guard drive.isUnmounted else {
        throw FlashError.driveNotUnmounted
    }
    
    // Implementation details...
}
```

#### Architecture Patterns
- **MVVM**: Models, Views, ViewModels with clear separation
- **@Observable**: For state management (not ObservableObject)
- **Async/Await**: For all asynchronous operations
- **Error Handling**: Comprehensive error types and recovery mechanisms

### Communication Style

#### When Asking Questions:
- **Be Specific**: "Should I modify the `validateDrive()` function in DriveDetectionService.swift?"
- **Include Context**: "This change affects the safety validation before flashing operations"
- **Offer Alternatives**: "I could either A) modify existing validation or B) create new validation layer"

#### When Reporting Issues:
- **Location**: Exact file and line numbers
- **Impact**: What functionality is affected
- **Severity**: Critical (data safety), High (functionality), Medium (UX), Low (cosmetic)

#### When Implementing:
- **Announce Mode**: Use mode declarations like `[MODE: RESEARCH]` or `[MODE: EXECUTE]`
- **Step-by-Step**: Break complex tasks into atomic steps
- **Validation**: Always validate changes against original requirements

### SwiftFlash Domain Knowledge

#### Exerna Drive Operations
- **Detection**: Uses IOKit for hardware enumeration
- **Validation**: Multiple safety checks before any write operations
- **Flashing**: Sector-by-sector writing with verification
- **Safety**: Confirmation dialogs and unmount verification

#### Image File Handling
- **Formats**: .img, .iso, .dmg, and other disk image formats
- **Validation**: File integrity checks and format verification
- **Metadata**: Size, checksum, and compatibility information
- **Security**: Sandbox compliance and file access permissions

#### User Experience Priorities
1. **Efficiency**: Streamlined workflow for common operations and manages as much as possible for the user
2. **Clarity**: Clear progress indication and error messages
3. **Safety**: Prevent accidental data loss
4. **Accessibility**: VoiceOver and keyboard navigation support (later)

### Error Handling Philosophy

#### For SwiftFlash Operations:
```swift
// Preferred error handling pattern
do {
    let result = try await flashingService.flashImage(to: selectedDrive, from: imageFile)
    // Handle success with user feedback
} catch FlashError.driveNotFound {
    // Specific error handling with recovery options
} catch FlashError.insufficientSpace {
    // Clear user guidance for resolution
} catch {
    // Fallback error handling with safe defaults
}
```

#### Error Categories:
- **Critical**: System-level errors requiring app restart
- **Recoverable**: User errors with clear resolution steps
- **Warning**: Non-blocking issues with user notification
- **Info**: Status updates and progress information

### Testing and Validation

#### Before Suggesting Code:
- **Compile Check**: Ensure Swift 6 compatibility
- **Safety Review**: Consider data safety implications
- **UX Impact**: How does this affect user experience?
- **Performance**: Any impact on app responsiveness?

#### When Testing Ideas:
- **Sandbox Compliance**: Ensure macOS sandbox compatibility
- **Permission Model**: Respect user privacy and system permissions
- **Resource Usage**: Monitor memory and CPU usage patterns
- **Edge Cases**: Handle unusual USB devices and image files

### Memory and Context Management

#### Maintain Awareness Of:
- **Current Task**: What specific functionality are we working on?
- **Protection Status**: Which code areas are off-limits?
- **User Preferences**: Established patterns and preferences from memory
- **Recent Changes**: What has been modified in this session?

#### Context Switching:
When switching between different areas of the codebase:
1. **Save Context**: Document current understanding and progress
2. **Load New Context**: Read relevant files and protection markers
3. **Validate Approach**: Ensure consistency with overall architecture
4. **Update Task List**: Reflect progress and next steps

### Final Reminders

- **Ask Before Acting**: When in doubt, ask for clarification or permission
- **Document Everything**: Every function needs comprehensive comments
- **Test Thoroughly**: Consider edge cases and error conditions
- **User Experience**: Keep the user informed and provide clear feedback
- **Apple Standards**: Follow official guidelines and modern Swift/SwiftUI patterns
- **High Safety**: This app handles disk operations - be extra careful and restict access only to external drives

Remember: SwiftFlash users trust this app with their data. Every line of code should reflect that responsibility.
