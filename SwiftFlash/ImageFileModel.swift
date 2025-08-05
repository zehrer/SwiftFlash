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
    var sha256Checksum: String?
    var bookmarkData: Data? // Added for security-scoped bookmark support
    
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
    
    var checksumStatus: String {
        if let checksum = sha256Checksum {
            return "SHA256: \(checksum.prefix(8))..."
        } else {
            return "No checksum available"
        }
    }
    
    /// Computed property to get partition scheme (MBR/GPT) for this image file
    var partitionScheme: ImageFileService.PartitionScheme {
        return ImageFileService.PartitionSchemeDetector.detectPartitionScheme(fileURL: URL(fileURLWithPath: path))
    }
    
    /// Formatted partition scheme display string
    var partitionSchemeDisplay: String {
        switch partitionScheme {
        case .mbr:
            return "MBR (Master Boot Record)"
        case .gpt:
            return "GPT (GUID Partition Table)"
        case .unknown:
            return "Unknown"
        }
    }
    
    /// Get a secure URL using bookmark data if available, otherwise fall back to path
    func getSecureURL() throws -> URL {
        if let bookmarkData = bookmarkData {
            return try BookmarkManager.shared.getSecureURL(from: bookmarkData)
        } else {
            // Fallback to direct path access (for backward compatibility)
            return URL(fileURLWithPath: path)
        }
    }
    
    /// Stop accessing the security-scoped resource
    func stopAccessingSecureResource() {
        if let bookmarkData = bookmarkData {
            do {
                let url = try BookmarkManager.shared.resolveBookmark(bookmarkData)
                BookmarkManager.shared.stopAccessing(url)
            } catch {
                print("⚠️ [DEBUG] Failed to stop accessing secure resource: \(error)")
            }
        }
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