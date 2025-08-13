import Foundation
import SwiftUI
import Combine

@Observable
class ImageHistoryService: ImageHistoryServiceProtocol {
    var imageHistory: [ImageHistoryItem] = []
    private let userDefaultsKey = "ImageHistory"
    private let maxHistoryItems = 20
    
    init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    func addToHistory(_ imageFile: ImageFile) {
        // Remove if already exists (to move to top)
        imageHistory.removeAll { $0.filePath == imageFile.path }
        
        // Create new history item
        let historyItem = ImageHistoryItem(
            id: UUID(),
            displayName: imageFile.displayName,
            filePath: imageFile.path,
            fileSize: imageFile.size,
            fileType: imageFile.fileType,
            lastUsed: Date(),
            sha256Checksum: imageFile.sha256Checksum,
            bookmarkData: imageFile.bookmarkData
        )
        
        // Add to beginning of array
        imageHistory.insert(historyItem, at: 0)
        
        // Keep only the most recent items
        if imageHistory.count > maxHistoryItems {
            imageHistory = Array(imageHistory.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    func removeFromHistory(_ item: ImageHistoryItem) {
        imageHistory.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearHistory() {
        imageHistory.removeAll()
        saveHistory()
    }
    
    /// Validate all bookmarks in the history
    func validateAllBookmarks() {
        print("🔍 [DEBUG] Validating all bookmarks in history...")
        
        for (index, item) in imageHistory.enumerated() {
            let wasValid = item.isValid
            var isValid = true
            
            // Check if it's a local file (not network share)
            let isLocalFile = !item.filePath.hasPrefix("//") && !item.filePath.hasPrefix("smb://")
            
            if isLocalFile {
                // For local files, validate bookmark or file existence
                if let bookmarkData = item.bookmarkData {
                    isValid = BookmarkManager.shared.isBookmarkValid(bookmarkData)
                } else {
                    isValid = FileManager.default.fileExists(atPath: item.filePath)
                }
                
                if !isValid {
                    print("❌ [DEBUG] Local bookmark/file no longer valid: \(item.displayName)")
                }
            } else {
                // For network files, we can't validate without network access
                // Keep them as potentially valid
                print("⚠️ [DEBUG] Network file - skipping validation: \(item.displayName)")
            }
            
            // Update validity status if it changed
            if wasValid != isValid {
                imageHistory[index].isValid = isValid
                print("🔄 [DEBUG] Validity changed for \(item.displayName): \(wasValid) → \(isValid)")
            }
        }
        
        saveHistory()
        print("✅ [DEBUG] Bookmark validation complete")
    }
    
    func loadImageFromHistory(_ item: ImageHistoryItem) -> ImageFile? {
        // Check if item is marked as invalid
        guard item.isValid else {
            print("❌ [DEBUG] Item marked as invalid: \(item.displayName)")
            return nil
        }
        
        // Try to validate bookmark if available
        if let bookmarkData = item.bookmarkData {
            guard BookmarkManager.shared.isBookmarkValid(bookmarkData) else {
                print("❌ [DEBUG] Bookmark is no longer valid for: \(item.displayName)")
                // Mark as invalid instead of removing
                if let index = imageHistory.firstIndex(where: { $0.id == item.id }) {
                    imageHistory[index].isValid = false
                    saveHistory()
                }
                return nil
            }
        } else {
            // Fallback to file existence check
            guard FileManager.default.fileExists(atPath: item.filePath) else {
                print("❌ [DEBUG] File no longer exists: \(item.filePath)")
                // Mark as invalid instead of removing
                if let index = imageHistory.firstIndex(where: { $0.id == item.id }) {
                    imageHistory[index].isValid = false
                    saveHistory()
                }
                return nil
            }
        }
        
        // Create ImageFile from history item
        var imageFile = ImageFile(
            name: item.displayName,
            path: item.filePath,
            size: item.fileSize,
            fileType: item.fileType
        )
        imageFile.sha256Checksum = item.sha256Checksum
        imageFile.bookmarkData = item.bookmarkData
        
        // Update last used date
        if let index = imageHistory.firstIndex(where: { $0.id == item.id }) {
            imageHistory[index].lastUsed = Date()
            saveHistory()
        }
        
        return imageFile
    }
    
    // MARK: - Private Methods
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(imageHistory)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("❌ [DEBUG] Failed to save image history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        do {
            imageHistory = try JSONDecoder().decode([ImageHistoryItem].self, from: data)
        } catch {
            print("❌ [DEBUG] Failed to load image history: \(error)")
            imageHistory = []
        }
    }
}

// MARK: - ImageHistoryItem

struct ImageHistoryItem: Identifiable, Codable {
    let id: UUID
    let displayName: String
    let filePath: String
    let fileSize: Int64
    let fileType: ImageFileType
    var lastUsed: Date
    var sha256Checksum: String?
    var bookmarkData: Data? // Added for security-scoped bookmark support
    var isValid: Bool = true // Track bookmark validity
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedLastUsed: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUsed, relativeTo: Date())
    }
}