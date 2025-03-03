import SwiftUI

struct EnhancedProgressView: View {
    @ObservedObject var viewModel: MosaicViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ConcurrencyCard(viewModel: viewModel)
                
                if viewModel.isProcessing {
                    CancelButton {
                        withAnimation {
                            viewModel.cancelGeneration()
                        }
                    }
                } else {
                    CloseButton {
                        withAnimation {
                            viewModel.displayProgress = false
                        }
                    }
                }
                
                OverallProgressGrid(
                    title: "Overall Progress",
                    progress: viewModel.progressG,
                    icon: "chart.bar.fill",
                    color: viewModel.currentTheme.colors.primary,
                    fileCount: viewModel.inputPaths.count
                )
                
                if !viewModel.isProcessing && !viewModel.completedFiles.isEmpty {
                    BrowseMosaicsButton(viewModel: viewModel)
                }
                
                StatusMessagesView(messages: [
                    .init(icon: "doc.text", text: viewModel.statusMessage1, type: .info),
                    .init(icon: "chart.bar.fill", text: viewModel.statusMessage2, type: .info),
                    .init(icon: "clock", text: viewModel.statusMessage3, type: .info),
                    .init(icon: "timer", text: viewModel.statusMessage4, type: .info)
                ])
                
                ProcessingQueueView(viewModel: viewModel)
            }
        }
    }
} 
