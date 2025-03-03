import Foundation
import Combine

@MainActor
class PreviewGenerationCoordinator: ObservableObject {
    @Published var tasks: [PreviewGenerationTask] = []
    @Published var activeTaskID: UUID?
    
    private let videoProcessor: VideoProcessor
    private var cancellables = Set<AnyCancellable>()
    
    init(videoProcessor: VideoProcessor) {
        self.videoProcessor = videoProcessor
    }
    
    func addTask(_ task: PreviewGenerationTask) {
        DispatchQueue.main.async {
            self.tasks.append(task)
            self.processNextTask()
        }
    }
    
    private func processNextTask() {
        guard activeTaskID == nil, let nextTask = tasks.first(where: { $0.status == .queued }) else { return }
        
        activeTaskID = nextTask.id
        updateTaskStatus(nextTask.id, .inProgress)
        
        let viewModel = PreviewGenerationViewModel(videoURL: nextTask.videoURL, videoProcessor: videoProcessor)
        viewModel.generatePreview()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self else { return }
                switch completion {
                case .finished:
                    self.updateTaskStatus(nextTask.id, .completed)
                case .failure(let error):
                    self.updateTaskStatus(nextTask.id, .failed(error: error))
                }
                self.activeTaskID = nil
                self.processNextTask()
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    private func updateTaskStatus(_ id: UUID, _ status: GenerationStatus) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].status = status
        }
    }
}

struct PreviewGenerationTask: Identifiable {
    let id: UUID
    let videoURL: URL
    var status: GenerationStatus
    let timestamp: Date
    
    init(id: UUID = UUID(), videoURL: URL, status: GenerationStatus = .queued) {
        self.id = id
        self.videoURL = videoURL
        self.status = status
        self.timestamp = Date()
    }
} 