import Foundation
import HyperMovieModels
import AVFoundation

/// Protocol defining preview generation operations.
@available(macOS 15, *)
public protocol PreviewGenerating: Actor {
    /// Generate a preview video for a video.
    /// - Parameters:
    ///   - video: The video to generate a preview for.
    ///   - config: The configuration for preview generation.
    /// - Returns: The URL of the generated preview video.
    /// - Throws: VideoError if generation fails.
    func generate(for video: Video, config: PreviewConfiguration) async throws -> URL
    
    /// Generate preview videos for multiple videos.
    /// - Parameters:
    ///   - videos: The videos to generate previews for.
    ///   - config: The configuration for preview generation.
    /// - Returns: A dictionary mapping video IDs to preview URLs.
    /// - Throws: VideoError if generation fails.
    func generateMultiple(for videos: [Video], config: PreviewConfiguration) async throws -> [UUID: URL]
    
    /// Extract a frame from a video at a specific time.
    /// - Parameters:
    ///   - video: The video to extract a frame from.
    ///   - time: The time at which to extract the frame.
    ///   - size: The desired size of the frame.
    /// - Returns: The extracted frame as a CGImage.
    /// - Throws: VideoError if frame extraction fails.
    func extractFrame(from video: Video, at time: CMTime, size: CGSize) async throws -> CGImage
    
    /// Extract multiple frames from a video at specific times.
    /// - Parameters:
    ///   - video: The video to extract frames from.
    ///   - times: The times at which to extract frames.
    ///   - size: The desired size of the frames.
    /// - Returns: A dictionary mapping times to frames.
    /// - Throws: VideoError if frame extraction fails.
    func extractFrames(from video: Video, at times: [CMTime], size: CGSize) async throws -> [CMTime: CGImage]
    
    /// Cancel preview generation for a specific video.
    /// - Parameter video: The video to cancel preview generation for.
    func cancel(for video: Video)
    
    /// Cancel all ongoing preview generation operations.
    func cancelAll()
}

/// Default implementations for PreviewGenerating.
@available(macOS 15, *)
public extension PreviewGenerating {
    func generateMultiple(for videos: [Video], config: PreviewConfiguration) async throws -> [UUID: URL] {
        var results: [UUID: URL] = [:]
        for video in videos {
            let url = try await generate(for: video, config: config)
            results[video.id] = url
        }
        return results
    }
    
    func extractFrames(from video: Video, at times: [CMTime], size: CGSize) async throws -> [CMTime: CGImage] {
        var frames: [CMTime: CGImage] = [:]
        for time in times {
            let frame = try await extractFrame(from: video, at: time, size: size)
            frames[time] = frame
        }
        return frames
    }
    
    func cancel(for video: Video) {
        // Default implementation does nothing
    }
    
    func cancelAll() {
        // Default implementation does nothing
    }
} 