import Foundation
import SwiftData
import OSLog
import HyperMovieModels
import HyperMovieCore
/// Service responsible for scanning folders and organizing the library structure
@available(macOS 15.0, *)
public actor LibraryScanner {
    private let logger = Logger(subsystem: "com.hypermovie", category: "library-scanner")
    private let videoProcessor: HyperMovieCore.VideoProcessing
    private let modelContext: ModelContext
    
    public init(videoProcessor: HyperMovieCore.VideoProcessing, modelContext: ModelContext) {
        self.videoProcessor = videoProcessor
        self.modelContext = modelContext
    }
    
    /// Scans a folder and creates or updates library items accordingly
    public func scanFolder(_ url: URL, parent: LibraryItem? = nil) async throws -> LibraryItem {
        logger.info("Scanning folder: \(url.path)")
        
        // Check if this folder is already in the library
        if let existingItem = try await findExistingLibraryItem(for: url) {
            logger.info("Found existing library item for: \(url.path)")
            return existingItem
        }
        
        // Create new library item
        let item = LibraryItem(
            name: url.lastPathComponent,
            type: .folder,
            url: url,
            parent: parent
        )
        
        // Scan folder contents
        try await scanFolderContents(url, into: item)
        
        // Save to database
        await MainActor.run {
            modelContext.insert(item)
        }
        
        return item
    }
    
    /// Scans the contents of a folder and organizes videos and subfolders
    private func scanFolderContents(_ url: URL, into item: LibraryItem) async throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        // Process all items concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for contentURL in contents {
                group.addTask {
                    let isDirectory = try contentURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
                    
                    if isDirectory {
                        // Recursively scan subfolder
                        let childItem = try await self.scanFolder(contentURL, parent: item)
                        await MainActor.run {
                            item.addChild(childItem)
                        }
                    } else if await self.isVideoFile(contentURL) {
                        // Process video file
                        let video = try await self.videoProcessor.process(url: contentURL)
                        await MainActor.run {
                            item.addVideo(video)
                        }
                    }
                }
            }
        }
        
        item.markAsScanned()
        logger.info("Completed scanning folder: \(url.path)")
    }
    
    /// Finds an existing library item for the given URL
    private func findExistingLibraryItem(for url: URL) async throws -> LibraryItem? {
        let descriptor = FetchDescriptor<LibraryItem>(
            predicate: #Predicate<LibraryItem> { item in
                item.url == url
            }
        )
        
        return try await MainActor.run {
            try modelContext.fetch(descriptor).first
        }
    }
    
    /// Checks if a file is a video based on its extension
    private func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }
    
    /// Updates an existing folder's contents
    public func updateFolder(_ item: LibraryItem) async throws {
        guard item.type == .folder, let url = item.url else { return }
        
        logger.info("Updating folder: \(url.path)")
        try await scanFolderContents(url, into: item)
    }
} 