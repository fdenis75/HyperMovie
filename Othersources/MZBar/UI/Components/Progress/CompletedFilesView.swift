import SwiftUI

struct CompletedFilesView: View {
    @ObservedObject var viewModel: MosaicViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Completed Files")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if !viewModel.completedFiles.isEmpty {
                    Text("\(viewModel.completedFiles.count) files")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            
            /*if isExpanded {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.completedFiles) { file in
                            FileCompletedView(
                                file: file,
                                onCancel: {},
                                onRetry: {}
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(minHeight: 200, maxHeight: 200)
            }*/
        }
        .padding(8)
        .background(Color(.tertiarySystemFill))
        .cornerRadius(8)
    }
} 
