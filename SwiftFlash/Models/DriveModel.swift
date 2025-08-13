//
//  DriveModel.swift
//  SwiftFlash
//
//  Deprecated: Drive model has been merged into Device.
//  This file no longer defines the Drive alias.
//  Use `Device` everywhere going forward.
//
//  Notes for compatibility:
//  - Drive.mountPoint    → Device.devicePath (alias `mountPoint` exists on Device)
//  - Drive.un/mountDevice → Device.un/mountDevice (identical API)
//  - Drive.displayName   → Device.displayName
//  - Drive.formattedSize → Device.formattedSize
//  - Drive.da* accessors → Device.da* accessors
//  - Drive.partitionScheme/Display → Device.partitionScheme/partitionSchemeDisplay
//  - Drive.deviceType    → Device.deviceType
//
//  If needed, define `typealias Drive = Device` near the Device declaration.
//

import Foundation
