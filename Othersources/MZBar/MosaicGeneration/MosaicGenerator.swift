//
//  MosaicGenerator.swift
//  MZBar
//
//  Created by Francois on 02/11/2024.
//
import Foundation
import AVFoundation
@preconcurrency import CoreGraphics
import os.log
import SwiftUI
import CryptoKit

struct TimeStamp: Sendable {
    let ts: String
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}
/// Main class responsible for generating mosaic images from video files
public final class MosaicGenerator: @unchecked Sendable {
    // MARK: - Properties
    
    
    private let logger = Logger(subsystem: "com.mosaic.generation", category: "MosaicGenerator")
    private let generatorConfig: MosaicGeneratorConfig
    private let processingConfig: ProcessingConfiguration
    private let videoProcessor: VideoProcessor
    private let thumbnailProcessor: ThumbnailProcessor
    private let layoutProcessor: LayoutProcessor
    private var progressHandler: ((ProgressInfo) -> Void)?
    private let signposter = OSSignposter(logHandle: .mosaic)
    private var currentBatchId: Int64?

    
    /// Whether processing should be cancelled
    private var isCancelled = false
    
    /// Current files being processed
    public private(set) var videosFiles: [(URL, URL)] = []
    
    // MARK: - Initialization
    
    /// Initialize mosaic generator with configuration
    /// - Parameter config: Generator configuration
    public init(config: MosaicGeneratorConfig = .default, processingConfig: ProcessingConfiguration = .default, layoutProcessor: LayoutProcessor? = nil) {
        self.generatorConfig = config
        self.processingConfig = processingConfig
        self.videoProcessor = VideoProcessor()
        self.thumbnailProcessor = ThumbnailProcessor(config: config)
        self.layoutProcessor = layoutProcessor ?? LayoutProcessor()
    }
    
    // MARK: - Public Methods
    
    /// Set progress handler for generation updates
    /// - Parameter handler: Progress handler closure
    public func setProgressHandler(_ handler: @escaping (ProgressInfo) -> Void) {
        self.progressHandler = handler
    }
    
    /// Cancel ongoing generation
    public func cancelGeneration() {
        isCancelled = true
    }
    
  
  
    // MARK: - Private Methods
    
