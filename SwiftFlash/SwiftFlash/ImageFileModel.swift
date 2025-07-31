//
//  ImageFileModel.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation

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
}

enum ImageFileType: String, CaseIterable {
    case img = "img"
    case iso = "iso"
    
    var displayName: String {
        return self.rawValue.uppercased()
    }
    
    var fileExtension: String {
        return ".\(self.rawValue)"
    }
    
    static func fromFileExtension(_ extension: String) -> ImageFileType? {
        let cleanExtension = `extension`.lowercased().replacingOccurrences(of: ".", with: "")
        return ImageFileType(rawValue: cleanExtension)
    }
} 