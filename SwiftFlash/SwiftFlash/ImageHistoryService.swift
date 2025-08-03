import Foundation
import SwiftUI
import Combine

@Observable
class ImageHistoryService {
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
            lastUsed: Date()
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
    
    func loadImageFromHistory(_ item: ImageHistoryItem) -> ImageFile? {
        // Verify file still exists
        guard FileManager.default.fileExists(atPath: item.filePath) else {
            // File no longer exists, remove from history
            removeFromHistory(item)
            return nil
        }
        
        // Create ImageFile from history item
        let imageFile = ImageFile(
            name: item.displayName,
            path: item.filePath,
            size: item.fileSize,
            fileType: item.fileType
        )
        
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