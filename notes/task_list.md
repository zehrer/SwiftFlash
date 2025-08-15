# SwiftFlash Task List

## TODO

- IOMediaWhole for detaction of device vs partion
- Store partion informationin DeviceInfo (List of partion info as far as avaible )
- support `.img` - Raw disk images (TODO testing)
- Other raw disk image formats (TODO testing)
- Image Repository 
    - local folder storing all images
    - list of external repositories 
    - list of URLs for each repositories public images for download
    - check new publications of images 
    - search from images
    - AI support to search for images (MacOS 26)
- write Unit tests and HMI test cases :)
- change build number based on tagged releases (git describe --tags --long)
- improve usage of Disk Arbitration Framework 
    - use it for mount and unmount
    - replace all key strings by the dedicated string const (e.g. kDADiskDescriptionDeviceVendorKey")
- add log view within the app itself (include related log leven / menu / icon / filter ...) and build a os.Logger wrapper
- Add quality code indicators (including test code coverage)
- Fix / reduce Waning during startup in BookmarkManager
- Add F3 / F3XSwift / Fight Flash Fraud check (TODO)

## High Priority Tasks

### Active Development
- [x] **SMART Requirements Specification Created** 
  - **Status**: Complete
  - **Assigned To**: Claude
  - **Notes**: Created comprehensive technical requirements document with SMART criteria
  - **Priority**: High
  - **Files**: `notes/requirements_specification.md`

### Core Functionality Maintenance
- [ ] **Monitor Protected Code Sections**
  - **Status**: Ongoing
  - **Description**: Ensure no unauthorized modifications to CRITICAL sections
  - **Files**: All protected models and services
  - **Priority**: Critical

## Medium Priority Tasks

### UI/UX Improvements
- [ ] **Enhance User Feedback**
  - **Status**: To Do
  - **Description**: Improve visual feedback during operations
  - **Files**: Progress views, confirmation dialogs
  - **Priority**: Medium

- [ ] **Accessibility Improvements**
  - **Status**: To Do
  - **Description**: Ensure proper VoiceOver and accessibility support
  - **Files**: All UI components
  - **Priority**: Medium

### Code Quality
- [ ] **Documentation Updates**
  - **Status**: To Do
  - **Description**: Ensure all functions have appropriate comments
  - **Files**: All source files
  - **Priority**: Medium

## Low Priority Tasks

### Future Enhancements
- [ ] **Additional Image Format Support**
  - **Status**: To Do
  - **Description**: Research and implement support for more image formats
  - **Files**: ImageFileService, ImageFileModel
  - **Priority**: Low

- [ ] **Performance Optimization**
  - **Status**: To Do
  - **Description**: Profile and optimize performance bottlenecks
  - **Files**: Core services
  - **Priority**: Low

## Completed Tasks

### Project Setup
- [x] **Initial Project Structure**
  - **Completed**: Project creation date
  - **Description**: Basic SwiftUI app structure with core models
  
- [x] **Protection System Implementation**
  - **Completed**: As per cursor rules
  - **Description**: Implemented code protection markers and safety guidelines

## Task Categories

### 🔒 Protected Areas (Require Permission)
Tasks that involve modifying protected code sections:
- Data model structure changes
- Core service logic modifications  
- Main UI layout alterations
- Safety mechanism updates

### ✅ Safe Areas (Can Modify Freely)
Tasks that involve non-protected areas:
- Adding new utility functions
- Creating new UI components (non-layout)
- Documentation improvements
- Adding comments and explanations

### 🔍 Research Tasks
Tasks focused on understanding and analysis:
- Code review and analysis
- Architecture documentation
- Performance profiling
- User experience research

## Development Workflow

### For New Tasks:
1. **Research Phase**: Understand requirements and existing code
2. **Planning Phase**: Create MECE breakdown with detailed steps
3. **Permission Check**: Verify if protected areas are involved
4. **Execution Phase**: Implement according to approved plan
5. **Review Phase**: Validate implementation against requirements

### Task Status Definitions:
- **Pending**: Awaiting assignment or clarification
- **In Progress**: Currently being worked on
- **Blocked**: Waiting for external dependency or permission
- **Review**: Completed, awaiting validation
- **Complete**: Finished and validated

## Notes
- Always check protection markers before starting any task
- Update this list regularly as tasks are completed or new ones are identified
- Use MECE principle for breaking down complex tasks
- Maintain clear communication about task progress and blockers
