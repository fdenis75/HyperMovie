import Foundation
import HyperMovieModels

/// Protocol defining video processing operations.
@available(macOS 15, *)
public protocol VideoProcessing: Actor {
    /// Process a video file at the given URL.
    /// - Parameter url: The URL of the video file to process.
    /// - Returns: A processed Video object.
    /// - Throws: VideoError if processing fails.
    func process(url: URL) async throws -> Video
    
    /// Process multiple video files.
    /// - Parameter urls: The URLs of the video files to process.
    /// - Returns: An array of processed Video objects.
    /// - Throws: VideoError if processing fails.
    func processMultiple(urls: [URL]) async throws -> [Video]
    
    /// Extract metadata from a video file.
    /// - Parameter video: The video to extract metadata from.
    /// - Throws: VideoError if metadata extraction fails.
    func extractMetadata(for video: Video) async throws
    
    /// Generate a thumbnail for a video.
    /// - Parameters:
    ///   - video: The video to generate a thumbnail for.
    ///   - size: The desired size of the thumbnail.
    /// - Returns: The URL of the generated thumbnail.
    /// - Throws: VideoError if thumbnail generation fails.
    func generateThumbnail(for video: Video, size: CGSize) async throws -> URL
    
    /// Cancel all ongoing processing operations.
    func cancelAllOperations()
}

/// Default implementations for VideoProcessing.
@available(macOS 15, *)
public extension VideoProcessing {
    func processMultiple(urls: [URL]) async throws -> [Video] {
        var videos: [Video] = []
        for url in urls {
            let video = try await process(url: url)
            videos.append(video)
        }
        return videos
    }
    
    func cancelAllOperations() {
        // Default implementation does nothing
    }
} 