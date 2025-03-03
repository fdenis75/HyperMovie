import SwiftUI

enum MovieSortOption {
    case name
    case date
    case size
    
    var title: String {
        switch self {
        case .name: return "Name"
        case .date: return "Date"
        case .size: return "Size"
        }
    }
}

struct MovieCardView: View {
    let movie: MovieFile
    let onSelect: (URL) -> Void
    let size: Double
    @State private var isHovered = false
    @State private var isSelected = false
    @Binding var selectedMoviesForMosaic: Set<MovieFile>
    @Binding var selectedMoviesForPreview: Set<MovieFile>
    
    private var aspectRatio: CGFloat { movie.aspectRatio }
    
    private var movieThumbnail: some View {
        Image(nsImage: movie.thumbnail ?? NSImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size / aspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var placeholderThumbnail: some View {
        Rectangle()
            .fill(.secondary.opacity(0.2))
            .frame(width: 320, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                ProgressView()
            }
    }
    
    private var thumbnailView: some View {
        Group {
            if movie.thumbnail != nil {
                movieThumbnail
            } else {
                placeholderThumbnail
            }
        }
    }
    
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(movie.name)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
            
            if !movie.relativePath.isEmpty {
                Text(movie.relativePath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            dateAndSizeView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
    
    private var dateAndSizeView: some View {
        HStack(spacing: 8) {
            if let date = try? movie.url.resourceValues(forKeys: Set([.contentModificationDateKey]))
                .contentModificationDate
            {
                Text(date, style: .date)
            }
            if let size = try? movie.url.resourceValues(forKeys: Set([.fileSizeKey])).fileSize {
                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            thumbnailView
            infoView
        }
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.mint : Color.gray.opacity(0.3), lineWidth: isHovered ? 2 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedMoviesForMosaic.contains(movie) ? Color.blue : 
                       selectedMoviesForPreview.contains(movie) ? Color.orange :
                       Color.gray.opacity(0.3), 
                       lineWidth: (selectedMoviesForMosaic.contains(movie) || selectedMoviesForPreview.contains(movie)) ? 2 : 1)
        )
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(radius: 2)
        }
        .onTapGesture(count: 1) {
            if NSEvent.modifierFlags.contains(.command) {
                if NSEvent.modifierFlags.contains(.option) {
                    // Option+Command for preview selection
                    if selectedMoviesForPreview.contains(movie) {
                        selectedMoviesForPreview.remove(movie)
                    } else {
                        selectedMoviesForPreview.insert(movie)
                    }
                } else {
                    // Command for mosaic selection
                    if selectedMoviesForMosaic.contains(movie) {
                        selectedMoviesForMosaic.remove(movie)
                    } else {
                        selectedMoviesForMosaic.insert(movie)
                    }
                }
            } else {
                onSelect(movie.url)
            }
        }
    }
}

struct FolderView<Processor: FolderProcessorProtocol>: View where Processor.MovieType: MovieFileProtocol {
    
    @ObservedObject var folderProcessor: Processor
    @ObservedObject var videoProcessor: VideoProcessor
    @Binding var searchText: String
    @StateObject private var mosaicCoordinator = MosaicGenerationCoordinator(videoProcessor: VideoProcessor())
    let onMovieSelected: (URL) -> Void
    let smartFolderName: String?
    @State private var sortOption: MovieSortOption = .name
    @State private var sortAscending = true
    @State private var selectedFolder: String?
    @State private var thumbnailSize: Double = 160
    @State private var selectedMovie: MovieFile?
    @State private var hoveredMovie: MovieFile?
    @FocusState private var isFocused: Bool
    
    // Mosaic generation states
    @State private var isShowingMosaicConfig = false
    @State private var mosaicConfig = MosaicConfig()
    @State private var selectedMoviesForMosaic = Set<MovieFile>()
    @State private var isMosaicGenerating = false
    @State private var showingMosaicQueue = false
    
    // Preview generation states
    @State private var isShowingPreviewGenerator = false
    @State private var selectedMovieForPreview: MovieFile?
    @State private var selectedMoviesForPreview = Set<MovieFile>()
    
    // Add preview coordinator
    @StateObject private var previewCoordinator = PreviewGenerationCoordinator(videoProcessor: VideoProcessor())
    
    // Add preview queue state
    @State private var showingPreviewQueue = false
    
    init(folderProcessor: Processor, videoProcessor: VideoProcessor, searchText: Binding<String> = .constant(""), onMovieSelected: @escaping (URL) -> Void, smartFolderName: String? = nil) {
        self.folderProcessor = folderProcessor
        self.videoProcessor = videoProcessor
        self._searchText = searchText
        self.onMovieSelected = onMovieSelected
        self.smartFolderName = smartFolderName
    }
    
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize * 2), spacing: 16)]
    }
    
    private var folders: [String] {
        let paths = folderProcessor.movies.compactMap { movie in
            let components = movie.relativePath.split(separator: "/")
            return components.first.map(String.init)
        }
        return Array(Set(paths)).sorted()
    }
    
    private var filteredMovies: [Processor.MovieType] {
        let baseMovies = folderProcessor.movies
        
        var filtered = baseMovies.filter {
            searchText.isEmpty ? true :
            $0.url.lastPathComponent.localizedCaseInsensitiveContains(searchText) ||
            $0.url.path.localizedCaseInsensitiveContains(searchText)
        }
        
        if let selectedFolder = selectedFolder {
            filtered = filtered.filter { movie in
                let components = movie.relativePath.split(separator: "/")
                return components.first.map(String.init) == selectedFolder
            }
        }
        
        return filtered
    }
    
    private var sortedMovies: [Processor.MovieType] {
        let sorted = filteredMovies.sorted { (first: Processor.MovieType, second: Processor.MovieType) in
            switch sortOption {
            case .name:
                return sortAscending
                ? first.name.localizedStandardCompare(second.name) == .orderedAscending
                : first.name.localizedStandardCompare(second.name) == .orderedDescending
            case .date:
                let firstDate =
                (try? first.url.resourceValues(forKeys: Set([.contentModificationDateKey])))?
                    .contentModificationDate ?? Date.distantPast
                let secondDate =
                (try? second.url.resourceValues(forKeys: Set([.contentModificationDateKey])))?
                    .contentModificationDate ?? Date.distantPast
                return sortAscending ? firstDate < secondDate : firstDate > secondDate
            case .size:
                let firstSize = (try? first.url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize ?? 0
                let secondSize = (try? second.url.resourceValues(forKeys: Set([.fileSizeKey])))?.fileSize ?? 0
                return sortAscending ? firstSize < secondSize : firstSize > secondSize
            }
        }
        return sorted
    }
    
    private func convertToSet(_ movies: [Processor.MovieType]) -> Set<MovieFile> {
        Set(movies.compactMap { $0 as? MovieFile })
    }
    
    @ViewBuilder
    private var slideView: some View {
        HStack {
            Image(systemName: "photo")
            Slider(
                value: $thumbnailSize,
                in: 160...320,
                step: 40
            )
            Image(systemName: "photo.fill")
        }
    }
    
    
    @ViewBuilder
    private var menuView: some View {
       
            Menu {
                Button("All Folders") {
                    selectedFolder = nil
                }
                Divider()
                ForEach(folders, id: \.self) { folder in
                    Button(folder) {
                        selectedFolder = folder
                    }
                }
            } label: {
                Label(selectedFolder ?? "All Folders", systemImage: "folder")
                    .frame(width: 150, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Picker("Sort by", selection: $sortOption) {
                ForEach([MovieSortOption.name, .date, .size], id: \.title) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Button(action: {
                withAnimation {
                    sortAscending.toggle()
                }
            }) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
            }
            .buttonStyle(.borderless)
            
            Spacer()
           
                Button(action: playAllInIINA) {
                    Label("Play All", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            if folderProcessor.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 4)
                Text("Scanning... found \(folderProcessor.movies.count) movies")
                    .foregroundStyle(.secondary)
            } else {
                Text("Found \(folderProcessor.movies.count) movies")
                    .foregroundStyle(.secondary)
            }
        }
    
    private func playAllInIINA() {
        do {
            let urls = sortedMovies.map(\.url)
            let tempDir = FileManager.default.temporaryDirectory
            let playlistURL = try PlaylistGenerator.createM3U8(from: urls, at: tempDir)
            let iinaURL = URL(string: "iina://open?url=\(playlistURL.absoluteString)")!
            NSWorkspace.shared.open(iinaURL)
        } catch {
            // Handle error appropriately
            print("Error creating playlist: \(error)")
        }
    }
    
    private var mosaicButtons: some View {
        HStack {
            Spacer()
            Button {
                selectedMoviesForMosaic = convertToSet(sortedMovies)
            } label: {
                Label("Select All", systemImage: "checkmark.circle")
            }
            .help("Select all videos for mosaic generation")
            
            Button {
                isShowingMosaicConfig = true
            } label: {
                Label("Generate Mosaic", systemImage: "square.grid.3x3")
            }
            .disabled(selectedMoviesForMosaic.isEmpty)
            .help("Generate mosaic from selected videos")
        }
        .padding()
    }
    
    private var previewButtons: some View {
        HStack {
            Spacer()
            Button {
                selectedMoviesForPreview = convertToSet(sortedMovies)
            } label: {
                Label("Select All", systemImage: "checkmark.circle")
            }
            .help("Select all videos for preview generation")
            
            Button {
                isShowingPreviewGenerator = true
            } label: {
                Label("Generate Preview", systemImage: "film.stack")
            }
            .disabled(selectedMoviesForPreview.isEmpty)
            .help("Generate preview from selected video")
        }
        .padding()
    }
    
    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                keyboardNavigation
            }
        }
    }
    private var gridContent: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(sortedMovies) { movie in
                MovieCardView(
                    movie: movie as! MovieFile,
                    onSelect: onMovieSelected,
                    size: thumbnailSize,
                    selectedMoviesForMosaic: $selectedMoviesForMosaic,
                    selectedMoviesForPreview: $selectedMoviesForPreview
                )
                .id(movie)
                .onHover { isHovered in
                    hoveredMovie = isHovered ? (movie as? MovieFile) : nil
                }
                .background(selectedMovie == (movie as? MovieFile) ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .onTapGesture(count: 1) { _ in 
                    selectedMovie = movie as? MovieFile
                    onMovieSelected(movie.url)
                }
                .contextMenu {
                    Button(action: { selectedMovie = movie as? MovieFile }) {
                        Label("Select", systemImage: "checkmark.circle")
                    }
                    Button(action: { 
                        if let movieFile = movie as? MovieFile {
                            selectedMovieForPreview = movieFile
                            isShowingPreviewGenerator = true
                        }
                    }) {
                        Label("Generate Preview", systemImage: "film.stack")
                    }
                    Button(action: { NSWorkspace.shared.selectFile(movie.url.path, inFileViewerRootedAtPath: movie.url.deletingLastPathComponent().path) }) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(movie.url.path, forType: .string) }) {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .padding()
    }
    // Keyboard navigation
    private var keyboardNavigation: some View {
        gridContent
            .onKeyPress(.leftArrow) {
                handleArrowKey(direction: .left)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                handleArrowKey(direction: .right)
                return .handled
            }
            .onKeyPress(.upArrow) {
                handleArrowKey(direction: .up)
                return .handled
            }
            .onKeyPress(.downArrow) {
                handleArrowKey(direction: .down)
                return .handled
            }
    }
    
    private enum NavigationDirection {
        case left, right, up, down
    }
    
    private func handleArrowKey(direction: NavigationDirection) {
        guard let current = selectedMovie as? Processor.MovieType,
              let index = sortedMovies.firstIndex(of: current) else {
            handleNoSelection()
            return
        }
        
        let newIndex = calculateNewIndex(currentIndex: index, direction: direction)
        if newIndex != index {
            updateSelection(at: newIndex)
        }
    }
    
    private func handleNoSelection() {
        if !sortedMovies.isEmpty {
            let firstMovie = sortedMovies[0]
            selectedMovie = firstMovie as? MovieFile
            onMovieSelected(firstMovie.url)
        }
    }
    
    private func calculateNewIndex(currentIndex: Int, direction: NavigationDirection) -> Int {
        switch direction {
        case .left:  return max(0, currentIndex - 1)
        case .right: return min(sortedMovies.count - 1, currentIndex + 1)
        case .up:    return max(0, currentIndex - getColumnsCount())
        case .down:  return min(sortedMovies.count - 1, currentIndex + getColumnsCount())
        }
    }
    
    private func getColumnsCount() -> Int {
        max(1, Int(NSScreen.main?.frame.width ?? 1600) / Int(thumbnailSize))
    }
    
    private func updateSelection(at index: Int) {
        let nextMovie = sortedMovies[index]
        selectedMovie = nextMovie as? MovieFile
        onMovieSelected(nextMovie.url)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            slideView.padding(.horizontal)
            
            HStack {
                menuView
                Spacer()
                Button {
                    isShowingMosaicConfig = true
                } label: {
                    Label("Generate Mosaics for current view", systemImage: "square.grid.3x3.fill")
                }
                .help("Generate mosaics for all videos in this view")
            }
            .padding()
            
            mosaicButtons
            previewButtons
            mainContent
        }
        .sheet(isPresented: $isShowingPreviewGenerator) {
            VideoPreviewGeneratorView(videoURLs: selectedMoviesForPreview.map(\.url))
        }
        .sheet(isPresented: $isShowingMosaicConfig) {
            MosaicConfigSheet(config: $mosaicConfig) {
                handleMosaicGeneration(config: mosaicConfig)
            }
        }
        .overlay {
            if folderProcessor.movies.isEmpty && !folderProcessor.isProcessing {
                Text("No movies found")
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingMosaicQueue.toggle()
                } label: {
                    Label("Show Mosaic Queue", systemImage: "photo.stack")
                }
                .help("Show mosaic generation queue")
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showingPreviewQueue.toggle()
                } label: {
                    Label("Show Preview Queue", systemImage: "film.stack.fill")
                }
                .help("Show preview generation queue")
            }
        }
        .sheet(isPresented: $showingMosaicQueue) {
            MosaicQueueView(coordinator: mosaicCoordinator)
        }
        .sheet(isPresented: $showingPreviewQueue) {
            PreviewQueueView(coordinator: previewCoordinator)
        }
    }
    
    private func handleMosaicGeneration(config: MosaicConfig) {
        Task {
            let moviesToProcess = smartFolderName != nil && selectedMoviesForMosaic.isEmpty ? 
                (sortedMovies as! [MovieFile]) : Array(selectedMoviesForMosaic)
            
            for movie in moviesToProcess {
                let task = MosaicGenerationTask(
                    id: UUID(),
                    url: movie.url,
                    config: config,
                    smartFolderName: folderProcessor.smartFolderName
                )
                mosaicCoordinator.addTask(task)
            }
        }
    }
}
