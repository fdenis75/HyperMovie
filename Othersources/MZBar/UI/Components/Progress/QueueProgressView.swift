import SwiftUI

struct QueueProgressView: View {
    @ObservedObject var viewModel: MosaicViewModel
    @State private var isExpanded = false
    @State private var lastFileId: UUID?
    @Namespace private var bottomID
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with toggle button
            QueueHeader(
                isExpanded: $isExpanded,
                fileCount: viewModel.queuedFiles.count
            )
            
           // if isExpanded {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(viewModel.queuedFiles, id: \.self) { file in
                                FileProgressView(
                                    progress: file,
                                    onCancel: { viewModel.cancelFile(file.id) },
                                    onRetry: { viewModel.retryPreview(for: file.id) }
                                )
                                .id(file.id)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(minHeight: 200, maxHeight: 200)
                    /*.onChange(of: viewModel.queuedFiles) { oldValue, newValue in
                        if !newValue.isEmpty {
                            scrollToBottom(proxy: proxy)
                        }
                    }*/
                }
            //}
        }
        .padding(8)
        .background(Color(.tertiarySystemFill))
        .cornerRadius(8)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if let lastFile = viewModel.queuedFiles.last {
                proxy.scrollTo(lastFile.id, anchor: .bottom)
            }
        }
    }
}

private struct QueueHeader: View {
    @Binding var isExpanded: Bool
    let fileCount: Int
    
    var body: some View {
        HStack {
            Text("Queue Status")
                .font(.system(size: 12, weight: .medium))
            Spacer()
            if fileCount > 0 {
                Text("\(fileCount) files")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            ExpandButton(isExpanded: $isExpanded)
        }
        .padding(.horizontal, 8)
    }
}

private struct ExpandButton: View {
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
} 