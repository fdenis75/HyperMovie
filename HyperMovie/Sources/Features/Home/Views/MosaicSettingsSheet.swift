import SwiftUI
import HyperMovieModels
import HyperMovieServices
 

struct MosaicSettingsSheet: View {
    let video: Video
    @Binding var isGenerating: Bool
    let onGenerate: (MosaicConfiguration) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(HyperMovieServices.AppState.self) private var appState
    @State private var config: MosaicConfiguration
    
    init(video: Video, isGenerating: Binding<Bool>, onGenerate: @escaping (MosaicConfiguration) -> Void) {
        self.video = video
        self._isGenerating = isGenerating
        self.onGenerate = onGenerate
        self._config = State(initialValue: MosaicConfiguration.default)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Layout") {
                    // Layout Type Picker
                    VStack(alignment: .leading) {
                        Label("Layout Type", systemImage: "square.grid.3x3")
                        Picker("", selection: Binding(
                            get: {
                                if config.layout.useAutoLayout {
                                    return LayoutType.auto
                                } else if config.layout.useCustomLayout {
                                    return LayoutType.custom
                                } else {
                                    return LayoutType.classic
                                }
                            },
                            set: { newValue in
                                switch newValue {
                                case .classic:
                                    config.layout.useCustomLayout = false
                                    config.layout.useAutoLayout = false
                                case .custom:
                                    config.layout.useCustomLayout = true
                                    config.layout.useAutoLayout = false
                                case .auto:
                                    config.layout.useCustomLayout = false
                                    config.layout.useAutoLayout = true
                                }
                            }
                        )) {
                            Text("Classic").tag(LayoutType.classic)
                            Text("Custom").tag(LayoutType.custom)
                            Text("Auto").tag(LayoutType.auto)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Aspect Ratio
                    Picker("Aspect Ratio", selection: $config.layout.aspectRatio) {
                        Text("16:9").tag(AspectRatio.widescreen)
                        Text("4:3").tag(AspectRatio.standard)
                        Text("1:1").tag(AspectRatio.square)
                        Text("21:9").tag(AspectRatio.ultrawide)
                    }
                    
                    // Output Size
                    Picker("Output Size", selection: $config.width) {
                        Text("2K").tag(2000)
                        Text("4K").tag(4000)
                        Text("5K").tag(5120)
                        Text("8K").tag(8000)
                        Text("10K").tag(10000)
                    }
                    
                    // Density
                    Picker("Density", selection: $config.density) {
                        Text("XXS").tag(DensityConfig.xxs)
                        Text("XS").tag(DensityConfig.xs)
                        Text("S").tag(DensityConfig.s)
                        Text("M").tag(DensityConfig.m)
                        Text("L").tag(DensityConfig.l)
                        Text("XL").tag(DensityConfig.xl)
                        Text("XXL").tag(DensityConfig.xxl)
                    }
                }
                
                Section("Visual") {
                    Toggle("Add Border", isOn: $config.layout.visual.addBorder)
                    Toggle("Add Shadow", isOn: $config.layout.visual.addShadow)
                }
                
                Section("Export") {
                    Slider(value: $config.compressionQuality, in: 0...1) {
                        Text("Quality: \(Int(config.compressionQuality * 100))%")
                    }
                    
                    Toggle("Include Metadata", isOn: $config.includeMetadata)
                    
                    Picker("Format", selection: $config.format) {
                        Text("JPEG").tag(OutputFormat.jpeg)
                        Text("PNG").tag(OutputFormat.png)
                        Text("HEIF").tag(OutputFormat.heif)
                    }
                }
            }
            .navigationTitle("Mosaic Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Generate") {
                        onGenerate(config)
                        dismiss()
                    }
                    .disabled(isGenerating)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

private enum LayoutType {
    case classic
    case custom
    case auto
} 