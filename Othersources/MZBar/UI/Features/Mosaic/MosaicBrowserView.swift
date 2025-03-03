import SwiftUI

struct MosaicBrowserView: View {
    @ObservedObject var viewModel: MosaicViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFileId: ResultFiles.ID?
    
    var body: some View {
        NavigationSplitView {
            List(viewModel.doneFiles, id: \.id, selection: $selectedFileId) { file in
                VStack(alignment: .leading) {
                    Text(file.video.lastPathComponent)
                        .font(.headline)
                    Text(file.video.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Source Files")
        } detail: {
            MosaicBrowserDetailView(file: selectedFile)
        }
        .onDisappear {
            selectedFileId = nil
        }
    }
    
    var selectedFile: ResultFiles? {
        viewModel.doneFiles.first { $0.id == selectedFileId }
    }
} 