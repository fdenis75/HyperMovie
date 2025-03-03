import SwiftUI
import AVKit
import HyperMovieModels
import HyperMovieServices
 

struct VideoDetail: View {
    let video: HyperMovieModels.Video?
    @Environment(HyperMovieServices.AppState.self) private var appState
    @State private var player: AVPlayer?
    @State private var thumbnails: [HyperMovieModels.Video.VideoThumbnail] = []
    @State private var selectedThumbnail: HyperMovieModels.Video.VideoThumbnail?
    @State private var thumbnailSize: Double = 320
    @State private var isGenerating = false
    @State private var isLoadingThumbnails = false
    @State private var error: Error?
    @State private var showMosaicSettings = false
    @State private var showPreviewSettings = false
    @State private var density: DensityConfig = .s
    @State private var videoDuration: Double = 0
    @State private var previewDuration: Double = 60
    @State private var previewDensity: DensityConfig = .s
    @State private var previewURLs: [URL] = []
    
    var body: some View {
        Group {
            if let video {
                VideoDetailContent(
                    video: video,
                    player: $player,
                    thumbnails: $thumbnails,
                    selectedThumbnail: $selectedThumbnail,
                    thumbnailSize: $thumbnailSize,
                    isGenerating: $isGenerating,
                    isLoadingThumbnails: $isLoadingThumbnails,
                    error: $error,
                    showMosaicSettings: $showMosaicSettings,
                    showPreviewSettings: $showPreviewSettings,
                    density: $density,
                    videoDuration: $videoDuration,
                    previewDuration: $previewDuration,
                    previewDensity: $previewDensity
                )
            } else {
                ContentUnavailableView("No Video Selected", 
                                     systemImage: "video.slash", 
                                     description: Text("Select a video to view details"))
            }
        }
    }
}

private struct VideoDetailContent: View {
    let video: HyperMovieModels.Video
    @Binding var player: AVPlayer?
    @Binding var thumbnails: [HyperMovieModels.Video.VideoThumbnail]
    @Binding var selectedThumbnail: HyperMovieModels.Video.VideoThumbnail?
    @Binding var thumbnailSize: Double
    @Binding var isGenerating: Bool
    @Binding var isLoadingThumbnails: Bool
    @Binding var error: Error?
    @Binding var showMosaicSettings: Bool
    @Binding var showPreviewSettings: Bool
    @Binding var density: DensityConfig
    @Binding var videoDuration: Double
    @Binding var previewDuration: Double
    @Binding var previewDensity: DensityConfig
    @Environment(HyperMovieServices.AppState.self) private var appState
    @State private var playerHeight: CGFloat = 300
    @State private var isShowingPreview: Bool = false
    @State private var currentPreviewURL: URL?
    @State private var previewURLs: [URL] = []
    
