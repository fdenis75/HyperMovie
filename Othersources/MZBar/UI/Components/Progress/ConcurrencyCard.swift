import SwiftUI

struct ConcurrencyCard: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        SettingsCard(title: "Concurrency", icon: "dial.high.fill", viewModel: viewModel) {
            Picker("Concurrent Ops", selection: $viewModel.concurrentOps) {
                ForEach(viewModel.concurrent, id: \.self) { concurrent in
                    Text(String(concurrent)).tag(concurrent)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.concurrentOps) {
                viewModel.updateMaxConcurrentTasks()
            }
        }
    }
} 