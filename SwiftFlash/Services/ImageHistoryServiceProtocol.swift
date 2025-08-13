//
//  ImageHistoryServiceProtocol.swift
//  SwiftFlash
//
//  Protocol defining the relationship between image history services and consumers.
//  This file establishes a clear contract for the image history service, allowing for
//  better separation of concerns, testability, and future extensibility.
//

import Foundation
import SwiftUI
import Combine

/// Protocol that defines the requirements for an image history service
protocol ImageHistoryServiceProtocol: ObservableObject {
    /// The list of image history items
    var imageHistory: [ImageHistoryItem] { get }
    
    /// Adds an image file to the history
    func addToHistory(_ imageFile: ImageFile)
    
    /// Removes a specific item from the history
    func removeFromHistory(_ item: ImageHistoryItem)
    
    /// Clears all history items
    func clearHistory()
    
    /// Validates all bookmarks in the history
    func validateAllBookmarks()
    
    /// Loads an image file from a history item
    func loadImageFromHistory(_ item: ImageHistoryItem) -> ImageFile?
}