    var body: some View {
        VStack(spacing: 0) {
            if isShowingPreview, let previewURL = currentPreviewURL {
                VideoPlayerView(player: AVPlayer(url: previewURL))
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .frame(height: playerHeight)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            isShowingPreview = false
                            currentPreviewURL = nil
                            player = AVPlayer(url: video.url)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
            } else {
                VideoPlayerView(player: player)
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .frame(height: playerHeight)
            }
            
            // Preview Controls
            if !previewURLs.isEmpty {
                VStack(spacing: Theme.Layout.Spacing.sm) {
                    Text("Available Previews")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.Text.primary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Layout.Spacing.md) {
                            ForEach(previewURLs, id: \.self) { previewURL in
                                Button {
                                    currentPreviewURL = previewURL
                                    isShowingPreview = true
                                } label: {
                                    VStack {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(Theme.Colors.accent)
                                        Text(previewURL.lastPathComponent)
                                            .font(Theme.Typography.caption1)
                                            .foregroundStyle(Theme.Colors.Text.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 120)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Layout.Spacing.md)
                    }
                }
                .padding(.vertical, Theme.Layout.Spacing.md)
                .background(Theme.Colors.Background.secondary)
            }
            
            Divider()
                .background(Theme.Colors.UI.border)
                .onHover { inside in
                    if inside {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            playerHeight = max(200, playerHeight + value.translation.height)
                        }
                )
            
            ThumbnailGridView(
                video: video,
                thumbnails: $thumbnails,
                selectedThumbnail: $selectedThumbnail,
                thumbnailSize: $thumbnailSize,
                isGenerating: $isGenerating,
                isLoadingThumbnails: $isLoadingThumbnails,
                density: $density,
                showMosaicSettings: $showMosaicSettings,
                showPreviewSettings: $showPreviewSettings,
                onGenerateDefaultPreview: {
                    generatePreview(with: .default)
                },
                onThumbnailSelected: { thumbnail in
                    player?.seek(to: thumbnail.time)
                }
            )
        }
        .onAppear {
            player = AVPlayer(url: video.url)
            loadThumbnails()
            loadPreviews()
        }
        .onChange(of: video) {
            player = AVPlayer(url: video.url)
            thumbnails = []
            selectedThumbnail = nil
            loadThumbnails()
        }
        .onChange(of: density) { _ in
            thumbnails = []
            selectedThumbnail = nil
            loadThumbnails()
        }
        .onChange(of: selectedThumbnail) { thumbnail in
            if let thumbnail {
                player?.seek(to: thumbnail.time)
            }
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            HMButton("OK", style: .primary) {
                error = nil
            }
        } message: {
            if let error {
                Text(error.localizedDescription)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.Text.primary)
            }
        }
        .sheet(isPresented: $showMosaicSettings) {
            MosaicSettingsSheet(video: video, isGenerating: $isGenerating) { config in
                generateMosaic(with: config)
            }
        }
        .sheet(isPresented: $showPreviewSettings) {
            PreviewSettingsSheet(
                video: video,
                isGenerating: $isGenerating,
                duration: $previewDuration,
                density: $previewDensity
            ) { duration, density in
                let config = PreviewConfiguration(
                    duration: duration,
                    density: density,
                    saveInCustomLocation: true
                )
                generatePreview(with: config)
            }
        }
    }
    
    private func calculateThumbnailCount(duration: Double) -> Int {
        if duration < 5 { return 4 }
        
        let base = 320.0 / 200.0 // base on thumbnail width
        let k = 10.0
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, 100)
    }
    
    private func loadThumbnails() {
        isLoadingThumbnails = true
        Task {
            do {
                let frameCount = calculateThumbnailCount(duration: video.duration)
                let thumbnailService = HyperMovieServices.VideoThumbnailService()
                let newThumbnails = try await thumbnailService.generateThumbnails(
                    for: video,
                    count: frameCount,
                    size: CGSize(width: 160, height: 90)
                )
                
                await MainActor.run {
                    thumbnails = newThumbnails
                    isLoadingThumbnails = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isLoadingThumbnails = false
                }
            }
        }
    }
    
    private func generateMosaic(with config: MosaicConfiguration) {
        isGenerating = true
        Task {
            do {
                try await appState.mosaicGenerator.generate(for: video, config: config)
            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    private func generatePreview(with config: PreviewConfiguration) {
        isGenerating = true
        Task {
            do {
                let previewURL = try await appState.previewGenerator.generate(for: video, config: config, progressHandler: { progress in
                    // Update progress
                })
                
                await MainActor.run {
                    if config.saveInCustomLocation {
                        // Open in IINA
                        let iinaPath = "/Applications/IINA.app/Contents/MacOS/IINA"
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: iinaPath)
                        process.arguments = [previewURL.path]
                        try? process.run()
                    } else {
                        // Show in player
                        currentPreviewURL = previewURL
                        isShowingPreview = true
                    }
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    isGenerating = false
                }
            }
        }
    }
    
    private func formatTime(_ time: CMTime) -> String {
        let seconds = Int(time.seconds)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func loadPreviews() {
        if let previewPaths = UserDefaults.standard.dictionary(forKey: "VideoPreviewMap")?[video.url.path] as? [String] {
            previewURLs = previewPaths.map { URL(fileURLWithPath: $0) }
        }
    }
}

private struct ThumbnailGridView: View {
    let video: HyperMovieModels.Video
    @Binding var thumbnails: [HyperMovieModels.Video.VideoThumbnail]
    @Binding var selectedThumbnail: HyperMovieModels.Video.VideoThumbnail?
    @Binding var thumbnailSize: Double
    @Binding var isGenerating: Bool
    @Binding var isLoadingThumbnails: Bool
    @Binding var density: DensityConfig
    @Binding var showMosaicSettings: Bool
    @Binding var showPreviewSettings: Bool
    let onGenerateDefaultPreview: () -> Void
    let onThumbnailSelected: (HyperMovieModels.Video.VideoThumbnail) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            DensityControlView(density: $density, video: video)
            ThumbnailControlsView(
                thumbnailSize: $thumbnailSize,
                isGenerating: isGenerating,
                showMosaicSettings: $showMosaicSettings,
                showPreviewSettings: $showPreviewSettings,
                onGenerateDefaultPreview: onGenerateDefaultPreview
            )
            ThumbnailsScrollView(
                thumbnails: thumbnails,
                selectedThumbnail: $selectedThumbnail,
                thumbnailSize: thumbnailSize,
                isLoadingThumbnails: isLoadingThumbnails,
                onThumbnailSelected: onThumbnailSelected
            )
        }
    }
}