    /// Processes a single video file to generate a mosaic image
    /// - Parameters:
    ///   - video: The input video file URL to process
    ///   - output: The output directory URL where the mosaic will be saved
    ///   - config: Configuration options for processing the video
    /// - Returns: A tuple containing (input video URL, output mosaic URL)
    /// - Throws: `MosaicError` for various failure conditions
    public func processSingleFile(
        video: URL,
        output: URL,
        config: ProcessingConfiguration,
        batchId: Int64
    ) async throws -> ResultFiles {
        // Initialize timing and logging
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("Processing file: \(video.lastPathComponent)")
        let asset = AVURLAsset(url: video)
        let state = signposter.beginInterval("mosaic generation")
        var metadata: VideoMetadata = try await videoProcessor.processVideo(file: video, asset: asset)
        var outputURL: URL = output
        defer { signposter.endInterval("mosaic generation", state) }

        // Generate hash and check for duplicates
        let hash = generateHash(filePath: video.path, size: String(metadata.resolution.debugDescription), codec: String(metadata.codec), creationDate: metadata.creationDate ?? "2024-01-11")
        
        // First check if movie exists and get/create movie ID
        let movieId = try DatabaseManager.shared.getOrCreateMovie(
            filePath: video.path,
            hash: hash,
            metadata: metadata
        )

        // Then check for duplicate mosaic
        if DatabaseManager.shared.isDuplicateMosaic(
            movieId: movieId,
            size: String(config.width),
            density: String(config.density.rawValue),
            layout: String(config.orientation)
        ) {
            logger.info("Mosaic already exists. Skipping generation for: \(video.lastPathComponent)")
            throw MosaicError.existingVid
        }
        do {
            // Early validation checks
            guard config.duration <= 0 || Int(metadata.duration) >= config.duration else {
                logger.debug("File too short: \(video.lastPathComponent)")
                throw MosaicError.tooShort
            }
            
            if try await isExistingFile(
                for: video,
                in: output,
                format: config.format,
                type: metadata.type,
                density: config.density.rawValue,
                addPath: config.addFullPath
            ) && !config.overwrite {
                logger.debug("Existing file: \(video.lastPathComponent)")
                let outputURL = getOutputFileName(for: video,
                                      in: output,
                                      format: config.format,
                                      type: metadata.type,
                                      density: config.density.rawValue,
                                      addPath: config.addFullPath)
                try DatabaseManager.shared.insertMosaic(
                    movieId: movieId,
                    batchId: batchId,
                    filePath: outputURL.path,
                    size: String(config.width),
                    density: String(config.density.rawValue),
                    layout: String(config.orientation),
                    folderHierarchy: output.path,
                    hash: hash,
                    metadata: metadata
                )
                throw MosaicError.existingVid
            }
            
            // MARK: - Layout Processing
            let aspectRatio = metadata.resolution.width / metadata.resolution.height
            let thumbnailCount = layoutProcessor.calculateThumbnailCount(
                duration: metadata.duration,
                width: config.width,
                density: config.density,
                useAutoLayout: config.useAutoLayout
            )
            
            let layout = layoutProcessor.calculateLayout(
                originalAspectRatio: aspectRatio,
                thumbnailCount: thumbnailCount,
                mosaicWidth: config.width,
                density: config.density,
                useCustomLayout: config.customLayout,
                useAutoLayout: config.useAutoLayout
            )
            
            // MARK: - Thumbnail Processing
            let thumbnails = try await thumbnailProcessor.extractThumbnails(
                from: video,
                layout: layout,
                asset: asset,
                preview: false,
                accurate: config.generatorConfig.accurateTimestamps
            )
            
            // MARK: - Mosaic Generation
            let mosaic = try await generateMosaic(
                from: thumbnails,
                layout: layout,
                metadata: metadata,
                config: config
            )
            
            // MARK: - Save Results
            let finalOutputDirectory = config.separateFolders 
                ? output.appendingPathComponent(metadata.type, isDirectory: true)
                : output
            
            let result = try await saveMosaic(
                mosaic,
                for: video,
                in: finalOutputDirectory,
                format: config.format,
                type: metadata.type,
                density: config.density.rawValue,
                addPath: config.addFullPath
            )
            
            updateProgress(
                currentFile: video.path,
                processedFiles: 1,
                totalFiles: 1,
                stage: "Mosaic generation complete",
                startTime: startTime,
                fileProgress: 1.0,
                doneFile: ResultFiles(video: result.0, output: result.1)
            )
            let resultat = ResultFiles(video: result.0, output: result.1)
            
            // Store metadata after successful generation
            let size = String(config.width)
            let density = String(config.density.rawValue)
            let layoutType = String(config.orientation)
            
            try DatabaseManager.shared.insertMosaic(
                movieId: movieId,
                batchId: batchId,
                filePath: resultat.output.path,
                size: size,
                density: density,
                layout: layoutType,
                folderHierarchy: output.path,
                hash: hash,
                metadata: metadata
            )
            
            return resultat
            
        } catch {
            let (stage, errorToThrow): (String, Error) = {
                switch error {
                case MosaicError.tooShort:
                    return ("File too short", error)
                case MosaicError.existingVid:
                    outputURL = getOutputFileName(for: video,
                                      in: output,
                                      format: config.format,
                                      type: metadata.type,
                                      density: config.density.rawValue,
                                      addPath: config.addFullPath)
                                      updateProgress(
                                        currentFile: video.path,
                                        processedFiles: 1,
                                        totalFiles: 1,
                                        stage: "File already exists",
                                        startTime: startTime,
                                        fileProgress: 1.0
                                        
                                    )
                    return ("File already exists", error)
                case MosaicError.unableToCreateContext:
                    return ("Failed to create graphics context", error)
                case MosaicError.thumbnailExtractionFailed:
                    return ("Failed to extract thumbnails", error)
                case MosaicError.unableToSaveMosaic:
                    return ("Failed to save mosaic", error)
                default:
                    return ("Error while processing file", error)
                }
            }()
            
            updateProgress(
                currentFile: video.path,
                processedFiles: 1,
                totalFiles: 1,
                stage: stage,
                startTime: startTime,
                fileProgress: 1.0,
                doneFile: ResultFiles(video: video, output: outputURL)
            )
            
            throw errorToThrow
        }
    }
    
    
    private func updateProgress(
        currentFile: String,
        processedFiles: Int,
        totalFiles: Int,
        stage: String,
        startTime: CFAbsoluteTime,
        fileProgress: Double = 0.0,
        doneFile: ResultFiles? = nil
    ) {
        // Calculate elapsed time once
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Use safer calculation for overall progress
        let progress = totalFiles > 0 ? Double(processedFiles) / Double(totalFiles) : 0
        
        // Calculate estimated time remaining only if there's actual progress
        let estimatedTimeRemaining: TimeInterval = processedFiles > 0 && progress > 0 
            ? (elapsedTime / progress) - elapsedTime 
            : 0
        
        let info = ProgressInfo(
            progressType: .file,
            progress: progress,
            currentFile: currentFile,
            processedFiles: processedFiles,
            totalFiles: totalFiles,
            currentStage: stage,
            elapsedTime: elapsedTime,
            estimatedTimeRemaining: estimatedTimeRemaining,
            skippedFiles: 0,
            errorFiles: 0,
            isRunning: true,
            fileProgress: fileProgress, // Use the passed fileProgress instead of overall progress
            doneFile: doneFile
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.progressHandler?(info)
        }
    }
    
