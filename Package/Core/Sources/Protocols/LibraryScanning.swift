import Foundation
import HyperMovieModels

/// Protocol defining library scanning capabilities
public protocol LibraryScanning {
    /// Scans a folder and creates or updates library items accordingly
    func scanFolder(_ url: URL, parent: LibraryItem?) async throws -> LibraryItem
    
    /// Updates an existing folder's contents
    func updateFolder(_ item: LibraryItem) async throws
} 