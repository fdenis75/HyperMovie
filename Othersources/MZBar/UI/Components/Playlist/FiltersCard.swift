import SwiftUI

struct FiltersCard: View {
    @ObservedObject var viewModel: MosaicViewModel
    @State private var minDuration: Double = 0
    @State private var maxDuration: Double = 3600
    
    var body: some View {
        SettingsCard(title: "Filters", icon: "line.3.horizontal.decrease.circle.fill", viewModel: viewModel) {
            VStack(spacing: 16) {
                DurationRangeFilter(minDuration: $minDuration, maxDuration: $maxDuration)
                
                if viewModel.selectedPlaylistType == 1 {
                    DurationBasedOptions(viewModel: viewModel)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct DurationRangeFilter: View {
    @Binding var minDuration: Double
    @Binding var maxDuration: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration Range")
                .font(.subheadline)
            
            HStack {
                VStack {
                    Text("Min")
                        .font(.caption)
                    Text(formatDuration(minDuration))
                }
                
                Slider(value: $minDuration, in: 0...3600)
                
                VStack {
                    Text("Max")
                        .font(.caption)
                    Text(formatDuration(maxDuration))
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)m"
    }
}

private struct DurationBasedOptions: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration Based Options")
                .font(.subheadline)
            
            Toggle("Include Partial Videos", isOn: $viewModel.includePartialVideos)
            Toggle("Prioritize Longer Videos", isOn: $viewModel.prioritizeLongerVideos)
        }
    }
} 