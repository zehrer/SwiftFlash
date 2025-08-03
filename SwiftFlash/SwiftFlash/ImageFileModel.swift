//
//  ImageFileModel.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation

// MARK: - CRITICAL DATA MODEL (DO NOT MODIFY - Core image data structure)
// This ImageFile model is used for image file handling, drag & drop, and flash operations.
// Changes here will affect image processing, UI display, and file operations.
// Any modifications require testing of image handling functionality.
struct ImageFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let fileType: ImageFileType
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var displayName: String {
        if name.isEmpty {
            return "Unknown Image"
        }
        return name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }
    
    static func == (lhs: ImageFile, rhs: ImageFile) -> Bool {
        return lhs.path == rhs.path
    }
    
    // Demo image for testing
    static let demoImage = ImageFile(
        name: "Ubuntu 22.04 LTS.iso",
        path: "/Users/demo/Downloads/ubuntu-22.04.iso",
        size: 4_500_000_000, // 4.5 GB
        fileType: .iso
    )
}
// END: CRITICAL DATA MODEL

// MARK: - CRITICAL ENUM (DO NOT MODIFY - File type definitions)
// This enum defines supported image file types and is used for validation.
// Changes here affect file type detection and validation logic.
enum ImageFileType: String, CaseIterable, Codable {
    case img = "img"
    case iso = "iso"
    case dmg = "dmg"
    case unknown = "unknown"
    
    var displayName: String {
        return self.rawValue.uppercased()
    }
    
    var fileExtension: String {
        return ".\(self.rawValue)"
    }
    
    static func fromFileExtension(_ extension: String) -> ImageFileType? {
        let cleanExtension = `extension`.lowercased().replacingOccurrences(of: ".", with: "")
        return ImageFileType(rawValue: cleanExtension) ?? .unknown
    }
}
// END: CRITICAL ENUM 