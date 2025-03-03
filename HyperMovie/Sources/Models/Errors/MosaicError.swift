import Foundation

enum MosaicError: LocalizedError {
    case inputNotFound
    case notAVideoFile
    case noVideoTrack
    case unableToGetCodec
    case unableToGenerateMosaic
    case unableToSaveMosaic
    case unsupportedOutputFormat
    case thumbnailExtractionFailed
    case unableToCreateContext
    case existingVid
    case unableToCreateGPUExtractor
    case unableToCreateCompositionTracks
    case unableToCreateExportSession
    case tooShort
    case exportTimeout
    
    var errorDescription: String? {
        switch self {
        case .inputNotFound: return "Input file or directory not found"
        case .notAVideoFile: return "File is not a valid video"
        case .noVideoTrack: return "Video file has no video track"
        case .unableToGetCodec: return "Unable to determine video codec"
        case .unableToGenerateMosaic: return "Failed to generate mosaic"
        case .unableToSaveMosaic: return "Failed to save mosaic"
        case .unsupportedOutputFormat: return "Output format not supported"
        case .thumbnailExtractionFailed: return "Failed to extract thumbnails"
        case .unableToCreateContext: return "Unable to create graphics context"
        case .existingVid: return "File already exists"
        case .unableToCreateGPUExtractor: return "Unable to create GPU-based extractor"
        case .unableToCreateCompositionTracks: return "Unable to create composition tracks"
        case .unableToCreateExportSession: return "Unable to create export session"
        case .tooShort: return "Video duration is too short"
        case .exportTimeout: return "Export timed out"
        }
    }
} 