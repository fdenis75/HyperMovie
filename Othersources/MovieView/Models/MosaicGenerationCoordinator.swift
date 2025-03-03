import Foundation
import SwiftUI
import OSLog
import os.signpost

/// Represents the status of a mosaic generation task
enum MosaicTaskStatus: Hashable {
    case queued
    case processing
    case completed
    case failed(Error)
    case cancelled
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .queued: hasher.combine(0)
        case .processing: hasher.combine(1)
        case .completed: hasher.combine(2)
        case .failed: hasher.combine(3)
        case .cancelled: hasher.combine(4)
        }
    }
    
    static func == (lhs: MosaicTaskStatus, rhs: MosaicTaskStatus) -> Bool {
        switch (lhs, rhs) {
        case (.queued, .queued): return true
        case (.processing, .processing): return true
        case (.completed, .completed): return true
        case (.failed, .failed): return true
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
}

/// Represents a single mosaic generation task
struct MosaicGenerationTask: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let config: MosaicConfig
    let smartFolderName: String?
    
    static func == (lhs: MosaicGenerationTask, rhs: MosaicGenerationTask) -> Bool {
        lhs.id == rhs.id
    }
}

/// Tracks progress for a single mosaic generation task
struct MosaicTaskProgress {
    let taskId: UUID
    var status: MosaicTaskStatus
    var progress: Double
    var startTime: Date?
    var endTime: Date?
    
    var duration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }
}

