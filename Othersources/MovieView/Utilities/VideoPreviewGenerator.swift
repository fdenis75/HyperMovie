import Foundation
import AVFoundation
import CoreMedia
import OSLog

enum VideoPreviewGenerator {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.MovieView", category: "videoPreview")

    static func generatePreviewFilename(
        originalURL: URL,
        duration: Double,
        thumbnailCount: Int
    ) -> String {
        let originalName = originalURL.deletingPathExtension().lastPathComponent
        return "\(originalName)-preview-\(Int(duration))s-\(thumbnailCount)fps.\(originalURL.pathExtension)"
    }
    
    static func getDefaultSavePath(for videoURL: URL) -> URL {
        let videoDirectory = videoURL.deletingLastPathComponent()
        return videoDirectory.appendingPathComponent("0Preview", isDirectory: true)
    }

    static func generatePreview(
        from url: URL,
        duration: Double = 30.0,
        thumbnailCount: Int,
        savePath: String? = nil,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let signposter = OSSignposter(logHandle: log)
        let intervalState = signposter.beginInterval("generatePreview")
        defer { signposter.endInterval("generatePreview", intervalState) }
        
        Logger.videoProcessing.debug("Generating preview with parameters:")
        Logger.videoProcessing.debug("  - URL: \(url)")
        Logger.videoProcessing.debug("  - Duration: \(duration) seconds") 
        Logger.videoProcessing.debug("  - Thumbnail count: \(thumbnailCount)")
        Logger.videoProcessing.debug("Starting preview generation for \(url.path)")
        Logger.videoProcessing.debug("Parameters - duration: \(duration), thumbnailCount: \(thumbnailCount)")
        
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        
        // Load video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw AppError.invalidVideoFile(url)
        }
        
        // Load audio track if available
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let compositionAudioTrack = audioTracks.isEmpty ? nil : composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        let assetDuration = try await asset.load(.duration)
        let (extractCount, segmentDuration) = calculateExtractionParameters(
            duration: CMTimeGetSeconds(assetDuration),
            thumbnailCount: thumbnailCount,
            previewDuration: duration
        )
        let timeScale = assetDuration.timescale
        
        // Composition setup progress: 10%
        await MainActor.run { progress(0.1) }
        Logger.videoProcessing.debug("Starting composition setup")
        Logger.videoProcessing.debug("Calculated parameters:")
        Logger.videoProcessing.debug("  - Extract count: \(extractCount)")
        Logger.videoProcessing.debug("  - Segment duration: \(segmentDuration) seconds")
        Logger.videoProcessing.debug("  - Time scale: \(timeScale)")
        Logger.videoProcessing.debug("  - Audio tracks found: \(audioTracks.count)")
        
        for i in 0..<extractCount {
            let fraction = Double(i) / Double(max(1, extractCount - 1))
            let sourceTime = CMTime(seconds: fraction * CMTimeGetSeconds(assetDuration), preferredTimescale: timeScale)
            let targetTime = CMTime(seconds: Double(i) * segmentDuration, preferredTimescale: timeScale)
            let segmentDurationTime = CMTime(seconds: segmentDuration, preferredTimescale: timeScale)
            let timeRange = CMTimeRange(start: sourceTime, duration: segmentDurationTime)
            
            // Insert video segment
            try compositionVideoTrack.insertTimeRange(
                timeRange,
                of: videoTrack,
                at: targetTime
            )
            
            // Insert corresponding audio segment if available
            if let audioTrack = audioTracks.first,
               let compositionAudioTrack = compositionAudioTrack {
                try compositionAudioTrack.insertTimeRange(
                    timeRange,
                    of: audioTrack,
                    at: targetTime
                )
            }
            
            // Track composition progress: 10-50%
            await MainActor.run { progress(0.1 + 0.4 * Double(i + 1) / Double(extractCount)) }
        }
        
        // Determine output path
        let outputURL: URL
        if let savePath = savePath {
            let saveDirectory = URL(fileURLWithPath: savePath)
            try FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
            outputURL = saveDirectory.appendingPathComponent(generatePreviewFilename(originalURL: url, duration: duration, thumbnailCount: thumbnailCount))
        } else {
            let defaultDirectory = getDefaultSavePath(for: url)
            try FileManager.default.createDirectory(at: defaultDirectory, withIntermediateDirectories: true)
            outputURL = defaultDirectory.appendingPathComponent(generatePreviewFilename(originalURL: url, duration: duration, thumbnailCount: thumbnailCount))
        }
        
        // Export the composition
        let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )
        
        guard let exportSession = exportSession else {
            throw AppError.thumbnailGenerationFailed(url, "Could not create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        // Start export progress tracking
        var progressTimer: Timer?
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak progressTimer] _ in
            let exportProgress = Float(exportSession.progress)
            // Export progress: 50-100%
            progress(0.5 + 0.5 * Double(exportProgress))
            if exportSession.status != .exporting {
                progressTimer?.invalidate()
            }
        }
        
        await exportSession.export()
        progressTimer?.invalidate()
        
        guard exportSession.status == .completed else {
            throw AppError.thumbnailGenerationFailed(url, exportSession.error?.localizedDescription ?? "Export failed")
        }
        
        await MainActor.run { progress(1.0) }
        Logger.videoProcessing.debug("Preview generation completed successfully")
        return outputURL
    }
    
    private static func calculateExtractionParameters(
        duration: Double,
        thumbnailCount: Int,
        previewDuration: Double
    ) -> (extractCount: Int, extractDuration: Double) {
        let baseExtractsPerMinute: Double
        if duration > 0 {
            let durationInMinutes = duration / 60.0
            let initialRate = 12.0
            let decayFactor = 0.2
            baseExtractsPerMinute = (initialRate / (1 + decayFactor * durationInMinutes))
        } else {
            baseExtractsPerMinute = 12.0
        }
        
        let extractCount = Int(ceil(duration / 60.0 * baseExtractsPerMinute))
        let extractDuration = previewDuration / Double(extractCount)
        
        return (extractCount, extractDuration)
    }
} 