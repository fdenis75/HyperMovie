import SwiftUI

struct VideoPreviewGeneratorView: View {
    let videoURLs: [URL]
    @StateObject private var viewModel: PreviewGenerationViewModel
    @State private var duration: Double = 30.0
    @State private var thumbnailCount: Int = 12
    @State private var selectedVideoURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    init(videoURLs: [URL]) {
        self.videoURLs = videoURLs
        // Initialize with first video if available
        let initialURL = videoURLs.first ?? URL(fileURLWithPath: "")
        _viewModel = StateObject(wrappedValue: PreviewGenerationViewModel(videoURL: initialURL, videoProcessor: VideoProcessor()))
    }
    
    // Convenience initializer for single video
    init(videoURL: URL) {
        self.init(videoURLs: [videoURL])
    }
    
    var body: some View {
        HSplitView {
            // Video List
            List(videoURLs, id: \.self, selection: $selectedVideoURL) { url in
                HStack {
                    Text(url.lastPathComponent)
                    Spacer()
                    if viewModel.currentVideoURL == url && viewModel.isGenerating {
                        ProgressView(value: viewModel.progress)
                            .frame(width: 60)
                    }
                }
            }
            .frame(minWidth: 200, maxWidth: 300)
            .listStyle(.sidebar)
            
            // Preview Settings
            VStack(spacing: 20) {
                Text("Generate Video Preview")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Form {
                    Section("Preview Settings") {
                        HStack {
                            Text("Duration:")
                            Slider(value: $duration, in: 10...120, step: 5) {
                                Text("Duration")
                            }
                            Text("\(Int(duration))s")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Density:")
                            Slider(value: .init(
                                get: { Double(thumbnailCount) },
                                set: { thumbnailCount = Int($0) }
                            ), in: 4...24, step: 1) {
                                Text("Density")
                            }
                            Text("\(thumbnailCount)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Section("Save Location") {
                        PreviewSaveSettings(
                            savePath: $viewModel.customSavePath,
                            useDefaultPath: $viewModel.useDefaultSavePath,
                            defaultPath: viewModel.currentSavePath,
                            onSavePathSelected: { path in
                                viewModel.customSavePath = path
                            }
                        )
                    }
                }
                .formStyle(.grouped)
                
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        Task {
                            guard let url = selectedVideoURL else { return }
                            do {
                                let outputURL = try await viewModel.generatePreview(
                                    for: url,
                                    duration: duration,
                                    thumbnailCount: thumbnailCount
                                )
                                print("Preview saved to: \(outputURL.path)")
                            } catch {
                                print("Error generating preview: \(error)")
                            }
                        }
                    } label: {
                        Text("Generate Preview")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedVideoURL == nil || viewModel.isGenerating)
                    
                    Button {
                        Task {
                            for url in videoURLs {
                                do {
                                    let outputURL = try await viewModel.generatePreview(
                                        for: url,
                                        duration: duration,
                                        thumbnailCount: thumbnailCount
                                    )
                                    print("Preview saved to: \(outputURL.path)")
                                } catch {
                                    print("Error generating preview for \(url.lastPathComponent): \(error)")
                                }
                            }
                            dismiss()
                        }
                    } label: {
                        Text("Generate All")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isGenerating)
                }
            }
            .padding()
            .frame(minWidth: 400)
        }
        .frame(minWidth: 700, minHeight: 400)
        .onChange(of: selectedVideoURL) { url in
            if let url = url {
                viewModel.updateDefaultPath(for: url)
            }
        }
    }
}

#Preview {
    VideoPreviewGeneratorView(videoURLs: [
        URL(fileURLWithPath: "/Users/example/movie1.mp4"),
        URL(fileURLWithPath: "/Users/example/movie2.mp4")
    ])
} 