/// Main coordinator for parallel mosaic generation
@MainActor
final class MosaicGenerationCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var activeTasksProgress: [UUID: MosaicTaskProgress] = [:]
    @Published private(set) var queuedTasks: [MosaicGenerationTask] = []
    @Published private(set) var isProcessing = false
    @Published var maxConcurrentTasks: Int = 4 {
        didSet {
            UserDefaults.standard.set(maxConcurrentTasks, forKey: "MosaicMaxConcurrentTasks")
        }
    }
    
    // MARK: - Private Properties
    private let videoProcessor: VideoProcessor
    private var activeTasks: [UUID: Task<URL, Error>] = [:]
    private var taskGroup: ThrowingTaskGroup<Void, Error>?
    private let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "com.movieview", category: "MosaicGeneration")
    private let ioQueue = DispatchQueue(label: "com.movieview.mosaic-io", qos: .utility)
    private let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical])
    
    // MARK: - Initialization
    init(videoProcessor: VideoProcessor) {
        self.videoProcessor = videoProcessor
        self.maxConcurrentTasks = UserDefaults.standard.integer(forKey: "MosaicMaxConcurrentTasks")
        if self.maxConcurrentTasks == 0 {
            self.maxConcurrentTasks = ProcessInfo.processInfo.activeProcessorCount
        }
        
        // Handle memory pressure
        memoryPressureSource.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }
        memoryPressureSource.resume()
    }
    
    // MARK: - Public Methods
    
    /// Add a new mosaic generation task to the queue
    func addTask(_ task: MosaicGenerationTask) {
        let interval = signposter.beginInterval("Queue Task", id: signposter.makeSignpostID(), "file: \(task.url.lastPathComponent)")
        defer { signposter.endInterval("Queue Task", interval) }
        
        Logger.mosaicGeneration.info("Adding new mosaic task \(task.id) for \(task.url.lastPathComponent)")
        queuedTasks.append(task)
        activeTasksProgress[task.id] = MosaicTaskProgress(
            taskId: task.id,
            status: .queued,
            progress: 0,
            startTime: nil
        )
        
        processQueueIfNeeded()
    }
    
    /// Cancel a specific task
    func cancelTask(id: UUID) {
        Logger.mosaicGeneration.warning("⏹ Cancelling task \(id)")
        if let task = activeTasks[id] {
            task.cancel()
            activeTasks[id] = nil
            updateTaskProgress(id: id, status: .cancelled)
            Logger.mosaicGeneration.info("🗑 Removed task \(id) from active tasks")
        } else {
            queuedTasks.removeAll { $0.id == id }
            Logger.mosaicGeneration.info("🗑 Removed task \(id) from queue")
        }
    }
    
    /// Cancel all tasks
    func cancelAllTasks() {
        let interval = signposter.beginInterval("Cancel All Tasks", id: signposter.makeSignpostID())
        defer { signposter.endInterval("Cancel All Tasks", interval) }
        
        Logger.mosaicGeneration.info("Cancelling all mosaic tasks")
        let taskCount = activeTasks.count + queuedTasks.count
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
        queuedTasks.removeAll()
        activeTasksProgress.keys.forEach { id in
            activeTasksProgress[id]?.status = .cancelled
        }
        isProcessing = false
        Logger.mosaicGeneration.info("Cancelled \(taskCount) tasks")
    }
    
    // MARK: - Private Methods
    
    private func processQueueIfNeeded() {
        guard !isProcessing else {
            Logger.mosaicGeneration.debug("Queue processing already in progress")
            return
        }
        
        Logger.mosaicGeneration.info("""
        🚦 Starting queue processing
        - Queued tasks: \(self.queuedTasks.count)
        - Active tasks: \(self.activeTasks.count)
        - Concurrency limit: \(self.maxConcurrentTasks)
        """)
        
        let interval = signposter.beginInterval("Process Queue", id: signposter.makeSignpostID(), "tasks: \(self.queuedTasks.count)")
        isProcessing = true
        
        Task {
            await withTaskGroup(of: Void.self) { group in
                while !queuedTasks.isEmpty {
                    if activeTasks.count >= maxConcurrentTasks {
                        Logger.mosaicGeneration.debug("""
                        🚧 Concurrency limit reached
                        - Active: \(self.activeTasks.count)
                        - Limit: \(self.maxConcurrentTasks)
                        """)
                        await Task.yield()
                        continue
                    }
                    
                    // Get task without removing first
                    guard let task = queuedTasks.first else { break }
                    
                    // Add to processing group first
                    group.addTask(priority: .userInitiated) {
                        await self.processSingleTask(task)
                    }
                    
                    // Then remove from queue after adding to group
                    queuedTasks.removeFirst()
                    
                    Logger.mosaicGeneration.info("""
                    🚀 Starting task \(task.id)
                    - File: \(task.url.lastPathComponent)
                    - Config: \(task.config.description)
                    - Smart folder: \(task.smartFolderName ?? "None")
                    """)
                }
            }
            isProcessing = false
            Logger.mosaicGeneration.info("""
            🏁 Queue processing completed
            - Total processed: \(self.activeTasksProgress.count)
            - Remaining: \(self.queuedTasks.count)
            """)
            signposter.endInterval("Process Queue", interval)
        }
    }
    
    private func processSingleTask(_ task: MosaicGenerationTask) async {
        activeTasks[task.id] = Task {
            try await videoProcessor.generateMosaic(
                url: task.url,
                config: task.config,
                smartFolderName: task.smartFolderName,
                taskId: task.id
            )
        }
        
        do {
            _ = try await activeTasks[task.id]?.value
            await MainActor.run {
                self.updateTaskProgress(id: task.id, status: .completed)
            }
        } catch {
            await MainActor.run {
                self.updateTaskProgress(id: task.id, status: .failed(error))
            }
        }
        
        activeTasks.removeValue(forKey: task.id)
        
        // Log completion using the progress data
        if let progress = activeTasksProgress[task.id] {
            Logger.mosaicGeneration.debug("""
            ✅ Task \(String(describing: task.id)) finalized
            - Status: \(String(describing: progress.status))
            - Duration: \(String(format: "%.2fs", progress.duration ?? 0))
            """)
        }
    }
    
    private func updateTaskProgress(
        id: UUID,
        status: MosaicTaskStatus? = nil,
        progress: Double? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        var taskProgress = activeTasksProgress[id] ?? MosaicTaskProgress(
            taskId: id,
            status: .queued,
            progress: 0,
            startTime: nil
        )
        
        if let status = status {
            let previousStatus = taskProgress.status
            taskProgress.status = status
            
            Logger.mosaicGeneration.info("🔄 Status change for \(String(describing: id))")
            Logger.mosaicGeneration.info("🔄 Status change for \(String(describing: id))")
        }
        
        if let progress = progress {
            Logger.mosaicGeneration.debug("""
            📊 Progress update for \(id)
            - Progress: \(String(format: "%.1f%%", progress * 100))
            """)
            taskProgress.progress = progress
        }
        
        if let startTime = startTime {
            Logger.mosaicGeneration.info("⏳ Task \(id) started processing")
            taskProgress.startTime = startTime
        }
        
        if let endTime = endTime {
            taskProgress.endTime = endTime
            Logger.mosaicGeneration.info("""
            ✅ Task \(String(describing: id)) completed
            - Final status: \(String(describing: taskProgress.status))
            - Duration: \(String(format: "%.2fs", taskProgress.duration ?? 0))
            """)
        }
        
        activeTasksProgress[id] = taskProgress
    }
    
    private func handleMemoryPressure() async {
        await MainActor.run { [weak self] in
            guard let self else { return }
            
            let oldLimit = self.maxConcurrentTasks
            self.maxConcurrentTasks = max(1, ProcessInfo.processInfo.activeProcessorCount / 2)
            
            Logger.mosaicGeneration.warning("""
            🚨 Memory pressure detected
            - Old concurrency limit: \(oldLimit)
            - New concurrency limit: \(self.maxConcurrentTasks)
            - Active tasks: \(self.activeTasks.count)
            """)
            
            self.activeTasks.values.forEach { task in
                Logger.mosaicGeneration.debug("⚠️ Reducing priority for \(String(describing: task))")
            }
        }
    }
} 
