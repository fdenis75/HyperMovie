import Foundation
import SwiftUI
import OSLog
import AVKit

@MainActor
class CachedMoviesManager: ObservableObject {
    @Published var movies: [MovieFile] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let diskCache = ThumbnailCacheManager.shared
    private let memoryCache = ThumbnailMemoryCache.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movieview", category: "CachedMovies")
    
    /// Load all cached movies
    func loadCachedMovies() async {
        self.isLoading = true
        defer { self.isLoading = false }
        
        do {
            let cacheDir = try await diskCache.getCacheDirectory()
            var cachedMovies: [MovieFile] = []
            
            // Get all video directories in cache
            let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey]
            if let enumerator = FileManager.default.enumerator(
                at: cacheDir,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    if resourceValues.isDirectory == true {
                        if let metadataURL = try? getMetadataURL(for: fileURL),
                           let metadata = try? loadMetadata(from: metadataURL) {
                            // Try to reconstruct the original video URL from metadata
                            if let movie = try? await createMovieFile(from: metadata) {
                                cachedMovies.append(movie)
                            }
                        }
                    }
                }
            }
            
            // Sort by last access date (most recent first)
            self.movies = cachedMovies.sorted { movie1, movie2 in
                guard let date1 = movie1.lastAccessDate,
                      let date2 = movie2.lastAccessDate else {
                    return false
                }
                return date1 > date2
            }
            
            // Load thumbnails for all movies
            for movie in self.movies {
                if let thumbnail = try? await diskCache.retrieveThumbnail(
                    for: movie.url,
                    at: 0,
                    quality: .standard
                ) {
                    movie.thumbnail = thumbnail
                }
            }
            
            logger.info("Loaded \(self.movies.count) cached movies")
            
        } catch {
            logger.error("Failed to load cached movies: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Clear all cached movies
    func clearCache() async {
        do {
            try await diskCache.clearCache()
            movies.removeAll()
            logger.info("Cache cleared successfully")
        } catch {
            logger.error("Failed to clear cache: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    /// Remove a specific movie from cache
    func removeFromCache(_ movie: MovieFile) async {
        do {
            try await diskCache.removeCacheForVideo(movie.url)
            movies.removeAll { $0.id == movie.id }
            logger.info("Removed \(movie.url.lastPathComponent) from cache")
        } catch {
            logger.error("Failed to remove \(movie.url.lastPathComponent) from cache: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    // MARK: - Private Helpers
    
    private func getMetadataURL(for directoryURL: URL) -> URL {
        return directoryURL.appendingPathComponent("metadata.json")
    }
    
    private func loadMetadata(from url: URL) throws -> ThumbnailCacheMetadata {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ThumbnailCacheMetadata.self, from: data)
    }
    
    private func createMovieFile(from metadata: ThumbnailCacheMetadata) async throws -> MovieFile {
        // Create MovieFile with cached thumbnail
        let movie = MovieFile(url: metadata.originalURL)
        movie.lastAccessDate = metadata.lastAccessDate
        
        // Try to get cached thumbnail
        if let cached = try? await diskCache.retrieveThumbnail(
            for: movie.url,
            at: 0,
            quality: .standard
        ) {
            movie.thumbnail = cached
        }
        
        // Load additional metadata
        if let asset = try? AVURLAsset(url: movie.url) {
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try await track.load(.naturalSize)
                movie.resolution = size
                movie.aspectRatio = size.width / size.height
                movie.codec = try await track.mediaFormat
            }
            let duration = try await asset.load(.duration)
            movie.duration = CMTimeGetSeconds(duration)
        }
        
        return movie
    }
}

// MARK: - MovieFile Extension
extension MovieFile {
    var lastAccessDate: Date? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.lastAccessDate) as? Date }
        set { objc_setAssociatedObject(self, &AssociatedKeys.lastAccessDate, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

private struct AssociatedKeys {
    static var lastAccessDate = "lastAccessDate"
}

// MARK: - FolderProcessorProtocol Conformance
extension CachedMoviesManager: FolderProcessorProtocol {
    var isProcessing: Bool { isLoading }
    var showAlert: Bool { error != nil }
    var smartFolderName: String? { nil }
    
    func cancelProcessing() {
        // No-op since loading is quick
    }
    
    func dismissAlert() {
        self.error = nil
    }
    
    func setError(_ error: Error) {
        self.error = error
    }
    
    func processFolder(at url: URL) async throws {
        // No-op since we don't process folders directly
    }
    
    func processVideos(from urls: [URL]) async {
        // No-op since we don't process videos directly
    }
    
    func setSmartFolderName(_ name: String) async {
        // No-op since we don't use smart folders
    }
} 