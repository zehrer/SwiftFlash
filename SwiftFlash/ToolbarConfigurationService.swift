import Foundation
import SwiftUI

@Observable
class ToolbarConfigurationService {
    private let userDefaults = UserDefaults.standard
    private let toolbarConfigurationKey = "toolbarConfiguration"
    
    // Default toolbar configuration
    var toolbarItems: [String] = [
        "refresh",
        "flexibleSpace",
        "flash",
        "eject",
        "checksum",
        "tags",
        "debug",
        "about",
        "inspector"
    ]
    
    init() {
        loadToolbarConfiguration()
    }
    
    func loadToolbarConfiguration() {
        if let savedItems = userDefaults.array(forKey: toolbarConfigurationKey) as? [String] {
            toolbarItems = savedItems
        }
    }
    
    func saveToolbarConfiguration() {
        userDefaults.set(toolbarItems, forKey: toolbarConfigurationKey)
    }
    
    func resetToDefault() {
        toolbarItems = [
            "refresh",
            "flexibleSpace",
            "flash",
            "eject",
            "checksum",
            "tags",
            "debug",
            "about",
            "inspector"
        ]
        saveToolbarConfiguration()
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        toolbarItems.move(fromOffsets: source, toOffset: destination)
        saveToolbarConfiguration()
    }
    
    func removeItem(at offsets: IndexSet) {
        toolbarItems.remove(atOffsets: offsets)
        saveToolbarConfiguration()
    }
    
    func addItem(_ itemId: String, at index: Int? = nil) {
        if let index = index {
            toolbarItems.insert(itemId, at: index)
        } else {
            toolbarItems.append(itemId)
        }
        saveToolbarConfiguration()
    }
} 