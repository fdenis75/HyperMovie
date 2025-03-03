//
//  RenderingMode.swift
//  MZBar
//
//  Created by Francois on 02/11/2024.
//

import Foundation
import AVFoundation

/// Rendering modes for mosaic generation
public enum RenderingMode {
    /// Automatically choose the best rendering mode
    case auto
    /// Use Metal-based rendering (future use)
    case metal
    /// Use classic CPU-based rendering
    case classic
}

public let videoTypes = [
    "public.movie",
    "public.video",
    "public.mpeg-4",
    "com.apple.quicktime-movie",
    "public.mpeg",
    "public.avi",
    "public.mkv"
]

public enum ProgressType {
    case global
    case file
}

/// Input types for processing
public enum InputType {
    /// Input is a folder
    case folder
    /// Input is an M3U8 playlist
    case m3u8
    /// Input is individual files
    case files
}

public enum FileStatus {
    case queued
    case processing
    case failed
    case completed
}

/// Core errors that can occur during mosaic generation
public enum MosaicError: LocalizedError {
    /// Input file or directory not found
    case inputNotFound
    /// File is not a valid video
    case notAVideoFile
    /// Video file has no video track
    case noVideoTrack
    /// Unable to determine video codec
    case unableToGetCodec
    /// Failed to generate mosaic
    case unableToGenerateMosaic
    /// Failed to save mosaic
    case unableToSaveMosaic
    /// Output format not supported
    case unsupportedOutputFormat
    /// Failed to extract thumbnails
    case thumbnailExtractionFailed
    /// Unable to create graphics context
    case unableToCreateContext
    /// File already exists
    case existingVid
    /// Unable to create GPU-based extractor
    case unableToCreateGPUExtractor
    /// Unable to create composition tracks
    case unableToCreateCompositionTracks
    /// Video file has no video or audio track
    case noVideoOrAudioTrack
    /// Unable to create export session
    case unableToCreateExportSession
    /// Video duration too short
    case tooShort
    case exportTimeout
    case unableToExtractParams
    case ffmpegProcessFailed
    case existingHash
    case batchIdNotFound
    

    
    public var errorDescription: String? {
        switch self {
        case .inputNotFound:
            return "Input file or directory not found"
        case .notAVideoFile:
            return "File is not a valid video"
        case .noVideoTrack:
            return "Video file has no video track"
        case .unableToGetCodec:
            return "Unable to determine video codec"
        case .unableToGenerateMosaic:
            return "Failed to generate mosaic"
        case .unableToSaveMosaic:
            return "Failed to save mosaic"
        case .unsupportedOutputFormat:
            return "Output format not supported"
        case .thumbnailExtractionFailed:
            return "Failed to extract thumbnails"
        case .unableToCreateContext:
            return "Unable to create graphics context"
        case .existingVid:
            return "File already exists"
        case .unableToCreateGPUExtractor:
            return "Unable to create GPU-based extractor"
        case .unableToCreateCompositionTracks:
            return "Unable to create composition tracks"
        case .noVideoOrAudioTrack:
            return "Video file has no video or audio track"
        case .unableToCreateExportSession:
            return "Unable to create export session"
        case .tooShort:
            return "Video duration is too short"
        case .exportTimeout:
            return "Preview export timed out"
        case .unableToExtractParams:
            return "Unable to extract parameters"
        case .ffmpegProcessFailed:
            return "FFmpeg process failed"  
        case .existingHash:
            return "Mosaic already exists"
        case .batchIdNotFound:
            return "Batch ID not found"
        }
    }
}

/// Errors specific to thumbnail extraction
public enum ThumbnailExtractionError: LocalizedError {
    /// Failed to generate thumbnail at specific time
    case generationFailed(time: CMTime, underlyingError: Error)
    /// Partial failure in thumbnail extraction
    case partialFailure(successfulCount: Int, failedCount: Int)
    
    public var errorDescription: String? {
        switch self {
        case .generationFailed(let time, let error):
            return "Failed to generate thumbnail at time \(time.seconds): \(error.localizedDescription)"
        case .partialFailure(let successful, let failed):
            return "Partial failure in thumbnail extraction: \(successful) successful, \(failed) failed"
        }
    }
}

/// Processing stage for progress tracking
public enum ProcessingStage {
    /// Discovering files
    case discovering
    /// Generating thumbnails
    case thumbnails
    /// Generating mosaic
    case mosaic
    /// Generating preview
    case preview
    /// Generating playlist
    case playlist
    /// Saving output
    case saving
    
    public var description: String {
        switch self {
        case .discovering:
            return "Discovering Files"
        case .thumbnails:
            return "Generating Thumbnails"
        case .mosaic:
            return "Generating Mosaic"
        case .preview:
            return "Generating Preview"
        case .playlist:
            return "Generating Playlist"
        case .saving:
            return "Saving Output"
        }
    }
}

/// Output format options
public enum OutputFormat: String {
    /// HEIC format
    case heic = "heic"
    /// JPEG format
    case jpeg = "jpeg"
    
    public var fileExtension: String {
        return self.rawValue
    }
    
    public var mimeType: String {
        switch self {
        case .heic:
            return "image/heic"
        case .jpeg:
            return "image/jpeg"
        }
    }
}
public struct DateRange {
    let start: String
    let end: String
}

    public enum FilterCategory: String, CaseIterable {
        case folder = "Folder"
        case size = "Size"
        case density = "Density"
        case layout = "Layout"
        case videoType = "Video Type"
        case resolution = "Resolution"
        case codec = "Codec"
    }

struct MosaicFilterParams {
    let searchQuery: String
    let filters: [FilterCategory: String]
    let dateRange: DateRange?
    let batchDateRange: DateRange?
    let offset: Int
    let limit: Int
    
    var description: String {
        var desc = "MosaicFilterParams("
        desc += "searchQuery: \(searchQuery), "
        desc += "filters: \(filters), "
        desc += "dateRange: \(String(describing: dateRange)), "
        desc += "batchDateRange: \(String(describing: batchDateRange)), "
        desc += "offset: \(offset), "
        desc += "limit: \(limit)"
        desc += ")"
        return desc
    }
}

public enum DurationFilter {
    case all
    case lessThanOneMin
    case lessThanFiveMin
    case lessThanTenMin
    case lessThanThirtyMin
    case lessThanOneHour
    case moreThanOneHour
    
    var durationInSeconds: Double? {
        switch self {
        case .all:
            return nil
        case .lessThanOneMin:
            return 60
        case .lessThanFiveMin:
            return 300
        case .lessThanTenMin:
            return 600
        case .lessThanThirtyMin:
            return 1800
        case .lessThanOneHour:
            return 3600
        case .moreThanOneHour:
            return 3600 // Used as minimum for this case
        }
    }
    
    var isMoreThan: Bool {
        self == .moreThanOneHour
    }
}

