import SwiftUI
import AVKit
import HyperMovieCore
import HyperMovieModels
import HyperMovieServices
 

struct VideoList: View {
    @Environment(HyperMovieServices.AppState.self) private var appState
    @Binding var selectedVideo: HyperMovieModels.Video?
    let selectedFolder: HyperMovieModels.LibraryItem?
    @State private var includeSubfolders = false
    @State private var selectedVideos: Set<HyperMovieModels.Video> = []
    
    @State private var searchText = ""
    @State private var sortOrder = SortOrder.name
    
    private var filteredVideos: [HyperMovieModels.Video] {
        guard let folder = selectedFolder,
              let folderURL = folder.url else {
            return []
        }
        
        // First filter by folder
        let folderVideos = appState.videos.filter { video in
            let videoPath = video.url.path
            if includeSubfolders {
                return videoPath.hasPrefix(folderURL.path)
            } else {
                return video.url.deletingLastPathComponent() == folderURL
            }
        }
        
        // Then apply search filter
        let searchFiltered = searchText.isEmpty ? folderVideos : folderVideos.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
        
        // Finally apply sorting
        return searchFiltered.sorted { first, second in
            switch sortOrder {
            case .name:
                return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            case .date:
                return first.dateAdded > second.dateAdded
            case .size:
                return (first.fileSize ?? 0) > (second.fileSize ?? 0)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: Theme.Layout.Spacing.md) {
            if let folder = selectedFolder, folder.type == .folder {
                HStack {
                    Toggle("Include subfolders", isOn: $includeSubfolders)
                        .toggleStyle(.switch)
                    Spacer()
                    
                    // IINA Playlist Buttons
                    HStack(spacing: Theme.Layout.Spacing.sm) {
                        if !selectedVideos.isEmpty {
                            HMButton(
                                "Open Selected in IINA",
                                icon: "play.circle",
                                style: .secondary,
                                size: .small
                            ) {
                                openInIINA(videos: Array(selectedVideos))
                            }
                        }
                        
                        HMButton(
                            "Open All in IINA",
                            icon: "play.circle.fill",
                            style: .secondary,
                            size: .small
                        ) {
                            openInIINA(videos: filteredVideos)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Search and Sort Controls
            HStack(spacing: Theme.Layout.Spacing.sm) {
                HStack(spacing: Theme.Layout.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: Theme.Layout.IconSize.sm))
                        .foregroundStyle(Theme.Colors.Text.secondary)
                    
                    TextField("Search", text: $searchText)
                        .font(Theme.Typography.body)
                        .textFieldStyle(.plain)
                }
                .padding(Theme.Layout.Spacing.xs)
                .background(Theme.Colors.Background.elevated)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md))
                
                Menu {
                    Picker("Sort", selection: $sortOrder) {
                        Label("Name", systemImage: "textformat").tag(SortOrder.name)
                        Label("Date", systemImage: "calendar").tag(SortOrder.date)
                        Label("Size", systemImage: "arrow.up.arrow.down").tag(SortOrder.size)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: Theme.Layout.IconSize.md))
                        .foregroundStyle(Theme.Colors.Text.primary)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, Theme.Layout.Spacing.md)
            
            // Video Grid
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: Theme.Layout.Spacing.md)],
                    spacing: Theme.Layout.Spacing.md
                ) {
                    ForEach(filteredVideos) { video in
                        HMGridItem(
                            title: video.title,
                            subtitle: formatFileSize(video.fileSize),
                            isSelected: selectedVideos.contains(video),
                            action: { handleVideoSelection(video) },
                            content: {
                                ZStack {
                                    Group {
                                        if let thumbnailURL = video.thumbnailURL,
                                           FileManager.default.fileExists(atPath: thumbnailURL.path) {
                                            AsyncImage(url: thumbnailURL) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 160, height: 90)
                                                    .background(Theme.Colors.Background.secondary)
                                            } placeholder: {
                                                thumbnailPlaceholder
                                            }
                                        } else {
                                            thumbnailPlaceholder
                                        }
                                    }
                                    .frame(width: 160, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md))
                                    
                                    // Selection Checkbox
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: selectedVideos.contains(video) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedVideos.contains(video) ? Theme.Colors.accent : .white)
                                                .font(.system(size: Theme.Layout.IconSize.md))
                                                .shadow(radius: 2)
                                                .padding(Theme.Layout.Spacing.xs)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(Theme.Layout.Spacing.md)
            }
        }
        .navigationTitle(selectedFolder?.name ?? "All Videos")
    }
    
    private func handleVideoSelection(_ video: HyperMovieModels.Video) {
        if NSEvent.modifierFlags.contains(.command) {
            // Command+Click: Add/Remove from selection
            if selectedVideos.contains(video) {
                selectedVideos.remove(video)
            } else {
                selectedVideos.insert(video)
            }
        } else {
            // Normal Click: Single selection and preview
            selectedVideo = video
            selectedVideos = [video]
        }
    }
    
    private func openInIINA(videos: [HyperMovieModels.Video]) {
        guard !videos.isEmpty else { return }
        
        // Create a temporary playlist file
        let playlistContent = videos.map { $0.url.path }.joined(separator: "\n")
        let tempDir = FileManager.default.temporaryDirectory
        let playlistURL = tempDir.appendingPathComponent("hypermovie_playlist.txt")
        
        do {
            try playlistContent.write(to: playlistURL, atomically: true, encoding: .utf8)
            
            // Open with IINA
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "IINA", "--args", "--playlist", playlistURL.path]
            try process.run()
        } catch {
            print("Error opening in IINA: \(error.localizedDescription)")
        }
    }
    
    @ViewBuilder
    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Theme.Colors.Background.secondary)
            .frame(width: 160, height: 90)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: Theme.Layout.IconSize.xl))
                    .foregroundStyle(Theme.Colors.Text.secondary)
            }
    }
    
    private func formatFileSize(_ size: Int64?) -> String {
        guard let size = size else { return "Unknown size" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct VideoRow: View {
    let video: Video
    
    var body: some View {
        HStack {
            if let thumbnailURL = video.thumbnailURL,
               let image = NSImage(contentsOf: thumbnailURL) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 40)
                    .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 60, height: 40)
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading) {
                Text(video.title)
                    .lineLimit(1)
                Text(video.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private enum SortOrder {
    case name
    case date
    case size
} 