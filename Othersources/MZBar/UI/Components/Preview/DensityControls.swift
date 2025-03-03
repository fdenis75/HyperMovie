import SwiftUI

struct DensityControls: View {
    @ObservedObject var viewModel: MosaicViewModel
    @Binding var isEditing2: Bool
    
    let densityLabels = ["XXS", "XS", "S", "M", "L", "XL", "XXL"]
    
    var body: some View {
        VStack(spacing: 8) {
            Slider(
                value: $viewModel.previewDensity,
                in: 1...7,
                step: 1
            ) {
                Text("Density")
            } minimumValueLabel: {
                Text("Low")
                    .foregroundStyle(viewModel.currentTheme.colors.primary)
            } maximumValueLabel: {
                Text("High")
                    .foregroundStyle(viewModel.currentTheme.colors.primary)
            } onEditingChanged: { editing in
                isEditing2 = editing
            }
            .tint(viewModel.currentTheme.colors.primary)
            
            HStack(spacing: 8) {
                ForEach(densityLabels, id: \.self) { label in
                    Button {
                        withAnimation {
                            viewModel.previewDensity = Double(densityValue(for: label))
                        }
                    } label: {
                        Text(label)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.previewDensity == Double(densityValue(for: label)) ? 
                          viewModel.currentTheme.colors.primary : .secondary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func densityValue(for label: String) -> Int {
        switch label {
        case "XXS": return 1
        case "XS": return 2
        case "S": return 3
        case "M": return 4
        case "L": return 5
        case "XL": return 6
        case "XXL": return 7
        default: return 4
        }
    }
} 