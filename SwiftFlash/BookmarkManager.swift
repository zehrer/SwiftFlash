import Foundation

/// Manages security-scoped bookmarks for persistent file access
class BookmarkManager {
    static let shared = BookmarkManager()
    
    private init() {}
    
    /// Create a security-scoped bookmark for a file URL
    func createBookmark(for url: URL) throws -> Data {
        print("🔐 [DEBUG] Creating bookmark for: \(url.path)")
        
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        print("✅ [DEBUG] Bookmark created successfully")
        return bookmarkData
    }
    
    /// Resolve a bookmark to get a file URL with security access
    func resolveBookmark(_ bookmarkData: Data) throws -> URL {
        print("🔓 [DEBUG] Resolving bookmark...")
        
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        if isStale {
            print("⚠️ [DEBUG] Bookmark was stale, but resolved successfully")
        } else {
            print("✅ [DEBUG] Bookmark resolved successfully")
        }
        
        return url
    }
    
    /// Start accessing a security-scoped resource
    func startAccessing(_ url: URL) -> Bool {
        let success = url.startAccessingSecurityScopedResource()
        if success {
            print("🔓 [DEBUG] Started accessing security-scoped resource: \(url.path)")
        } else {
            print("⚠️ [DEBUG] Failed to start accessing security-scoped resource: \(url.path)")
        }
        return success
    }
    
    /// Stop accessing a security-scoped resource
    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
        print("🔒 [DEBUG] Stopped accessing security-scoped resource: \(url.path)")
    }
    
    /// Get a file URL with security access using bookmark data
    func getSecureURL(from bookmarkData: Data) throws -> URL {
        let url = try resolveBookmark(bookmarkData)
        
        // Start accessing the resource
        guard startAccessing(url) else {
            throw BookmarkError.accessDenied
        }
        
        return url
    }
    
    /// Verify that a bookmark is still valid
    func isBookmarkValid(_ bookmarkData: Data) -> Bool {
        do {
            let url = try resolveBookmark(bookmarkData)
            return FileManager.default.fileExists(atPath: url.path)
        } catch {
            print("❌ [DEBUG] Bookmark validation failed: \(error)")
            return false
        }
    }
}

/// Errors that can occur when working with bookmarks
enum BookmarkError: Error {
    case creationFailed
    case resolutionFailed
    case accessDenied
    case fileNotFound
    
    var localizedDescription: String {
        switch self {
        case .creationFailed:
            return "Failed to create security bookmark"
        case .resolutionFailed:
            return "Failed to resolve security bookmark"
        case .accessDenied:
            return "Access denied to file"
        case .fileNotFound:
            return "File not found"
        }
    }
} 