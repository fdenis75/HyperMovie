import SwiftUI
import HyperMovieServices
import HyperMovieModels

struct SettingsView: View {
    @Bindable var appState: HyperMovieServices.AppState
    
    var body: some View {
        TabView {
            MosaicSettingsView(appState: appState)
                .tabItem {
                    Label("Mosaic", systemImage: "photo.on.rectangle")
                }
            
            PreviewSettingsView(appState: appState)
                .tabItem {
                    Label("Preview", systemImage: "eye")
                }
        }
        .frame(width: 500, height: 300)
    }
}

private struct MosaicSettingsView: View {
    @Bindable var appState: HyperMovieServices.AppState
    
    var body: some View {
        Form {
            LayoutSection(appState: appState)
            ExportSection(appState: appState)
        }
        .padding()
    }
}

private struct LayoutSection: View {
    @Bindable var appState: HyperMovieServices.AppState
    
    private let widthOptions = [2000, 4000, 5120, 8000, 10000]
    private let aspectRatios: [(String, CGFloat)] = [
        ("16:9", 16.0/9.0),
        ("1:1", 1.0),
        ("9:16", 9.0/16.0)
    ]
    private let densityLabels = ["XXS", "XS", "S", "M", "L", "XL", "XXL"]
    
    var body: some View {
        Section("Layout") {
            // Auto Layout Toggle
            Toggle("Auto Layout", isOn: $appState.mosaicConfig.layout.useAutoLayout)
            
            // Aspect Ratio
            VStack(alignment: .leading) {
                Label("Aspect Ratio", systemImage: "aspectratio")
                Picker("", selection: $appState.mosaicConfig.layout.aspectRatio) {
                    ForEach(aspectRatios, id: \.0) { label, ratio in
                        Text(label).tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Output Size
            VStack(alignment: .leading) {
                Label("Output Size", systemImage: "ruler")
                Picker("", selection: $appState.mosaicConfig.width) {
                    ForEach(widthOptions, id: \.self) { width in
                        Text("\(width)px").tag(width)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Density
            VStack(alignment: .leading, spacing: 8) {
                Label("Density", systemImage: "chart.bar.fill")
                HStack {
                    ForEach(densityLabels, id: \.self) { label in
                        Button(label) {
                            appState.mosaicConfig.density = densityValue(for: label)
                        }
                        .buttonStyle(.bordered)
                        .tint(appState.mosaicConfig.density == densityValue(for: label) ? .blue : .secondary)
                    }
                }
            }
        }
    }
    
    private func densityValue(for label: String) -> DensityConfig {
        switch label {
        case "XXS": return .xxs
        case "XS": return .xs
        case "S": return .s
        case "M": return .m
        case "L": return .l
        case "XL": return .xl
        case "XXL": return .xxl
        default: return .default
        }
    }
}

private struct ExportSection: View {
    @Bindable var appState: HyperMovieServices.AppState
    
    private var qualityBinding: Binding<Double> {
        .init(
            get: { appState.mosaicConfig.compressionQuality },
            set: { appState.mosaicConfig.compressionQuality = $0 }
        )
    }
    
    var body: some View {
        Section("Export") {
            Slider(value: qualityBinding, in: 0...1) {
                Text("Quality: \(Int(appState.mosaicConfig.compressionQuality * 100))%")
            }
            
            Toggle("Include Metadata", isOn: $appState.mosaicConfig.includeMetadata)
        }
    }
}

private struct PreviewSettingsView: View {
    @Bindable var appState: HyperMovieServices.AppState
    
    private var durationBinding: Binding<Double> {
        .init(
            get: { appState.previewConfig.duration },
            set: { appState.previewConfig.duration = Double($0) }
        )
    }
    
    private var qualityBinding: Binding<Double> {
        .init(
            get: { appState.mosaicConfig.compressionQuality },
            set: { appState.mosaicConfig.compressionQuality = $0 }
        )
    }
    
    var body: some View {
        Form {  
            Section {
              /*  Slider(value: durationBinding, in: 5...120, step: 5) {
                    Text("Duration: \(Int(appState.previewConfig.duration))s")
                }*/
                
                Slider(value: qualityBinding, in: 0...1) {
                    Text("Quality: \(Int(appState.mosaicConfig.compressionQuality * 100))%")
                }
                /*
                Picker("Frame Rate", selection: $appState.previewConfig.frameRate) {
                    Text("24 fps").tag(24)
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }*/
            } header: {
                Text("Video")
            }
        }
        .padding()
    }
}
