//
//  ImageFileService.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import Foundation
import Combine

@MainActor
class ImageFileService: ObservableObject {
    @Published var selectedImage: ImageFile?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let supportedExtensions = ["img", "iso"]
    
    func validateAndLoadImage(from url: URL) -> ImageFile? {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "File does not exist"
            return nil
        }
        
        // Check file extension
        let fileExtension = url.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            errorMessage = "Unsupported file format. Supported formats: \(supportedExtensions.joined(separator: ", "))"
            return nil
        }
        
        // Get file attributes
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? Int64 else {
                errorMessage = "Could not determine file size"
                return nil
            }
            
            // Check if file is too small (likely not a valid image)
            if fileSize < 1024 * 1024 { // Less than 1MB
                errorMessage = "File is too small to be a valid disk image"
                return nil
            }
            
            // Create security-scoped bookmark
            var bookmarkData: Data?
            do {
                bookmarkData = try BookmarkManager.shared.createBookmark(for: url)
                print("✅ [DEBUG] Created bookmark for: \(url.lastPathComponent)")
            } catch {
                print("⚠️ [DEBUG] Failed to create bookmark for: \(url.lastPathComponent), error: \(error)")
                // Continue without bookmark (fallback to direct access)
            }
            
            // Create image file object
            let imageFileType = ImageFileType.fromFileExtension(fileExtension)
            var imageFile = ImageFile(
                name: url.lastPathComponent,
                path: url.path,
                size: fileSize,
                fileType: imageFileType ?? .img
            )
            imageFile.bookmarkData = bookmarkData
            
            errorMessage = nil
            return imageFile
            
        } catch {
            errorMessage = "Error reading file: \(error.localizedDescription)"
            return nil
        }
    }
    
    func clearSelection() {
        // Stop accessing the current secure resource if needed
        selectedImage?.stopAccessingSecureResource()
        selectedImage = nil
        errorMessage = nil
    }
    
    func validateImageForDrive(_ image: ImageFile, drive: Drive) -> Bool {
        // Check if drive is read-only
        if drive.isReadOnly {
            errorMessage = "Cannot flash to read-only drive. Please use a writable USB drive."
            return false
        }
        
        // Check if image size is larger than drive capacity
        if image.size > drive.size {
            errorMessage = "Image file (\(image.formattedSize)) is larger than drive capacity (\(drive.formattedSize))"
            return false
        }
        
        // Additional validation could be added here
        // - Check if image is corrupted
        // - Check available space
        
        return true
    }
} 