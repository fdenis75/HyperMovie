import SwiftUI

struct DetailView: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        ZStack {
            mainContent
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 10)
                        .opacity(0.01)
                )
                .opacity(1)
                .padding()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.selectedMode {
        case .mosaic:
            VStack {
                EnhancedMosaicSettings(viewModel: viewModel)
                    .opacity(viewModel.isProcessing ? 0.05 : 1)
            }
        case .preview:
            EnhancedPreviewSettings(viewModel: viewModel)
                .opacity(viewModel.isProcessing ? 0.05 : 1)
        case .playlist:
            EnhancedPlaylistSettings(viewModel: viewModel)
                .opacity(viewModel.isProcessing ? 0.05 : 1)
        case .settings:
            Text("Settings")
        case .navigator:
            Text("Navigator")
        }
        
        if viewModel.isProcessing || viewModel.displayProgress {
            EnhancedProgressView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .padding()
                .frame(minHeight: 500, maxHeight: 800, alignment: .top)
        }
    }
} 