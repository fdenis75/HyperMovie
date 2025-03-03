import SwiftUI

struct DurationPresets: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    let presets = [30, 60, 120, 180]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.self) { duration in
                Button("\(duration)s") {
                    withAnimation {
                        viewModel.previewDuration = Double(duration)
                    }
                }
                .buttonStyle(.bordered)
                .tint(viewModel.previewDuration == Double(duration) ? .blue : .secondary)
            }
            .padding(.horizontal)
        }
    }
} 