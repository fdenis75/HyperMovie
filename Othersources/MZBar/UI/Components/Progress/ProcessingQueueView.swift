import SwiftUI

struct ProcessingQueueView: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            QueueProgressView(viewModel: viewModel)
            CompletedFilesView(viewModel: viewModel)
        }
    }
} 