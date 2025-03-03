import SwiftUI
import HyperMovieCore
import HyperMovieModels
import HyperMovieServices
 //import DesignSystem
//  

struct ContentView: View {
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedLibraryItem: HyperMovieModels.LibraryItem?
    @State private var selectedVideo: HyperMovieModels.Video?
    @Environment(HyperMovieServices.AppState.self) private var appState
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LibrarySidebar(selection: $selectedLibraryItem)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } content: {
            VideoList(selectedVideo: $selectedVideo,
                      selectedFolder: selectedLibraryItem)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            VideoDetail(video: selectedVideo)
        }
        .navigationSplitViewStyle(.balanced)
        .background(Theme.Colors.Background.primary)
        .preferredColorScheme(.dark)
    }
} 