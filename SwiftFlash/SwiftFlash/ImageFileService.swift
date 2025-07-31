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
            
            // Create image file object
            let imageFileType = ImageFileType.fromFileExtension(fileExtension)
            let imageFile = ImageFile(
                name: url.lastPathComponent,
                path: url.path,
                size: fileSize,
                fileType: imageFileType ?? .img
            )
            
            errorMessage = nil
            return imageFile
            
        } catch {
            errorMessage = "Error reading file: \(error.localizedDescription)"
            return nil
        }
    }
    
    func clearSelection() {
        selectedImage = nil
        errorMessage = nil
    }
    
    func validateImageForDrive(_ image: ImageFile, drive: Drive) -> Bool {
        // Check if image size is larger than drive capacity
        if image.size > drive.size {
            errorMessage = "Image file (\(image.formattedSize)) is larger than drive capacity (\(drive.formattedSize))"
            return false
        }
        
        // Additional validation could be added here
        // - Check if drive is writable
        // - Check if image is corrupted
        // - Check available space
        
        return true
    }
} 