    /// Generate a mosaic from thumbnails
    /// - Parameters:
    ///   - thumbnails: Array of thumbnails with timestamps
    ///   - layout: Layout information
    ///   - metadata: Video metadata
    /// - Returns: Generated mosaic image
    public func generateMosaic(
        from thumbnails: [(image: CGImage, timestamp: String)],
        layout: MosaicLayout,
        metadata: VideoMetadata,
        config: ProcessingConfiguration
    ) async throws -> CGImage {
        logger.info("Generating mosaic for: \(metadata.file.lastPathComponent)")
        let state = signposter.beginInterval("gen mosaic")
        defer{
            signposter.endInterval("gen mosaic", state)
        }
        // Create drawing context
        guard let context = createContext(width: Int(layout.mosaicSize.width),
                                       height: Int(layout.mosaicSize.height)) else {
            throw MosaicError.unableToCreateContext
        }
        
        // Fill background
        context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0,
                          width: layout.mosaicSize.width,
                          height: layout.mosaicSize.height))
        
        // Create array for timestamp info
        let count = min(thumbnails.count, layout.positions.count)
        var timestampInfo = Array(repeating: TimeStamp(ts: "", x: 0, y: 0, w: 0, h: 0),
                                count: count)
        
        // Use actor to synchronize context access
        actor ContextManager: @unchecked Sendable {
             let context: CGContext
            
            init(context: CGContext) {
                self.context = context
            }
            
             func drawImage(_ image: CGImage, in rect: CGRect) {
                context.draw(image, in: rect)
            }
        }
        
        let contextManager = ContextManager(context: context)
        
        // Process thumbnails concurrently but draw sequentially
        try await withThrowingTaskGroup(of: (Int, TimeStamp).self) { group in
            let layoutCopy = layout // Capture value type
            for index in 0..<count {
                group.addTask { @Sendable in
                    let (thumbnail, timestamp) = thumbnails[index]
                    let position = layoutCopy.positions[index]
                    var thumbnailSize = layoutCopy.thumbnailSizes[index]
                    var x = position.x
                    var y = Int(layoutCopy.mosaicSize.height) - Int(thumbnailSize.height) - position.y
                    
                    var imageToDraw = thumbnail
                    
                    // Resize if needed
                    if thumbnail.width != Int(thumbnailSize.width) || thumbnail.height != Int(thumbnailSize.height) {
                        autoreleasepool {
                            if let resizeContext = self.createContext(
                                width: Int(thumbnailSize.width),
                                height: Int(thumbnailSize.height)
                            ) {
                                let rect = CGRect(x: 0, y: 0,
                                                width: thumbnailSize.width,
                                                height: thumbnailSize.height)
                                resizeContext.draw(thumbnail, in: rect)
                                
                                if let resizedImage = resizeContext.makeImage() {
                                    imageToDraw = resizedImage
                                }
                            }
                        }
                    }
                    
                    // Create drawing context for effects
                    if config.addBorder || config.addShadow {
                        // Calculate padding needed for effects
                        let borderPadding = config.addBorder ? config.borderWidth : 0
                        let shadowPadding: CGFloat = config.addShadow ? 8 : 0 // Space for shadow
                        let totalPadding = borderPadding + shadowPadding
                        
                        // Create larger context to accommodate effects
                        if let effectContext = self.createContext(
                            width: Int(thumbnailSize.width + totalPadding * 2),  // Add padding on both sides
                            height: Int(thumbnailSize.height + totalPadding * 2)  // Add padding on top and bottom
                        ) {
                            // Apply shadow if enabled
                            if config.addShadow {
                                effectContext.setShadow(
                                    offset: CGSize(width: 3, height: 3),
                                    blur: 5,
                                    color: CGColor(gray: 0, alpha: 0.5)
                                )
                            }
                            
                            // Calculate the drawing rect with padding
                            let drawRect = CGRect(
                                x: totalPadding,
                                y: totalPadding,
                                width: thumbnailSize.width - (borderPadding * 2),  // Adjust for border width
                                height: thumbnailSize.height - (borderPadding * 2)  // Adjust for border width
                            )
                            
                            // Draw the image
                            effectContext.draw(imageToDraw, in: drawRect)
                            
                            // Add border if enabled
                            if config.addBorder {
                                effectContext.setStrokeColor(config.borderColor)
                                effectContext.setLineWidth(config.borderWidth)
                                effectContext.stroke(drawRect)
                            }
                            
                            if let processedImage = effectContext.makeImage() {
                                imageToDraw = processedImage
                                
                                // Update the position to account for the larger image with effects
                                x -= Int(totalPadding)
                                y -= Int(totalPadding)
                                thumbnailSize = CGSize(
                                    width: thumbnailSize.width + totalPadding * 2,
                                    height: thumbnailSize.height + totalPadding * 2
                                )
                            }
                        }
                    }
                    
                    // Draw using the context manager with potentially updated position and size
                    await contextManager.drawImage(
                        imageToDraw,
                        in: CGRect(x: CGFloat(x), y: CGFloat(y),
                                  width: CGFloat(thumbnailSize.width),
                                  height: CGFloat(thumbnailSize.height))
                    )
                    
                    return (index, TimeStamp(
                        ts: timestamp,
                        x: x,
                        y: y,
                        w: Int(thumbnailSize.width),
                        h: Int(thumbnailSize.height)
                    ))
                }
            }
            
            // Collect results in order
            for try await (index, stamp) in group {
                timestampInfo[index] = stamp
            }
        }
        
        // Draw timestamps and metadata
        drawTimestamps(context: context, timestamps: timestampInfo)
        drawMetadata(context: context, metadata: metadata,
                    width: Int(layout.mosaicSize.width),
                    height: Int(layout.mosaicSize.height))
        
        guard let outputImage = context.makeImage() else {
            throw MosaicError.unableToGenerateMosaic
        }
        
        return outputImage
    }
    
    // MARK: - Private Methods
    
    private func createContext(width: Int, height: Int) -> CGContext? {
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
    
    private func drawTimestamps(context: CGContext, timestamps: [TimeStamp]) {
        for ts in timestamps {
            let fontSize = CGFloat(ts.h) / 6 / 1.618
            let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white.cgColor
            ]
            
            let attributedTimestamp = CFAttributedStringCreate(
                nil,
                ts.ts as CFString,
                attributes as CFDictionary
            )
            let line = CTLineCreateWithAttributedString(attributedTimestamp!)
            
            context.saveGState()
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.1))
            
            let textRect = CGRect(
                x: ts.x,
                y: ts.y,
                width: ts.w,
                height: Int(CGFloat(ts.h) / 7)
            )
            context.fill(textRect)
            
            let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            let textPosition = CGPoint(
                x: ts.x + ts.w - Int(textWidth) - 5,
                y: ts.y + 10
            )
            
            context.textPosition = textPosition
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }
    
    private func drawMetadata(context: CGContext, metadata: VideoMetadata, width: Int, height: Int) {
        let metadataHeight = Int(round(Double(height) * 0.1))
        let lineHeight = metadataHeight / 4
        let fontSize = round(Double(lineHeight) / 2)
        
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 0.2))
        context.fill(CGRect(
            x: 0,
            y: height - metadataHeight,
            width: width,
            height: metadataHeight
        ))
        
        let metadataText = """
        File: \(metadata.file.standardizedFileURL.standardizedFileURL)
        Codec: \(metadata.codec)
        Resolution: \(Int(metadata.resolution.width))x\(Int(metadata.resolution.height))
        Duration: \(formatDuration(seconds: metadata.duration))
        """
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: CTFontCreateWithName("Helvetica" as CFString, fontSize, nil),
            .foregroundColor: NSColor.white.cgColor
        ]
        
        let attributedString = NSAttributedString(string: metadataText, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        let rect = CGRect(
            x: 10,
            y: height - metadataHeight + 10,
            width: width - 20,
            height: metadataHeight - 20
        )
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        
        context.saveGState()
        CTFrameDraw(frame, context)
        context.restoreGState()
    }
    
    private func formatDuration(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

extension MosaicGenerator {
    private func saveMosaic(
        _ mosaic: CGImage,
        for videoFile: URL,
        in outputDirectory: URL,
        format: String,
        type: String,
        density: String,
        addPath: Bool
    ) async throws -> (URL, URL) {
        // Create export manager if not exists
        let exportManager = ExportManager(config: self.generatorConfig)
        let state = signposter.beginInterval("save mosaic")
        defer{
            signposter.endInterval("save mosaic", state)
        }
        // Save the mosaic
        let outputURL = try await exportManager.saveMosaic(
            mosaic,
            for: videoFile,
            in: outputDirectory,
            format: format,
            type: type,
            density: density,
            addPath: addPath
        )
        return (videoFile, outputURL)
    }
    
    
    private func isExistingFile( for videoFile: URL,
                                 in outputDirectory: URL,
                                 format: String,
                                 type: String,
                                 density: String,
                                 addPath: Bool) async throws -> Bool
    {
        let exportManager = ExportManager(config: self.generatorConfig)
        return try await exportManager.FileExists(for: videoFile, in: outputDirectory, format: format, type: type, density: density, addPath: addPath)
    }
    private func getOutputFileName ( for videoFile: URL,
                                     in outputDirectory: URL,
                                     format: String,
                                     type: String,
                                     density: String,
                                     addPath: Bool)   -> URL
    {
        let exportManager = ExportManager(config: self.generatorConfig)
        return   exportManager.getFileName(for: videoFile, in: outputDirectory, format: format, type: type, density: density, addPath: addPath)
    }
}

func generateHash(filePath: String, size: String, codec: String, creationDate: String) -> String {
    // Concatenate the attributes into a single string
    let combinedString = "\(filePath)\(size)\(codec)\(creationDate)"
    
    // Convert the string to data
    let data = Data(combinedString.utf8)
    
    // Generate the SHA256 hash
    let hash = SHA256.hash(data: data)
    
    // Convert the hash to a hex string
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}




