import SwiftUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers
import AppKit
import OSLog
import os.signpost

@MainActor
class VideoProcessor: ObservableObject {
    @Published var thumbnails: [VideoThumbnail] = []
    @Published var isProcessing = false
    @Published private(set) var error: Error?
    @Published private(set) var showAlert = false
    @Published var density: DensityConfig = .default
    @Published var processingProgress: Double = 0
    @Published var expectedThumbnailCount: Int = 0
    
    @Published var currentVideoURL: URL?
    private var currentTask: Task<Void, Never>?
    private let maxThumbnails = 600
    
    private let diskCache = ThumbnailCacheManager.shared
    private let memoryCache = ThumbnailMemoryCache.shared
    private let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "com.movieview", category: "VideoProcessing")
    
    @Published var mosaicProgress: Double = 0
    @Published var isMosaicGenerating = false
    private var mosaicTask: Task<Void, Never>?
    
    // Add new properties for mosaic progress tracking
    private var mosaicProgressContinuations: [UUID: AsyncStream<Double>.Continuation] = [:]
    private var mosaicProgressTasks: [UUID: Task<Void, Never>] = [:]
    
    // Add these new properties to VideoProcessor
    private let mosaicQueue = DispatchQueue(label: "com.movieview.mosaic-generation", qos: .userInitiated, attributes: .concurrent)
    private let thumbnailGenerationQueue = DispatchQueue(label: "com.movieview.thumbnail-generation", qos: .userInitiated)
    private let imageProcessingSemaphore = DispatchSemaphore(value: ProcessInfo.processInfo.activeProcessorCount * 2)
    
    func processDraggedItems(_ provider: NSItemProvider) {
        let interval = signposter.beginInterval("Process Dragged Items", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Process Dragged Items", interval) }
        
        Logger.videoProcessing.info("Processing dragged item...")
        guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            Logger.videoProcessing.error("Item is not a movie file")
            setError(AppError.invalidVideoFile(URL(fileURLWithPath: "")))
            return
        }
        
        provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { [weak self] (videoURL, error) in
            Logger.videoProcessing.info("Loading item...")
            if let error = error {
                Logger.videoProcessing.error("Error loading item: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.setError(AppError.unknownError(error.localizedDescription))
                }
                return
            }
            
            guard let videoURL = videoURL as? URL else {
                Logger.videoProcessing.error("Invalid URL received")
                Task { @MainActor in
                    self?.setError(AppError.invalidVideoFile(URL(fileURLWithPath: "")))
                }
                return
            }
            
            Logger.videoProcessing.info("Processing video at URL: \(videoURL.path)")
            Task { @MainActor in
                do {
                    try await self?.processVideo(url: videoURL)
                } catch {
                    Logger.videoProcessing.error("Error processing video: \(error.localizedDescription)")
                    self?.setError(error)
                }
            }
        }
    }
    
    func calculateExpectedThumbnails() {
        let interval = signposter.beginInterval("Calculate Expected Thumbnails", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Calculate Expected Thumbnails", interval) }
        
        guard let url = currentVideoURL else {
            expectedThumbnailCount = 0
            return
        }
        
        Task {
            let asset = AVAsset(url: url)
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                expectedThumbnailCount = calculateThumbnailCount(duration: durationSeconds)
                signposter.emitEvent("Expected Thumbnails Calculated", "count: \(self.expectedThumbnailCount)")
            } catch {
                Logger.videoProcessing.error("Failed to calculate expected thumbnails: \(error.localizedDescription)")
                expectedThumbnailCount = 0
            }
        }
    }
    
    func cancelProcessing() {
        signposter.emitEvent("Cancel Processing")
        Logger.videoProcessing.info("Cancelling video processing")
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        processingProgress = 0
    }
    
    private func calculateThumbnailCount(duration: Double) -> Int {
        if duration < 5 { return 4 }
        
        let base = 320.0 / 200.0 // base on thumbnail width
        let k = 10.0
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, maxThumbnails)
    }
    private func calculateThumbnailCountMosaic(duration: Double, config: MosaicConfig) -> Int {
        if duration < 5 { return 4 }
        
        let base = Double(config.width) / 320 // base on thumbnail width
        let k = 10.0
        let deca = 0.2
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, maxThumbnails)
    }


    func processVideo(url: URL) async throws {
        let interval = signposter.beginInterval("Process Video", id: signposter.makeSignpostID(), "file: \(url.lastPathComponent)")
        defer { signposter.endInterval("Process Video", interval) }
        
        Logger.videoProcessing.info("Starting video processing for: \(url.lastPathComponent)")
        
        try validateVideoFile(url)
        
        let startTime = Date()
        prepareForProcessing(url)
        
        currentTask = Task {
            do {
                let asset = AVAsset(url: url)
                try await validateVideoAsset(asset, url: url)
                
                let (thumbnailCount, durationSeconds) = try await getThumbnailConfiguration(from: asset)
                expectedThumbnailCount = thumbnailCount
                
                let (generator, aspectRatio) = try await configureImageGenerator(for: asset)
                let timePoints = calculateTimePoints(count: thumbnailCount, duration: durationSeconds)
                let parameters = createThumbnailParameters()
                
                try await processThumbnails(
                    timePoints: timePoints,
                    generator: generator,
                    url: url,
                    aspectRatio: aspectRatio,
                    parameters: parameters,
                    thumbnailCount: thumbnailCount
                )
                
                finishProcessing(startTime: startTime)
                
            } catch is CancellationError {
                handleCancellation()
            } catch {
                handleError(error)
            }
        }
    }

    private func validateVideoFile(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.videoProcessing.error("File not found: \(url.path)")
            throw AppError.fileNotFound(url)
        }
        
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            Logger.videoProcessing.error("File not accessible: \(url.path)")
            throw AppError.fileNotAccessible(url)
        }
    }
    
    private func prepareForProcessing(_ url: URL) {
        cancelProcessing()
        isProcessing = true
        processingProgress = 0
        currentVideoURL = url
        thumbnails.removeAll()
    }
    
    private func validateVideoAsset(_ asset: AVAsset, url: URL) async throws {
    
        
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            Logger.videoProcessing.debug("No video track found, falling back to audio track.")
            return
        }
        
        guard videoTrack != nil else {
            Logger.videoProcessing.error("No video track found in file: \(url.path)")
            throw AppError.invalidVideoFile(url)
        }
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        guard durationSeconds > 0 else {
            Logger.videoProcessing.error("Invalid video duration for file: \(url.path)")
            throw AppError.invalidVideoFile(url)
        }
    }
    
    private func getThumbnailConfiguration(from asset: AVAsset) async throws -> (count: Int, duration: Double) {
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let thumbnailCount = calculateThumbnailCount(duration: durationSeconds)
        
        Logger.videoProcessing.info("Generating \(thumbnailCount) thumbnails for video of duration \(durationSeconds)s")
        
        return (thumbnailCount, durationSeconds)
    }
    
    private func configureImageGenerator(for asset: AVAsset) async throws -> (AVAssetImageGenerator, CGFloat) {
        let generator = AVAssetImageGenerator(asset: asset)
        var aspectRatio: CGFloat = 16.0 / 9.0
        
        if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
            let naturalSize = try await videoTrack.load(.naturalSize)
            aspectRatio = naturalSize.width / naturalSize.height
            generator.maximumSize = CGSize(width: 480, height: 480 / aspectRatio)
        }
        
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 3, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 3, preferredTimescale: 600)
        
        return (generator, aspectRatio)
    }
    
    private func calculateTimePoints(count: Int, duration: Double) -> [CMTime] {
        (0..<count).map { i -> CMTime in
            let fraction = Double(i) / Double(max(1, count - 1))
            let seconds = fraction * duration
            return CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
        }
    }
    
    private func createThumbnailParameters() -> ThumbnailParameters {
        ThumbnailParameters(
            density: Float(density.factor),
            quality: .standard,
            size: ThumbnailQuality.standard.resolution,
            format: .heic
        )
    }
    
    private func processThumbnails(
        timePoints: [CMTime],
        generator: AVAssetImageGenerator,
        url: URL,
        aspectRatio: CGFloat,
        parameters: ThumbnailParameters,
        thumbnailCount: Int
    ) async throws {
        let interval = signposter.beginInterval("Process Thumbnails", id: signposter.makeSignpostID(), "count: \(thumbnailCount)")
        defer { signposter.endInterval("Process Thumbnails", interval) }
        
        for (index, time) in timePoints.enumerated() {
            let iterationInterval = signposter.beginInterval("Process Thumbnail", id: signposter.makeSignpostID(), "index: \(index + 1)/\(thumbnailCount)")
            let iterationStart = Date()
            try Task.checkCancellation()
            
            let timestamp = CMTimeGetSeconds(time)
            Logger.videoProcessing.debug("Processing thumbnail \(index + 1)/\(thumbnailCount) at \(String(format: "%.2f", timestamp))s")
            
            if let thumbnail = try await checkMemoryCache(url: url, timestamp: timestamp, parameters: parameters) {
                signposter.emitEvent("Memory Cache Hit", "index: \(index + 1)")
                addThumbnail(thumbnail, at: timestamp, aspectRatio: aspectRatio)
                processingProgress = Double(index + 1) / Double(thumbnailCount)
                signposter.endInterval("Process Thumbnail", iterationInterval)
                continue
            }
            
            if let thumbnail = try await checkDiskCache(url: url, timestamp: timestamp, parameters: parameters) {
                signposter.emitEvent("Disk Cache Hit", "index: \(index + 1)")
                addThumbnail(thumbnail, at: timestamp, aspectRatio: aspectRatio)
                processingProgress = Double(index + 1) / Double(thumbnailCount)
                signposter.endInterval("Process Thumbnail", iterationInterval)
                continue
            }
            
            try await generateAndStoreThumbnail(
                generator: generator,
                time: time,
                url: url,
                timestamp: timestamp,
                parameters: parameters,
                aspectRatio: aspectRatio,
                index: index,
                thumbnailCount: thumbnailCount,
                iterationStart: iterationStart
            )
            
            signposter.endInterval("Process Thumbnail", iterationInterval)
        }
    }
    
    private func generateAndStoreThumbnail(
        generator: AVAssetImageGenerator,
        time: CMTime,
        url: URL,
        timestamp: Double,
        parameters: ThumbnailParameters,
        aspectRatio: CGFloat,
        index: Int,
        thumbnailCount: Int,
        iterationStart: Date
    ) async throws {
        do {
            let thumbnail = try await generateNewThumbnail(generator: generator, at: time)
            try await storeThumbnail(thumbnail, for: url, at: timestamp, parameters: parameters)
            addThumbnail(thumbnail, at: timestamp, aspectRatio: aspectRatio)
            processingProgress = Double(index + 1) / Double(thumbnailCount)
            
            let iterationDuration = Date().timeIntervalSince(iterationStart)
            Logger.videoProcessing.debug("Thumbnail generation took \(String(format: "%.2f", iterationDuration))s")
        } catch {
            Logger.videoProcessing.error("Failed to generate thumbnail at \(CMTimeGetSeconds(time))s: \(error.localizedDescription)")
            if !error.isCancelled {
                throw AppError.thumbnailGenerationFailed(url, error.localizedDescription)
            }
        }
    }
    
    private func finishProcessing(startTime: Date) {
        isProcessing = false
        processingProgress = 1.0
        
        let totalDuration = Date().timeIntervalSince(startTime)
        Logger.videoProcessing.info("Finished processing video in \(String(format: "%.2f", totalDuration))s")
    }
    
    private func handleCancellation() {
        Logger.videoProcessing.info("Video processing cancelled")
        isProcessing = false
        processingProgress = 0
    }
    
    private func handleError(_ error: Error) {
        Logger.videoProcessing.error("Video processing failed: \(error.localizedDescription)")
        self.setError(error)
        isProcessing = false
        processingProgress = 0
    }
    
    private func addThumbnail(_ image: NSImage, at timestamp: TimeInterval, aspectRatio: CGFloat) {
        let thumbnail = VideoThumbnail(
            image: image,
            timestamp: CMTimeMakeWithSeconds(timestamp, preferredTimescale: 600),
            videoURL: currentVideoURL!,
            aspectRatio: aspectRatio
        )
        thumbnails.append(thumbnail)
    }
    
    func reprocessCurrentVideo() {
        guard let url = currentVideoURL else {
            Logger.videoProcessing.warning("No video to reprocess")
            return
        }
        Logger.videoProcessing.info("Reprocessing video with new density: \(self.density.name)")
        currentTask?.cancel()
        calculateExpectedThumbnails()
        Task { @MainActor in
            do {
                try await self.processVideo(url: url)
            } catch {
                Logger.videoProcessing.error("Error reprocessing video: \(error.localizedDescription)")
                self.setError(error)
            }
        }
    }
    
     func setError(_ error: Error) {
        self.error = error
        self.showAlert = true
    }
    
    func dismissAlert() {
        error = nil
        showAlert = false
    }
    
    private func checkMemoryCache(url: URL, timestamp: Double, parameters: ThumbnailParameters) async throws -> NSImage? {
        guard let videoHash = try? ThumbnailCacheMetadata.generateCacheKey(for: url) else {
            return nil
        }
        
        let key = ThumbnailMemoryCache.cacheKey(
            videoHash: videoHash,
            timestamp: timestamp,
            quality: parameters.quality
        )
        
        if let (cachedImage, _, _) = await memoryCache.retrieve(forKey: key) {
            Logger.videoProcessing.debug("Found thumbnail in memory cache")
            return cachedImage
        }
        return nil
    }
    
    private func checkDiskCache(url: URL, timestamp: Double, parameters: ThumbnailParameters) async throws -> NSImage? {
        if let cachedImage = try? await diskCache.retrieveThumbnail(
            for: url,
            at: timestamp,
            quality: parameters.quality
        ) {
            Logger.videoProcessing.debug("Found thumbnail in disk cache")
            await storeThumbnailInMemory(cachedImage, for: url, at: timestamp, parameters: parameters)
            return cachedImage
        }
        return nil
    }
    
    private func generateNewThumbnail(generator: AVAssetImageGenerator, at time: CMTime) async throws -> NSImage {
        Logger.videoProcessing.debug("Generating new thumbnail")
        let cgImage = try await generator.image(at: time).image
        return NSImage(cgImage: cgImage, size: NSSizeFromCGSize(generator.maximumSize))
    }
    
    private func storeThumbnail(_ image: NSImage, for url: URL, at timestamp: Double, parameters: ThumbnailParameters) async throws {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            try await diskCache.storeThumbnail(
                cgImage,
                for: url,
                at: timestamp,
                quality: parameters.quality,
                parameters: parameters
            )
            await storeThumbnailInMemory(image, for: url, at: timestamp, parameters: parameters)
        }
    }
    
    private func storeThumbnailInMemory(_ image: NSImage, for url: URL, at timestamp: Double, parameters: ThumbnailParameters) async {
        if let videoHash = try? ThumbnailCacheMetadata.generateCacheKey(for: url) {
            await memoryCache.store(
                image: image,
                forKey: ThumbnailMemoryCache.cacheKey(
                    videoHash: videoHash,
                    timestamp: timestamp,
                    quality: parameters.quality
                ),
                timestamp: timestamp,
                quality: parameters.quality
            )
        }
    }
    public func getVideoDuration(url: URL) async throws -> Double {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    public func getVideoAspectRatio(url: URL) async throws -> CGFloat {
        let asset = AVAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw AppError.invalidVideoFile(url)
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        return naturalSize.width / naturalSize.height
    }

    /// Creates an AsyncStream for tracking mosaic generation progress
    func mosaicProgressStream(for taskId: UUID) -> AsyncStream<Double> {
        AsyncStream { continuation in
            mosaicProgressContinuations[taskId] = continuation
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.mosaicProgressContinuations[taskId] = nil
                }
            }
        }
    }
    
    /// Generate a mosaic for a video file with task tracking
    func generateMosaic(
        url: URL,
        config: MosaicConfig,
        smartFolderName: String? = nil,
        taskId: UUID
    ) async throws -> URL {
        let interval = signposter.beginInterval("Generate Mosaic", id: signposter.makeSignpostID(), "file: \(url.lastPathComponent)")
        defer { signposter.endInterval("Generate Mosaic", interval) }
        
        isMosaicGenerating = true
        updateMosaicProgress(0, for: taskId)
        
        defer {
            isMosaicGenerating  = false
            updateMosaicProgress(1.0, for: taskId)
            mosaicProgressContinuations[taskId]?.finish()
        }
        
        // Determine output directory based on whether it's from a smart folder
        let mosaicDir: URL
        if let smartFolderName = smartFolderName {
            mosaicDir = URL(fileURLWithPath: "/Volumes/Ext-6TB-2/Mosaics/\(smartFolderName)", isDirectory: true)
        } else {
            mosaicDir = url.deletingLastPathComponent().appendingPathComponent("0Tth", isDirectory: true)
        }
        
        try FileManager.default.createDirectory(at: mosaicDir, withIntermediateDirectories: true)
        
        // Configure output path
        let outputName = "\(url.deletingPathExtension().lastPathComponent)_mosaic_\(config.configString).heic"
        let outputURL = mosaicDir.appendingPathComponent(outputName)
        
        // Check if mosaic already exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            signposter.emitEvent("Mosaic Already Exists", "file: \(outputName)")
            return outputURL
        }
        
        let metadataInterval = signposter.beginInterval("Get Video Metadata", id: signposter.makeSignpostID())
        // Get video metadata
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let track = try await asset.loadTracks(withMediaType: .video).first
        let size = try await track?.load(.naturalSize)
        let aspectRatio = (size?.width ?? 16) / (size?.height ?? 9)
        
        // Get additional metadata
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let codec = try await track?.mediaFormat ?? "Unknown"
        let resolution = size.map { "\(Int($0.width))×\(Int($0.height))" } ?? "Unknown"
        signposter.endInterval("Get Video Metadata", metadataInterval)
        
        let layoutInterval = signposter.beginInterval("Calculate Layout", id: signposter.makeSignpostID())
        // Calculate layout
        let thumbnailCount = calculateThumbnailCountMosaic(duration: duration, config: config)
        let layout = MosaicLayout.calculateOptimalLayout(
            originalAspectRatio: aspectRatio,
            thumbnailCount: thumbnailCount,
            mosaicWidth: Int(config.width),
            useAutoLayout: config.useAutoLayout,
            density: config.density
        )
        signposter.endInterval("Calculate Layout", layoutInterval)
        
        let extractionInterval = signposter.beginInterval("Extract Thumbnails", id: signposter.makeSignpostID(), "count: \(thumbnailCount)")
        // Create a serial queue for ordered processing
        let extractionQueue = DispatchQueue(label: "com.movieview.extraction.\(taskId.uuidString)")
        
        // Use AVAssetImageGenerator's batch generation capability
        let times = layout.sections.flatMap { section -> [CMTime] in
            return (0..<section.count).map { i in
                let fraction = Double(i) / Double(section.count)
                let sectionDuration = (section.endTime - section.startTime) * duration
                return CMTime(
                    seconds: section.startTime * duration + sectionDuration * fraction,
                    preferredTimescale: 600
                )
            }
        }
          let generator = AVAssetImageGenerator(asset: asset)
                        generator.appliesPreferredTrackTransform = true
        // Batch process thumbnails with parallel execution
        var thumbnails = [(image: CGImage, timestamp: String)]()
        try await withThrowingTaskGroup(of: (CGImage, String).self) { group in
            let batchSize = 8
            for batchStart in stride(from: 0, to: times.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, times.count)
                let batchTimes = Array(times[batchStart..<batchEnd])
                
                for time in batchTimes {
                    group.addTask {
                        // Use semaphore to prevent memory overload
                        self.imageProcessingSemaphore.wait()
                        defer { self.imageProcessingSemaphore.signal() }
                        
                      
                        let cgImage = try await generator.image(at: time).image
                        let timestamp = await self.formatTimestamp(seconds: CMTimeGetSeconds(time))
                        return (cgImage, timestamp)
                    }
                }
                
                for try await (cgImage, timestamp) in group {
                    extractionQueue.sync {
                        thumbnails.append((cgImage, timestamp))
                        let progress = Double(thumbnails.count) / Double(thumbnailCount) * 0.8
                        self.updateMosaicProgress(progress, for: taskId)
                    }
                }
            }
        }
        signposter.endInterval("Extract Thumbnails", extractionInterval)
        
        let renderInterval = signposter.beginInterval("Render Mosaic", id: signposter.makeSignpostID())
        
        // Calculate metadata and header dimensions
        let (metadata, headerHeight, fontSize) = generateMosaicMetadata(
            url: url,
            fileSize: Int64(fileSize),
            duration: duration,
            resolution: resolution,
            codec: codec,
            layout: layout
        )
        
        let totalHeight = layout.mosaicSize.height + headerHeight
        
        // Generate mosaic image
        guard let context = CGContext(
            data: nil,
            width: Int(layout.mosaicSize.width),
            height: Int(totalHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw AppError.thumbnailGenerationFailed(url, "Failed to create graphics context")
        }
        
        // Draw all components
        drawBackground(context, size: CGSize(width: layout.mosaicSize.width, height: totalHeight))
        
        let headerRect = CGRect(
            x: 10,
            y: Int(totalHeight - headerHeight - 10),
            width: Int(layout.mosaicSize.width) - 20,
            height: Int(headerHeight)
        )
        drawMetadataHeader(context, metadata: metadata, in: headerRect, fontSize: fontSize)
        drawThumbnails(context, thumbnails: thumbnails, layout: layout, config: config)
        
        // Save mosaic
        guard let outputImage = context.makeImage() else {
            throw AppError.thumbnailGenerationFailed(url, "Failed to create output image")
        }
        signposter.endInterval("Render Mosaic", renderInterval)
        
        let saveInterval = signposter.beginInterval("Save Mosaic", id: signposter.makeSignpostID())
        // Save as HEIC
        let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.heic" as CFString, 1, nil)
        guard let destination = destination else {
            throw AppError.thumbnailGenerationFailed(url, "Failed to create image destination")
        }
        
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: 0.3,
            kCGImageDestinationEmbedThumbnail as String: true,
            kCGImagePropertyHasAlpha as String: false
        ]
        
        CGImageDestinationAddImage(destination, outputImage, options)
        guard CGImageDestinationFinalize(destination) else {
            throw AppError.thumbnailGenerationFailed(url, "Failed to save mosaic")
        }
        signposter.endInterval("Save Mosaic", saveInterval)
        
        return outputURL
    }
    
    /// Cancel ongoing mosaic generation
    func cancelMosaicGeneration() {
        mosaicTask?.cancel()
        mosaicTask = nil
        isMosaicGenerating = false
        mosaicProgress = 0
    }
    
    // MARK: - Private Methods
    
    private func drawBackground(_ context: CGContext, size: CGSize) {
        let interval = signposter.beginInterval("Draw Background", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Draw Background", interval) }
        
        context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))
    }
    
    private func drawMetadataHeader(
        _ context: CGContext,
        metadata: String,
        in rect: CGRect,
        fontSize: CGFloat
    ) {
        let interval = signposter.beginInterval("Draw Metadata Header", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Draw Metadata Header", interval) }
        
        // Draw header background
        context.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))
        context.fill(rect)
        
        // Draw metadata text
        drawText(metadata, in: rect, context: context, fontSize: fontSize)
    }
    
    private func drawThumbnails(
        _ context: CGContext,
        thumbnails: [(image: CGImage, timestamp: String)],
        layout: MosaicLayout,
        config: MosaicConfig
    ) {
        let interval = signposter.beginInterval("Draw Thumbnails", id: signposter.makeSignpostID(), "count: \(thumbnails.count)")
        defer { signposter.endInterval("Draw Thumbnails", interval) }
        
        for (index, thumbnail) in thumbnails.enumerated() {
            guard index < layout.positions.count else { break }
            
            let position = layout.positions[index]
            let size = layout.thumbnailSizes[index]
            let rect = CGRect(
                x: position.x,
                y: Int(layout.mosaicSize.height) - Int(size.height) - position.y,
                width: Int(size.width),
                height: Int(size.height)
            )
            
            if config.addShadow {
                context.setShadow(
                    offset: CGSize(width: 3, height: 3),
                    blur: 5,
                    color: CGColor(gray: 0, alpha: 0.5)
                )
            }
            
            // Create rounded rect path
            let path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            context.addPath(path)
            context.clip()
            
            context.draw(thumbnail.image, in: rect)
            context.resetClip()
            
            if config.addBorder {
                context.setStrokeColor(config.borderColor)
                context.setLineWidth(config.borderWidth)
                context.addPath(path)
                context.strokePath()
            }
            
            // Draw timestamp
            drawTimestamp(thumbnail.timestamp, in: rect, context: context)
        }
    }
    
    private func generateMosaicMetadata(
        url: URL,
        fileSize: Int64,
        duration: Double,
        resolution: String,
        codec: String,
        layout: MosaicLayout
    ) -> (text: String, headerHeight: CGFloat, fontSize: CGFloat) {
        let interval = signposter.beginInterval("Generate Metadata", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Generate Metadata", interval) }
        
        let metadata = """
        File: \(url.lastPathComponent) | Location: \(url.deletingLastPathComponent().lastPathComponent)
        Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)) | Duration: \(formatTimestamp(seconds: duration))
        Resolution: \(resolution) | Codec: \(codec)
        """
        
        let headerHeight: CGFloat = layout.mosaicSize.height / 15
        let lineHeight: CGFloat = headerHeight / 3
        let fontSize: CGFloat = lineHeight / 1.618
        
        return (metadata, headerHeight, fontSize)
    }
    
    private func drawTimestamp(_ timestamp: String, in rect: CGRect, context: CGContext) {
        let fontSize = rect.height / 6 / 1.618
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.cgColor
        ]
        
        let attributedTimestamp = CFAttributedStringCreate(
            nil,
            timestamp as CFString,
            attributes as CFDictionary
        )
        let line = CTLineCreateWithAttributedString(attributedTimestamp!)
        
        context.saveGState()
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.1))
        
        let textRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height / 7
        )
        context.fill(textRect)
        
        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
        let textPosition = CGPoint(
            x: rect.maxX - textWidth - 5,
            y: rect.minY + 10
        )
        
        context.textPosition = textPosition
        CTLineDraw(line, context)
        context.restoreGState()
    }
    
    private func formatTimestamp(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func drawText(_ text: String, in rect: CGRect, context: CGContext, fontSize: CGFloat) {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.cgColor
        ]
        
        let attributedString = CFAttributedStringCreate(
            nil,
            text as CFString,
            attributes as CFDictionary
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString!)    
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, CFAttributedStringGetLength(attributedString!)), path, nil)
     //   let line = CTLineCreateWithAttributedString(attributedString!)
        
        context.saveGState()
       // context.textPosition = CGPoint(x: rect.minX + 10, y: rect.maxY - 30)
        CTFrameDraw(frame, context)
        context.restoreGState()
    }
    
    private func updateMosaicProgress(_ progress: Double, for taskId: UUID) {
        mosaicProgressContinuations[taskId]?.yield(progress)
    }
}

// MARK: - Error Handling
private extension Error {
    var isCancelled: Bool {
        (self as? CancellationError) != nil
    }
}
