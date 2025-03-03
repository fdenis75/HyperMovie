import Foundation
import SwiftUI
import CryptoKit

/// Represents the quality level of a cached thumbnail
enum ThumbnailQuality: String, Codable {
    case preview    // 240p
    case standard   // 480p
    case high      // 720p
    case original   // Source resolution
    
    var resolution: CGSize {
        switch self {
        case .preview:
            return CGSize(width: 426, height: 240)
        case .standard:
            return CGSize(width: 854, height: 480)
        case .high:
            return CGSize(width: 1280, height: 720)
        case .original:
            return CGSize(width: 0, height: 0) // Will be set based on source
        }
    }
}

/// Format used for storing cached thumbnails
enum CacheFormat: String, Codable, CaseIterable {
    case heic
    case jpeg
    
    var fileExtension: String {
        rawValue
    }
    
    var mimeType: String {
        switch self {
        case .heic:
            return "image/heic"
        case .jpeg:
            return "image/jpeg"
        }
    }
}

/// Parameters used for thumbnail generation
struct ThumbnailParameters: Codable, Hashable {
    let density: Float
    let quality: ThumbnailQuality
    let size: CGSize
    let format: CacheFormat
    
    static let standard = ThumbnailParameters(
        density: 1.0,
        quality: .standard,
        size: ThumbnailQuality.standard.resolution,
        format: .heic
    )
}

/// Represents a cached thumbnail
struct CachedThumbnail: Codable, Identifiable {
    let id: String
    let timestamp: TimeInterval
    let quality: ThumbnailQuality
    let filePath: String
    let fileSize: Int64
    let createdAt: Date
    
    var url: URL {
        URL(fileURLWithPath: filePath)
    }
}

/// Metadata for a cached video's thumbnails
struct ThumbnailCacheMetadata: Codable {
    let version: Int
    let videoHash: String
    let modificationDate: Date
    let parameters: ThumbnailParameters
    let thumbnails: [CachedThumbnail]
    let lastAccessDate: Date
    let originalURL: URL
    
    static let currentVersion = 1
    
    // Add CodingKeys to handle URL coding
    private enum CodingKeys: String, CodingKey {
        case version
        case videoHash
        case modificationDate
        case parameters
        case thumbnails
        case lastAccessDate
        case originalURL
    }
    
    // Add custom encoding for URL
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(videoHash, forKey: .videoHash)
        try container.encode(modificationDate, forKey: .modificationDate)
        try container.encode(parameters, forKey: .parameters)
        try container.encode(thumbnails, forKey: .thumbnails)
        try container.encode(lastAccessDate, forKey: .lastAccessDate)
        try container.encode(originalURL.path, forKey: .originalURL)
    }
    
    // Add custom decoding for URL
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        videoHash = try container.decode(String.self, forKey: .videoHash)
        modificationDate = try container.decode(Date.self, forKey: .modificationDate)
        parameters = try container.decode(ThumbnailParameters.self, forKey: .parameters)
        thumbnails = try container.decode([CachedThumbnail].self, forKey: .thumbnails)
        lastAccessDate = try container.decode(Date.self, forKey: .lastAccessDate)
        originalURL = URL(fileURLWithPath: try container.decode(String.self, forKey: .originalURL))
    }
    
    init(version: Int, videoHash: String, modificationDate: Date, parameters: ThumbnailParameters, thumbnails: [CachedThumbnail], lastAccessDate: Date, originalURL: URL) {
        self.version = version
        self.videoHash = videoHash
        self.modificationDate = modificationDate
        self.parameters = parameters
        self.thumbnails = thumbnails
        self.lastAccessDate = lastAccessDate
        self.originalURL = originalURL
    }
}

/// Utility functions for cache management
extension ThumbnailCacheMetadata {
    /// Generate a cache key for a video file
    @available(macOS 10.15, *)
    static func generateCacheKey(for videoURL: URL) throws -> String {
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let modificationDate = fileAttributes[.modificationDate] as? Date ?? Date()
        let pathHash = videoURL.path.data(using: .utf8)!
        let dateString = String(format: "%.0f", modificationDate.timeIntervalSince1970)
        let combinedString = videoURL.path + dateString
        let hash = SHA256.hash(data: combinedString.data(using: .utf8)!)
        return hash.prefix(16).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Get the cache directory for a specific video
    static func cacheDirectory(for videoHash: String) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDir
            .appendingPathComponent("MovieView")
            .appendingPathComponent("Thumbnails")
            .appendingPathComponent(videoHash)
    }
} 