private struct DensityControlView: View {
    @Binding var density: DensityConfig
    let video: HyperMovieModels.Video
    var body: some View {
        HStack(spacing: Theme.Layout.Spacing.md) {
            Text("Density")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.Colors.Text.secondary)
            
            Picker("Density", selection: $density) {
                ForEach(DensityConfig.allCases, id: \.self) { config in
                    Text(config.name + " - \(calculateThumbnailCount(duration: video.duration, density: config)) Thumbnails").tag(config)
                }
            }
            
            Text(density.thumbnailCountDescription)
                .font(Theme.Typography.caption1)
                .foregroundStyle(Theme.Colors.Text.secondary)
        }
        .padding(.horizontal, Theme.Layout.Spacing.md)
        .padding(.vertical, Theme.Layout.Spacing.sm)
    }
    private func calculateThumbnailCount(duration: Double, density: DensityConfig) -> Int {
        if duration < 5 { return 4 }
        
        let base = 320.0 / 200.0 // base on thumbnail width
        let k = 10.0
        let rawCount = base + k * log(duration)
        let totalCount = Int(rawCount / density.factor)
        
        return min(totalCount, 100)
    }
}

private struct ThumbnailControlsView: View {
    @Binding var thumbnailSize: Double
    let isGenerating: Bool
    @Binding var showMosaicSettings: Bool
    @Binding var showPreviewSettings: Bool
    let onGenerateDefaultPreview: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Layout.Spacing.md) {
            HStack(spacing: Theme.Layout.Spacing.sm) {
                Image(systemName: "photo")
                    .font(.system(size: Theme.Layout.IconSize.sm))
                    .foregroundStyle(Theme.Colors.Text.secondary)
                
                Slider(value: $thumbnailSize, in: 160...800, step: 40)
                    .frame(maxWidth: 300)
                
                Image(systemName: "photo.fill")
                    .font(.system(size: Theme.Layout.IconSize.sm))
                    .foregroundStyle(Theme.Colors.Text.secondary)
            }
            
            Spacer()
            
            HStack(spacing: Theme.Layout.Spacing.md) {
                Menu {
                    Button("Quick Preview (30s)") {
                        onGenerateDefaultPreview()
                    }
                    
                    Button("Custom Preview...") {
                        showPreviewSettings = true
                    }
                } label: {
                    HMButton(
                        "Generate Preview",
                        icon: "film",
                        isDisabled: isGenerating
                    ) { }
                }
                
                HMButton(
                    "Generate Mosaic",
                    icon: "square.grid.3x3",
                    isDisabled: isGenerating
                ) {
                    showMosaicSettings = true
                }
            }
        }
        .padding(Theme.Layout.Spacing.md)
        .background(.ultraThinMaterial)
    }
}

private struct ThumbnailsScrollView: View {
    let thumbnails: [HyperMovieModels.Video.VideoThumbnail]
    @Binding var selectedThumbnail: HyperMovieModels.Video.VideoThumbnail?
    let thumbnailSize: Double
    let isLoadingThumbnails: Bool
    let onThumbnailSelected: (HyperMovieModels.Video.VideoThumbnail) -> Void
    
