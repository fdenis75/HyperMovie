import SwiftUI
import AVFoundation

struct EnhancedPreviewSettings: View {
    @ObservedObject var viewModel: MosaicViewModel
    @State private var isEditing = false
    @State private var isEditing2 = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                EnhancedDropZone(viewModel: viewModel, inputPaths: $viewModel.inputPaths, inputType: $viewModel.inputType)
                
                SettingsCard(title: "Preview Setting", icon: "clock.fill", viewModel: viewModel) {
                    VStack(alignment: .center, spacing: 8) {
                        PreviewDurationSection(viewModel: viewModel, isEditing: $isEditing)
                        Divider()
                        PreviewDensitySection(viewModel: viewModel, isEditing2: $isEditing2)
                    }
                }
                
                SettingsCard(title: "Quality", icon: "dial.high.fill", viewModel: viewModel) {
                    CodecPicker(viewModel: viewModel)
                }
                
                EnhancedActionButtons(viewModel: viewModel, mode: viewModel.selectedMode)
            }
            .padding(12)
        }
    }
}

private struct PreviewDurationSection: View {
    @ObservedObject var viewModel: MosaicViewModel
    @Binding var isEditing: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Label("Preview Duration", systemImage: "ruler")
                .foregroundStyle(viewModel.currentTheme.colors.primary)
            
            Slider(
                value: $viewModel.previewDuration,
                in: 0...300,
                step: 5
            ) {
                Text("Duration")
            } minimumValueLabel: {
                Text("0s").foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("300s").foregroundStyle(.secondary)
            } onEditingChanged: { editing in
                isEditing = editing
            }
            
            Text("\(Int(viewModel.previewDuration))s")
            
            DurationPresets(viewModel: viewModel)
        }
    }
}

private struct PreviewDensitySection: View {
    @ObservedObject var viewModel: MosaicViewModel
    @Binding var isEditing2: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Label("Density", systemImage: "ruler")
                .foregroundStyle(viewModel.currentTheme.colors.primary)
            
            DensityVisualizer(viewModel: viewModel)
            DensityControls(viewModel: viewModel, isEditing2: $isEditing2)
        }
    }
}

private struct CodecPicker: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        Picker("OutputFormat", selection: $viewModel.codec) {
            ForEach(AVAssetExportSession.allExportPresets(), id: \.self) { codec in
                Text(String(codec)).tag(codec)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: viewModel.codec) {
            viewModel.updateCodec()
        }
    }
} 