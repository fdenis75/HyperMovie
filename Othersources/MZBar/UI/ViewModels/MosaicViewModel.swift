import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import AVFoundation

@available(macOS 14.0, *)
public class MosaicViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    // Mode Selection
    @Published var selectedFile: FileProgress?
   

    // Input Management
    @Published var inputPaths: [(String,Int)] = []
    @Published var inputType: InputType = .folder
    
    // Processing Settings
    @Published var isAutoLayout = false
    @Published var selectedSize = 5120
    @Published var selectedduration = 0
    @Published var selectedDensity = 4.0
    @Published var previewDensity = 4.0
    @Published var selectedFormat = "heic"
    @Published var previewDuration: Double = 60.0
    @Published var concurrentOps = 8
    @Published var codec: String = "AVAssetExportPresetHEVC1920x1080"
    // Processing Options
    @Published var overwrite = false
    @Published var saveAtRoot = false
    @Published var seperate = false
    @Published var summary = false
    @Published var customLayout = true
    @Published var addFullPath = false
    @Published var layoutName = "Focus"
    @Published var selectedPlaylistType = 0
    @Published var previewEngine = PreviewEngine.avFoundation
    @Published var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var endDate: Date = Date()
    
    // State
    @Published var isProcessing = false
    @Published var progressG: Double = 0
    @Published var finalResult: [ResultFiles] = []
    @Published var displayProgress = false

    
    // Status Messages
    @Published var statusMessage1: String = ""
    @Published var statusMessage2: String = ""
    @Published var statusMessage3: String = ""
    @Published var statusMessage4: String = ""
    
    // Progress Details
    @Published private(set) var currentFile: String = ""
    @Published private(set) var processedFiles: Int = 0
    @Published private(set) var totalFiles: Int = 0
    @Published private(set) var skippedFiles: Int = 0
    @Published private(set) var errorFiles: Int = 0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var estimatedTimeRemaining: TimeInterval = 0
    @Published private(set) var fps: Double = 0
    @Published private(set) var activeFiles: [FileProgress] = []
    private let maxConcurrentFiles = 24 // Match with your generator config
    @Published var autoProcessDroppedFiles: Bool = false
    
    @Published var config: MosaicGeneratorConfig = .default
    
    @Published private(set) var queuedFiles: [FileProgress] = []
    @Published private(set) var currentlyProcessingFile: URL?
    @Published private(set) var failedFiles: Set<URL> = []
    @Published private(set) var completedFiles: [FileProgress] = []
    @Published private(set) var doneFiles: [ResultFiles] = []
    
    @Published var allMosaics: [MosaicEntry] = []
    @Published var availableFolders: [String] = []
    @Published var availableResolutions: [String] = []
    @Published var availableWidths: [String] = []
    @Published var availableDensities: [String] = []
    @Published var isLoading: Bool = false
    
    // Playlist Settings
    @Published var includePartialVideos = false
    @Published var prioritizeLongerVideos = false
    
    private let databaseManager: DatabaseManager
    /*
    init(databaseManager: DatabaseManager = DatabaseManager.shared) {
        self.databaseManager = databaseManager
        self.pip
    }*/
    
    // Call this after initialization when ready to migrate
    func performInitialMigration() async throws {
        try await migrateDatabase()
    }
    
    func migrateDatabase() async throws {
        // Create migration manager
        let migrationManager = try DatabaseMigrationManager()
        
        // Run migration on background thread
        try await Task.detached(priority: .userInitiated) {
            try migrationManager.migrateToNewSchema()
        }.value
    }
    
    
    @Published var compressionQuality: Float = 0.4 {
        didSet {
            config.compressionQuality = compressionQuality
            updateConfig()
        }
    }
    // MARK: - Constants
    let sizes = [2000, 4000, 5120, 8000, 10000]
    let densities = ["XXS", "XS", "S", "M", "L", "XL", "XXL"]
    let formats = ["heic", "jpeg"]
    let durations = [0, 10, 30, 60, 120, 300, 600]
    let layouts = ["Classic", "Focus"]
    let concurrent = [1,2,4,8,16,24,32]
    
    // MARK: - Private Properties
    private let pipeline: ProcessingPipeline
    @Published var selectedMode: TabSelection = .mosaic {
            didSet {
                // Notify views to apply the new theme when mode changes
                currentTheme = AppTheme(from: selectedMode)
            }
        }
        
        @Published var currentTheme: AppTheme = .mosaic

    // MARK: - Initialization
    override public init() {
        let Pconfig = ProcessingConfiguration(
            width: 5120,
            density: "M",
            format: "heic",
            duration: 0,
            previewDuration: 60,
            previewDensity: "M",
            overwrite: false,
            saveAtRoot: false,
            separateFolders: true,
            summary: false,
            customLayout: true,
            addFullPath: false,
            generatorConfig: .default
        )
        self.pipeline = ProcessingPipeline(config: Pconfig)
        self.databaseManager = DatabaseManager.shared
        super.init()
        setupPipeline()
        loadSavedOutputFolder()
        print("🔄 MosaicViewModel initialized")
    }
    
    // Add a property to retain the window
    private var browserWindow: NSWindow?
    
    public func showMosaicBrowser() {
    browserWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 2000, height: 1000),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    browserWindow?.title = "Mosaic Browser"
    browserWindow?.contentView = NSHostingView(rootView: MosaicBrowserView(viewModel: self))
    browserWindow?.center()
    browserWindow?.makeKeyAndOrderFront(nil)
    browserWindow?.isReleasedWhenClosed = false
    
    if let window = browserWindow {
        WindowManager.shared.addWindow(window)
    }
    }

    private var navigatorWindow: NSWindow?
    func showMosaicNavigator() {
        navigatorWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 2000, height: 1000),
            styleMask: [.closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        self.currentTheme = .mosaic
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .windowBackground
        navigatorWindow?.contentView = visualEffect

        navigatorWindow?.styleMask.insert(.titled)
        navigatorWindow?.titlebarAppearsTransparent = true
        navigatorWindow?.titleVisibility = .hidden
        navigatorWindow?.standardWindowButton(.miniaturizeButton)?.isHidden = false
        navigatorWindow?.standardWindowButton(.closeButton)?.isHidden = false
        navigatorWindow?.standardWindowButton(.zoomButton)?.isHidden = false
        navigatorWindow?.isMovableByWindowBackground = true
   
        navigatorWindow?.contentView = NSHostingView(rootView: MosaicNavigatorView(viewModel: self))
        navigatorWindow?.center()
        navigatorWindow?.makeKeyAndOrderFront(nil)
        navigatorWindow?.isReleasedWhenClosed = false
    
        if let window = navigatorWindow {
            WindowManager.shared.addWindow(window)
        }
        
        //Task {
          //  await fetchMosaics()
       // }
    }
    
    
    // MARK: - Public Methods
    @MainActor
    func processMosaics() {
        guard !inputPaths.isEmpty else {
            statusMessage1 = "Please select input first."
            return
        }
        displayProgress = true
        isProcessing = true
        statusMessage1 = "Starting processing..."
        
        Task {
            do {
                let config = getCurrentConfig()
                let files = try await getInputFiles(Pconfig: config)
                await MainActor.run {
                    queuedFiles = files.map { file in
                        FileProgress(filename: file.0.path)
                    }
                }

                self.finalResult = try await pipeline.generateMosaics(
                    for: files,
                    config: config
                ) { result in
                    if case let .success((input, outputURL)) = result {
                        Task { @MainActor in
                            self.completeFileProgress(input.path, outputURL: outputURL)
                            self.doneFiles.append(ResultFiles(video: input, output: outputURL))
                        }
                    }
                }
                
                
                
                await MainActor.run {
                       print("we are here")
                    isProcessing = false
                    completeProcessing(success: true)

                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    @MainActor
    func processPreviews() {
        guard !inputPaths.isEmpty else {
            statusMessage1 = "Please select input first."
            return
        }
        displayProgress = true
        isProcessing = true
        statusMessage1 = "Starting processing..."
        
        Task {
            do {
                let config = getCurrentConfig()
                let files = try await getInputFiles(Pconfig: config)
                await MainActor.run {
                    queuedFiles = files.map { file in
                        FileProgress(filename: file.0.path)
                    }
                }
                
                
                try await pipeline.generatePreviews(
                    for: files,
                    config: config
                )
                
                
                await MainActor.run {
                    isProcessing = false
                    completeProcessing(success: true)
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    @MainActor
    func updateMaxConcurrentTasks() {
        pipeline.updateMaxConcurrentTasks(concurrentOps)
    }
    @MainActor
    func updateCodec() {
        pipeline.updateCodec(codec)
    }
    @MainActor
    func generateMosaictoday() {
        isProcessing = true
        statusMessage1 = "Starting today's mosaic generation..."
        displayProgress = true

        Task {
            do {
                
                let files = try await pipeline.getTodayFiles(width: selectedSize)
                let playlist = try await pipeline.createPlaylisttoday()
                let config = getCurrentConfig()
                await MainActor.run {
                    queuedFiles = files.map { file in
                        FileProgress(filename: file.0.path)
                    }
                }
                let mosaics = try await pipeline.generateMosaics(
                    for: files,
                    config: config
                ) { result in
                    if case let .success((input, outputURL)) = result {
                        Task { @MainActor in
                            self.completeFileProgress(input.path, outputURL: outputURL)
                        }
                    }
                }
                
                await MainActor.run {
                    isProcessing = false
                    completeProcessing(success: true)
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    @MainActor
    func generatePlaylist(_ path: String) {
        isProcessing = true
        statusMessage1 = "Starting playlist generation..."
        displayProgress = true

        Task {
            do {
                let playlistURL = try await pipeline.createPlaylist(
                    from: path, 
                    playlistype: selectedPlaylistType,
                    outputFolder: playlistOutputFolder
                )
                await MainActor.run {
                    self.lastGeneratedPlaylistURL = playlistURL
                    isProcessing = false
                    completeProcessing(success: true, message: "Playlist generation completed")
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }


    
    func generateDateRangePlaylist() {
        isProcessing = true
        statusMessage1 = "Starting date range playlist generation..."
        displayProgress = true

        Task {
            do {
                let playlistURL = try await pipeline.createDateRangePlaylist(
                    from: startDate,
                    to: endDate,
                    playlistype: selectedPlaylistType,
                    outputFolder: playlistOutputFolder
                )
                await MainActor.run {
                    self.lastGeneratedPlaylistURL = playlistURL
                    isProcessing = false
                    completeProcessing(success: true, message: "Date range playlist generation completed")
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    func generatePlaylisttoday() {
        isProcessing = true
        statusMessage1 = "Starting playlist today generation..."
        displayProgress = true

        Task {
            do {
                let playlistURL = try await pipeline.createPlaylisttoday(
                    outputFolder: playlistOutputFolder
                )
                await MainActor.run {
                    self.lastGeneratedPlaylistURL = playlistURL
                    completeProcessing(success: true, message: "Playlist generation completed")
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    
    func cancelGeneration() {
        pipeline.cancel()
        statusMessage1 = "Cancelling generation..."
        
        // Update UI state
        queuedFiles.forEach { file in
            if let index = queuedFiles.firstIndex(where: { $0.id == file.id }) {
                queuedFiles[index].isCancelled = true
                queuedFiles[index].stage = "Cancelled"
            }
        }
        
        isProcessing = false
        displayProgress = true
        
        // Clear status messages for cancellation
        statusMessage2 = ""
        statusMessage3 = ""
        statusMessage4 = ""
        
        showCancellationNotification()
    }
    
    // MARK: - Private Methods
    
    private func setupPipeline() {
        pipeline.progressHandler = { [weak self] info in
            Task { @MainActor in
                self?.updateProgress(with: info)
            }
        }
    }
    
    private func getCurrentConfig() -> ProcessingConfiguration {
        if layoutName == "Focus" { customLayout = true }
        else { customLayout = false }
        
        // Update the generator config with current compression quality
        if let preset = QualityPreset(rawValue: selectedQualityPreset) {
            config.compressionQuality = preset.compressionQuality
        }
        config.videoExportPreset = codec
        
        return ProcessingConfiguration(
            width: selectedSize,
            density: DensityConfig.densityFrom(selectedDensity),
            format: selectedFormat,
            duration: selectedduration,
            previewDuration: Int(previewDuration),
            previewDensity:  DensityConfig.extractsFrom(previewDensity),
            overwrite: overwrite,
            saveAtRoot: saveAtRoot,
            separateFolders: seperate,
            summary: summary,
            customLayout: customLayout,
            addFullPath: addFullPath,
            addBorder: addBorder,
            addShadow: addShadow,
            borderColor: NSColor(borderColor).cgColor,
            borderWidth: CGFloat(borderWidth),
            generatorConfig: config,
            orientation: selectedAspectRatio.rawValue,
            useAutoLayout: isAutoLayout
    
        )
    }
    @MainActor
    private func updateProgress(with info: ProgressInfo) {
        // Since this might be called from a background thread, ensure we're on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if (info.progressType == .global) {
                self.progressG = info.progress.isNaN ? 0.0 : info.progress
                self.processedFiles = info.processedFiles
                self.totalFiles = info.totalFiles
                self.skippedFiles = info.skippedFiles
                self.errorFiles = info.errorFiles
                self.elapsedTime = info.elapsedTime
                self.estimatedTimeRemaining = info.estimatedTimeRemaining
                self.updateStatusMessages(stage: info.currentStage)
                self.fps = info.fps ?? 0.0
            } else {
                self.currentFile = info.currentFile
                self.updateFileProgress(info.currentFile, progress: info.fileProgress ?? 0.0, stage: info.currentStage)
                if info.fileProgress == 1.0 {
                    self.completeFileProgress(info.currentFile)
                    self.doneFiles.append(info.doneFile)
                }
            }
            
            self.isProcessing = info.isRunning
        }
    }
   /*  @MainActor
    private func updateProgress(with info: ProgressInfo) {
        // Since this might be called from a background thread, ensure we're on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if (info.progressType == .global) {
                self.progressG = info.progress.isNaN ? 0.0 : info.progress
                self.processedFiles = info.processedFiles
                self.totalFiles = info.totalFiles
                self.skippedFiles = info.skippedFiles
                self.errorFiles = info.errorFiles
                self.elapsedTime = info.elapsedTime
                self.estimatedTimeRemaining = info.estimatedTimeRemaining
                self.updateStatusMessages(stage: info.currentStage)
                self.fps = info.fps ?? 0.0
            } else {
                self.currentFile = info.currentFile
                self.updateFileProgress(info.currentFile, progress: info.fileProgress ?? 0.0, stage: info.currentStage)
                if info.fileProgress == 1.0 {
                    self.completeFileProgress(info.currentFile)
                    self.doneFiles.append(info.doneFile)
                }
            }
            
            self.isProcessing = info.isRunning
        }
    } 
*/
    @MainActor
    private func updateStatusMessages(stage: String) {
        statusMessage1 = "Processing: \(currentFile.substringWithRange(0,end: 30))..."
        statusMessage2 = "Progress: \(processedFiles)/\(totalFiles) files (skipped: \(skippedFiles), Error: \(errorFiles))"
        statusMessage3 = "Stage: \(stage)"
        statusMessage4 = "Estimated Time Remaining: \(estimatedTimeRemaining.format(2))s (current speed : \(fps.format(2)) files/s)"
    }
    @MainActor
    private func updateFileProgress(_ filename: String, progress: Double, stage: String) {
        // Since we're already on the main thread from updateProgress, we don't need another dispatch
        if let index = queuedFiles.firstIndex(where: { $0.filename == filename }) {
            queuedFiles[index].progress = progress
            queuedFiles[index].stage = stage
        } else {
            return
        }
    }
    /*
    private func addFileProgress(_ filename: String) {
        // Since we're already on the main thread from updateProgress, we don't need another dispatch
        if activeFiles.count >= maxConcurrentFiles {
            if let completeIndex = activeFiles.firstIndex(where: { $0.isComplete }) {
                activeFiles.remove(at: completeIndex)
            }
        }
        
        if activeFiles.count < maxConcurrentFiles {
            activeFiles.append(FileProgress(filename: filename))
        }
    }*/
    @MainActor
    private func completeFileProgress(_ filename: String, outputURL: URL? = nil) {
        Task { @MainActor in
            // Safely find and update the file
            if let index = queuedFiles.firstIndex(where: { $0.filename == filename }) {
                // Update the file status
                queuedFiles[index].progress = 1.0
                queuedFiles[index].stage = "Complete"
                queuedFiles[index].isComplete = true
                queuedFiles[index].outputURL = outputURL
                
                // Create a copy of the completed file
                let completedFile = queuedFiles[index]
                
                // Safely remove from queued and add to completed
                completedFiles.append(completedFile)
                queuedFiles.remove(at: index)
            }
        }
    }
    
    
    private func getInputFiles(Pconfig: ProcessingConfiguration) async throws -> [(URL, URL)] {
        switch inputType {
        case .folder:
            return try await pipeline.getFiles(from: inputPaths[0].0, width: selectedSize, config: Pconfig)
        case .m3u8:
            return try await pipeline.getFiles(from: inputPaths[0].0, width: selectedSize, config: Pconfig )
        case .files:
            // Create an array to hold all the results
            var allFiles: [(URL, URL)] = []
            
            // Process each path sequentially
            for (path, _ ) in inputPaths {
                let files = try await pipeline.getSingleFile(from: path, width: selectedSize)
                allFiles.append(contentsOf: files)
            }
            
            return allFiles
        }
    }
    @MainActor
    private func completeProcessing(success: Bool, message: String? = nil) {
        // Update status messages
        statusMessage1 = message ?? (success ? "Processing completed successfully!" : "Processing completed with errors")
        
        // Show notification
        let content = UNMutableNotificationContent()
        content.title = success ? "Processing Complete" : "Processing Failed"
        content.body = message ?? (success ? "All files processed successfully" : "Processing completed with some errors")
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        isProcessing = false
        displayProgress = true
        // Reset processing state
        resetProcessingState()
        
        // Set processing flag
        
    }
    @MainActor
    func cancelFile(_ fileId: UUID) {
        if let index = queuedFiles.firstIndex(where: { $0.id == fileId }) {
            let filename = queuedFiles[index].filename
            
            // Update UI state
            queuedFiles[index].isCancelled = true
            queuedFiles[index].stage = "Cancelled"
            
            // Cancel in pipeline
            pipeline.cancelFile(filename)
            
            // Update status if this was the current file
            if statusMessage1.contains(filename) {
                statusMessage1 = "Cancelled: \(filename)"
            }
        }
    }
    @MainActor
    private func handleError(_ error: Error) {
        if error is CancellationError {
            statusMessage1 = "Processing was cancelled"
            isProcessing = false
        } else {
            statusMessage1 = "Error: \(error.localizedDescription)"
            // Mark current file as error if there is one
            if let currentFile = currentlyProcessingFile {
                markFileAsError(currentFile, error: error)
            }
        }
    }
    
    func updateConfig() {
        // Update the config in GenerationCoordinator
        pipeline.updateConfig(config)
    }
    /* private func removeItem(_ path: String) {
     withAnimation {
     inputPaths.removeAll { $0 == path }
     if inputPaths.isEmpty {
     isTargeted = false
     }
     }
     }*/
    
    func retryPreview(for fileId: UUID) {
        Task {
            guard let index = queuedFiles.firstIndex(where: { $0.id == fileId }),
                  queuedFiles[index].stage.contains("Exporting") else { return }
            
            let file = queuedFiles[index]
            
            await MainActor.run {
                queuedFiles[index].progress = 0
                queuedFiles[index].stage = "Retrying preview generation"
            }
            
            pipeline.cancelFile(file.filename)
            
            do {
                let config = getCurrentConfig()
                let files = try await pipeline.getSingleFile(from: file.filename, width: selectedSize)
                try await pipeline.generatePreviews(for: files, config: config)
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    
    @Published var selectedQualityPreset: Int = 0 {
        didSet {
            if let preset = QualityPreset(rawValue: selectedQualityPreset) {
                config.compressionQuality = preset.compressionQuality
                updateConfig()
            }
        }
    }
    
    
    
   
    
    func fileStatus(for file: URL) -> FileStatus {
        if failedFiles.contains(file) {
            return .failed
        } else if completedFiles.contains(where: { $0.filename == file.path }) {
            return .completed
        } else if currentlyProcessingFile == file {
            return .processing
        } else {
            return .queued
        }
    }
    /*
    func cancelFile(_ file: FileProgress) {
        Task {
            await pipeline.cancelFile(file.filename)
            DispatchQueue.main.async {
                self.queuedFiles.removeAll { $0.path == file.filename }
            }
        }
    }*/
    
   /* func retryFile(_ file: FileProgress) {
        DispatchQueue.main.async {
            self.failedFiles.remove(URL(fileURLWithPath: file.filename))
            // Add to beginning of queue for immediate processing
            self.queuedFiles.insert(URL(fileURLWithPath: file.filename), at: 0)
        }
    }*/
    
   // Add method to manually close progress view
func closeProgressView() {
    isProcessing = false
    // Optionally reset progress state here if needed
    progressG = 0
}

    
    func updateCurrentFile(_ file: URL?) {
        DispatchQueue.main.async {
            self.currentlyProcessingFile = file
        }
    }
    
    func markFileAsFailed(_ file: URL) {
        DispatchQueue.main.async {
            self.failedFiles.insert(file)
        }
    }
    
    func markFileAsCompleted(_ file: URL) {
        DispatchQueue.main.async {
            self.completedFiles.append(FileProgress(filename: file.path))
        }
    }
    
    private func showCancellationNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Processing Cancelled"
        content.body = "Mosaic generation has been cancelled"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    @Published var lastGeneratedPlaylistURL: URL? = nil
    
    @Published var playlistOutputFolder: URL? = nil
    
    func setPlaylistOutputFolder(_ url: URL) {
        playlistOutputFolder = url
        // Optionally save to UserDefaults for persistence
        if let bookmarkData = try? url.bookmarkData() {
            UserDefaults.standard.set(bookmarkData, forKey: "PlaylistOutputFolder")
        }
    }
    
    func resetPlaylistOutputFolder() {
        playlistOutputFolder = nil
        UserDefaults.standard.removeObject(forKey: "PlaylistOutputFolder")
    }
    
    private func loadSavedOutputFolder() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "PlaylistOutputFolder") {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if !isStale {
                    playlistOutputFolder = url
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
    }
    
    @Published var isFileDiscoveryCancelled = false
    
    func cancelFileDiscovery() {
        isFileDiscoveryCancelled = true
    }
    
    @Published var selectedAspectRatio: MosaicAspectRatio = .landscape {
        didSet {
            updateAspectRatio()
        }
    }
    
    private func updateAspectRatio() {
        pipeline.updateAspectRatio(selectedAspectRatio.ratio)
    }

    // Add new published properties
    @Published var addBorder = false
    @Published var addShadow = false
    @Published var borderColor = Color.white
    @Published var borderWidth: Double = 2
    
    @Published var isShowingMosaicNavigator: Bool = false

private func resetProcessingState() {
    // Reset counters
    progressG = 0
    processedFiles = 0
    totalFiles = 0
    skippedFiles = 0 
    errorFiles = 0
    elapsedTime = 0
    estimatedTimeRemaining = 0
    fps = 0
    
    // Clear arrays
    queuedFiles.removeAll()
    completedFiles.removeAll()
    activeFiles.removeAll()
    
    // Reset status messages
    statusMessage1 = ""
    statusMessage2 = ""
    statusMessage3 = ""
    statusMessage4 = ""
    
    // Reset file tracking
    currentlyProcessingFile = nil
    failedFiles.removeAll()
}

@MainActor
func markFileAsSkipped(_ file: URL) {
    if let index = queuedFiles.firstIndex(where: { $0.filename == file.path }) {
        var updatedFile = queuedFiles[index]
        updatedFile.isSkipped = true
        queuedFiles[index] = updatedFile
        skippedFiles += 1
    }
}

@MainActor
func markFileAsError(_ file: URL, error: Error) {
    if let index = queuedFiles.firstIndex(where: { $0.filename == file.path }) {
        var updatedFile = queuedFiles[index]
        updatedFile.isError = true
        updatedFile.errorMessage = error.localizedDescription
        updatedFile.stage = "Error: \(error.localizedDescription)"
        queuedFiles[index] = updatedFile
        errorFiles += 1
    }
}

@MainActor
    func fetchMosaics() {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔄 Starting fetchMosaics")
        isLoading = true
        defer { isLoading = false }
        Task {
            do {
                print("📊 Fetching mosaics from database...")
                allMosaics = try await databaseManager.fetchAllMosaics()
                let endTime = CFAbsoluteTimeGetCurrent()
                print("✅ Fetched \(allMosaics.count) mosaics in \((endTime - startTime).formatted()) seconds")
            } catch {
                print("❌ Error fetching mosaics: \(error)")
                allMosaics = []
            }
        }
    }
    




    // Add new properties
    @Published private(set) var isLoadingMore = false
    @Published var hasMoreContent = true
    private var currentPage = 0
    private let pageSize = 50
    
    // Track current filter state
    private var currentSearchQuery: String = ""
    private var currentFilters: [FilterCategory: String] = [:]
    @Published var selectedDateRange: DateRange? = nil
    @Published var cachedFilterValues: [FilterCategory: Set<String>] = [:]
  @Published var loadingProgress: Double = 0.0
  @Published var loadingMessage: String = ""
  @Published var totalCount: Int = 0
  @Published var loadedCount: Int = 0
  @Published var filteredMosaics: [MosaicEntry] = []


    @MainActor
    func applyFilters(searchQuery: String, filters: [FilterCategory: String]) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔄 Applying new filters")
        
        // Only reset and reload if filters actually changed
        if currentSearchQuery != searchQuery || currentFilters != filters {
            currentSearchQuery = searchQuery
            currentFilters = filters
            
            // Reset pagination state
            currentPage = 0
            allMosaics = []
            hasMoreContent = true
            
            // Load first page with new filters
            await loadNextPage()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("✅ Applied filters in \((endTime - startTime).formatted()) seconds")
    }
    
    func loadNextPage() async {
        guard !isLoadingMore && hasMoreContent else {
            print("⏭️ Skipping loadNextPage: isLoadingMore=\(isLoadingMore), hasMoreContent=\(hasMoreContent)")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔄 Starting loadNextPage: page \(currentPage)")
        await MainActor.run { isLoadingMore = true }
        
        do {
            // Create filter parameters
            let filterParams = MosaicFilterParams(
                searchQuery: currentSearchQuery,
                filters: currentFilters,
                dateRange: selectedDateRange,
                batchDateRange: selectedBatchDateRange,
                offset: currentPage * pageSize,
                limit: pageSize
            )
            
            print("📊 Fetching page with filters: \(filterParams)")
            let newMosaics = try await databaseManager.fetchMosaicsPage(
                filterParams: filterParams
            )
            
            await MainActor.run {
                let appendStartTime = CFAbsoluteTimeGetCurrent()
                allMosaics.append(contentsOf: newMosaics)
                let appendEndTime = CFAbsoluteTimeGetCurrent()
                print("📊 Appended \(newMosaics.count) mosaics in \((appendEndTime - appendStartTime).formatted()) seconds")
                
                currentPage += 1
                hasMoreContent = newMosaics.count == pageSize
                isLoadingMore = false
                
                let endTime = CFAbsoluteTimeGetCurrent()
                print("✅ Completed loadNextPage in \((endTime - startTime).formatted()) seconds")
            }
        } catch {
            print("❌ Error loading more mosaics: \(error)")
            await MainActor.run { isLoadingMore = false }
        }
    }
    
    @MainActor
    func refreshMosaics() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔄 Starting refreshMosaics")
        
        // Reset pagination state
        currentPage = 0
        allMosaics = []
        hasMoreContent = true
        
        // Load first page
        await loadNextPage()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("✅ Completed refreshMosaics in \((endTime - startTime).formatted()) seconds")
    }
    
    @MainActor
    func loadFilterValues() async {
        guard cachedFilterValues.isEmpty else {
            print("📋 Using cached filter values")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔄 Starting loadFilterValues")
        
        do {
            cachedFilterValues = try await databaseManager.fetchFilterValues()
            await MainActor.run {
                let updateStartTime = CFAbsoluteTimeGetCurrent()
                // Update UI with cached filter values
                availableFolders = Array(cachedFilterValues[.folder] ?? [])
                let updateEndTime = CFAbsoluteTimeGetCurrent()
                print("📊 Updated filter UI in \((updateEndTime - updateStartTime).formatted()) seconds")
            }
            let endTime = CFAbsoluteTimeGetCurrent()
            print("✅ Completed loadFilterValues in \((endTime - startTime).formatted()) seconds")
        } catch {
            print("❌ Error loading filter values: \(error)")
        }
    }

    @MainActor
    func fetchAllMosaics() async {
        isLoading = true
        loadingMessage = "Loading mosaics..."
        
        do {
            allMosaics = try await databaseManager.fetchMosaicsWithProgress()
            filteredMosaics = allMosaics
            await loadFilterValues()
        } catch {
            print("❌ Error loading mosaics: \(error)")
            loadingMessage = "Error: \(error.localizedDescription)"
            allMosaics = []
            filteredMosaics = []
        }
        
        isLoading = false
    }

    @MainActor
    func applyFilters(searchQuery: String, filters: [FilterCategory: String]) {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔄 Applying filters in memory - current counts: all=\(allMosaics.count), filtered=\(filteredMosaics.count)")
        
        // Only update if filters actually changed
        if currentSearchQuery != searchQuery || currentFilters != filters {
            currentSearchQuery = searchQuery
            currentFilters = filters
            
            // Create a filtered array with initial capacity
            var filtered: [MosaicEntry] = []
            filtered.reserveCapacity(allMosaics.count / 2) // Estimate half will match
            
            // Prepare search terms for case-insensitive search
            let searchTerms = searchQuery.lowercased().split(separator: " ")
            
            // Perform filtering in memory
            for mosaic in allMosaics {
                // Search query filter
                let matchesSearch = searchQuery.isEmpty || searchTerms.allSatisfy { term in
                    mosaic.movieFilePath.localizedCaseInsensitiveContains(term) ||
                    mosaic.folderHierarchy.localizedCaseInsensitiveContains(term)
                }
                
                // Category filters
                let matchesFilters = filters.allSatisfy { category, value in
                    switch category {
                    case .folder:
                        return mosaic.folderHierarchy.contains(value)
                    case .size:
                        return mosaic.size == value
                    case .density:
                        return mosaic.density == value
                    case .layout:
                        return mosaic.layout == value
                    case .videoType:
                        return mosaic.videoType == value
                    case .resolution:
                        return mosaic.resolution == value
                    case .codec:
                        return mosaic.codec == value
                    }
                }
                
                // Duration filter
                let matchesDuration: Bool
                if let duration = selectedDurationFilter.durationInSeconds {
                    if selectedDurationFilter.isMoreThan {
                        matchesDuration = mosaic.duration > duration
                    } else {
                        matchesDuration = mosaic.duration < duration
                    }
                } else {
                    matchesDuration = true
                }
                
                // Movie creation date range filter
                let matchesDateRange: Bool
                if let dateRange = selectedDateRange {
                    matchesDateRange = mosaic.creationDate >= dateRange.start &&
                                     mosaic.creationDate <= dateRange.end
                } else {
                    matchesDateRange = true
                }
                
                // Batch generation date range filter
                let matchesBatchDateRange: Bool
                if let batchDateRange = selectedBatchDateRange {
                    matchesBatchDateRange = mosaic.generationDate >= batchDateRange.start &&
                                          mosaic.generationDate <= batchDateRange.end
                } else {
                    matchesBatchDateRange = true
                }
                
                if matchesSearch && matchesFilters && matchesDuration && matchesDateRange && matchesBatchDateRange {
                    filtered.append(mosaic)
                }
            }
            
            filteredMosaics = filtered
            
            let endTime = CFAbsoluteTimeGetCurrent()
            print("✅ Filtered to \(filteredMosaics.count) mosaics in \((endTime - startTime).formatted()) seconds")
        }
    }

    @MainActor
    func loadFilterValues() {
        // Extract unique values from the loaded mosaics
        var filters: [FilterCategory: Set<String>] = [:]
        
        for mosaic in allMosaics {
            // Folder hierarchy
            if !mosaic.folderHierarchy.isEmpty {
                filters[.folder, default: []].insert(mosaic.folderHierarchy)
            }
            
            // Size
            filters[.size, default: []].insert(mosaic.size)
            
            // Density
            filters[.density, default: []].insert(mosaic.density)
            
            // Layout
            if let layout = mosaic.layout {
                filters[.layout, default: []].insert(layout)
            }
            
            // Video type
            filters[.videoType, default: []].insert(mosaic.videoType)
            
            // Resolution
            filters[.resolution, default: []].insert(mosaic.resolution)
            
            // Codec
            filters[.codec, default: []].insert(mosaic.codec)
        }
        
        cachedFilterValues = filters
    }

    // Add new properties for batch date filtering
    @Published var selectedBatchDateRange: DateRange? = nil
    @Published var batchStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var batchEndDate: Date = Date()

    @Published var selectedDurationFilter: DurationFilter = .all
}

// MARK: - Type Definitions
extension MosaicViewModel {
    enum InputType {
        case folder
        case m3u8
        case files
    }
    
    enum MosaicAspectRatio: String, CaseIterable {
        case landscape = "16:9"
        case square = "1:1"
        case portrait = "9:16"
        
        var ratio: CGFloat {
            switch self {
            case .landscape: return 16.0 / 9.0
            case .square: return 1.0
            case .portrait: return 9.0 / 16.0
            }
        }
    }
}

// MARK: - Theme Support

// Add NSWindowDelegate conformance
extension MosaicViewModel: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        // Clean up the reference when window closes
        browserWindow = nil
    }
}

// Add these methods to MosaicViewModel
extension MosaicViewModel {
    @MainActor
    func generateVariant(for moviePath: String) async {
        isProcessing = true
        statusMessage1 = "Generating new variant..."
        
        Task {
            do {
                let config = getCurrentConfig()
                let files = try await pipeline.getSingleFile(from: moviePath, width: selectedSize)
                
                await MainActor.run {
                    queuedFiles = files.map { file in
                        FileProgress(filename: file.0.path)
                    }
                }
                
                self.finalResult = try await pipeline.generateMosaics(
                    for: files,
                    config: config
                ) { result in
                    if case let .success((input, outputURL)) = result {
                        Task { @MainActor in
                            self.completeFileProgress(input.path, outputURL: outputURL)
                            self.doneFiles.append(ResultFiles(video: input, output: outputURL))
                        }
                    }
                }
                
                await MainActor.run {
                    completeProcessing(success: true)
                    // Refresh the mosaic list to show the new variant
                    Task {
                        await self.refreshMosaics()
                    }
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
}

// Add this method to MosaicViewModel