    var body: some View {
        ScrollView {
            if isLoadingThumbnails {
                LoadingView()
            } else {
                ThumbnailGrid(
                    thumbnails: thumbnails,
                    selectedThumbnail: $selectedThumbnail,
                    thumbnailSize: thumbnailSize,
                    isLoadingThumbnails: isLoadingThumbnails,
                    onThumbnailSelected: onThumbnailSelected
                )
            }
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: Theme.Layout.Spacing.sm) {
            ProgressView()
                .controlSize(.large)
            Text("Loading thumbnails...")
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

private struct ThumbnailGrid: View {
    let thumbnails: [HyperMovieModels.Video.VideoThumbnail]
    @Binding var selectedThumbnail: HyperMovieModels.Video.VideoThumbnail?
    let thumbnailSize: Double
    let isLoadingThumbnails: Bool
    let onThumbnailSelected: (HyperMovieModels.Video.VideoThumbnail) -> Void
    
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize * 2), spacing: Theme.Layout.Spacing.md)],
            spacing: Theme.Layout.Spacing.md
        ) {
            ForEach(thumbnails) { thumbnail in
                ThumbnailCell(
                    thumbnail: thumbnail,
                    isSelected: selectedThumbnail == thumbnail,
                    onSelect: {
                        selectedThumbnail = thumbnail
                        onThumbnailSelected(thumbnail)
                    }
                )
            }
        }
        .padding(Theme.Layout.Spacing.md)
    }
}

private struct ThumbnailCell: View {
    let thumbnail: HyperMovieModels.Video.VideoThumbnail
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HMGridItem(
            title: formatTime(thumbnail.time),
            isSelected: isSelected,
            action: onSelect
        ) {
            Image(nsImage: thumbnail.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    private func formatTime(_ time: CMTime) -> String {
        let seconds = Int(time.seconds)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer?
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.player = player
        view.allowsMagnification = true
        view.allowsPictureInPicturePlayback = true
        view.showsFullScreenToggleButton = true
        
        // Enable fullscreen support
        let windowController = NSApp.windows.first?.windowController
        windowController?.shouldCascadeWindows = false
        view.window?.collectionBehavior = [.fullScreenPrimary]

        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

private enum LayoutType {
    case classic
    case custom
    case auto
}

struct PreviewSettingsSheet: View {
    let video: HyperMovieModels.Video
    @Binding var isGenerating: Bool
    @Binding var duration: Double
    @Binding var density: DensityConfig
    let onGenerate: (Double, DensityConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(HyperMovieServices.AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: Theme.Layout.Spacing.lg) {
            Text("Preview Settings")
                .font(Theme.Typography.title2)
                .foregroundStyle(Theme.Colors.Text.primary)
            
            if isGenerating {
                VStack(spacing: Theme.Layout.Spacing.md) {
                    ProgressView(value: appState.previewGenerator.progress) {
                        Text("Generating Preview...")
                    }
                    Text("\(Int(appState.previewGenerator.progress * 100))%")
                        .font(Theme.Typography.caption1)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: Theme.Layout.Spacing.md) {
                    Text("Duration (seconds)")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                    
                    Slider(
                        value: $duration,
                        in: 30...240,
                        step: 10
                    ) {
                        Text("Duration")
                    } minimumValueLabel: {
                        Text("30s")
                    } maximumValueLabel: {
                        Text("240s")
                    }
                    
                    Text("\(Int(duration)) seconds")
                        .font(Theme.Typography.caption1)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                }
                
                VStack(alignment: .leading, spacing: Theme.Layout.Spacing.md) {
                    Text("Density")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                    
                    Picker("Density", selection: $density) {
                        ForEach(DensityConfig.allCases, id: \.self) { config in
                            Text(config.name).tag(config)
                        }
                    }
                    
                    Text("Affects the number and length of extracts")
                        .font(Theme.Typography.caption1)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                }
            }
            
            HStack(spacing: Theme.Layout.Spacing.md) {
                HMButton("Cancel") {
                    if isGenerating {
                        appState.previewGenerator.cancelAll()
                    }
                    dismiss()
                }
                
                if !isGenerating {
                    HMButton("Generate", style: .primary) {
                        onGenerate(duration, density)
                    }
                }
            }
        }
        .padding(Theme.Layout.Spacing.xl)
        .frame(width: 400)
    }
} 
