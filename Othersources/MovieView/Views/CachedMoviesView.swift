import SwiftUI

struct CachedMoviesView: View {
    @StateObject private var manager = CachedMoviesManager()
    @StateObject private var videoProcessor = VideoProcessor()
    @State private var searchText = ""
    
    var body: some View {
        FolderView(
            folderProcessor: manager,
            videoProcessor: videoProcessor,
            searchText: $searchText,
            onMovieSelected: { url in
                Task { try await videoProcessor.processVideo(url: url) }
            }
        )
        .task {
            await manager.loadCachedMovies()
        }
    }
}

#Preview {
    CachedMoviesView()
} 