import Foundation
import SwiftUI
import Combine

@MainActor
class PreviewGenerationViewModel: ObservableObject {
    @Published var useDefaultSavePath = true
    @Published var customSavePath = ""
    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var status: GenerationStatus = .queued
    
    private var defaultSavePath: URL?
    private let videoURL: URL
    private let videoProcessor: VideoProcessor
    
    var currentVideoURL: URL { videoURL }
    
    nonisolated init(videoURL: URL, videoProcessor: VideoProcessor) {
        self.videoURL = videoURL
        self.videoProcessor = videoProcessor
    }
    
    func generatePreview(
        for url: URL,
        duration: Double,
        thumbnailCount: Int
    ) async throws -> URL {
        isGenerating = true
        progress = 0
        
        defer { isGenerating = false }
        
        return try await VideoPreviewGenerator.generatePreview(
            from: url,
            duration: duration,
            thumbnailCount: thumbnailCount,
            savePath: useDefaultSavePath ? nil : customSavePath
        ) { [weak self] progress in
            Task { @MainActor in
                self?.progress = progress
            }
        }
    }
    
    func updateDefaultPath(for videoURL: URL) {
        defaultSavePath = VideoPreviewGenerator.getDefaultSavePath(for: videoURL)
    }
    
    var currentSavePath: String {
        if useDefaultSavePath {
            return defaultSavePath?.path ?? "Default location not set"
        }
        return customSavePath
    }
    
    func generatePreview() -> AnyPublisher<URL, Error> {
        status = .inProgress
        return Future<URL, Error> { promise in
            Task {
                do {
                    let url = try await VideoPreviewGenerator.generatePreview(
                        from: self.videoURL,
                        duration: 5.0,
                        thumbnailCount: 10,
                        savePath: self.useDefaultSavePath ? nil : self.customSavePath
                    ) { [weak self] progress in
                        Task { @MainActor in
                            self?.progress = progress
                        }
                    }
                    await MainActor.run {
                        self.status = .completed
                        promise(.success(url))
                    }
                } catch {
                    await MainActor.run {
                        self.status = .failed(error: error)
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
} 