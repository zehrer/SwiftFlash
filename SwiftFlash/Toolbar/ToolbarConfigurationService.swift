import Foundation
import SwiftUI

@Observable
class ToolbarConfigurationService {
    private let userDefaults = UserDefaults.standard
    private let toolbarConfigurationKey = "toolbarConfiguration"
    
    // Default toolbar configuration - Only essential items
    var toolbarItems: [String] = [
        "refresh",
        "flexibleSpace",
        "flash",
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