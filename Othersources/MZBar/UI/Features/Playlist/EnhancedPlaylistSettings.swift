import SwiftUI

struct EnhancedPlaylistSettings: View {
    @ObservedObject var viewModel: MosaicViewModel
    @State private var selectedPlaylistType = 0
    @State private var lastGeneratedPlaylistURL: URL? = nil
    @State private var isShowingFolderPicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                EnhancedDropZone(viewModel: viewModel, inputPaths: $viewModel.inputPaths, inputType: $viewModel.inputType)
                
                PlaylistTypeCard(viewModel: viewModel)
                CalendarOptionsCard(viewModel: viewModel)
                FiltersCard(viewModel: viewModel)
                OutputLocationCard(viewModel: viewModel, isShowingFolderPicker: $isShowingFolderPicker)
                
                EnhancedActionButtons(viewModel: viewModel, mode: viewModel.selectedMode)
                
                if let playlistURL = lastGeneratedPlaylistURL {
                    ShowInFinderButton(playlistURL: playlistURL)
                }
            }
            .padding(12)
        }
        .onChange(of: viewModel.lastGeneratedPlaylistURL) { oldValue, newValue in
            withAnimation {
                lastGeneratedPlaylistURL = newValue
            }
        }
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let selectedURL = urls.first {
                viewModel.setPlaylistOutputFolder(selectedURL)
            }
        case .failure(let error):
            print("Folder selection failed: \(error.localizedDescription)")
        }
    }
} 