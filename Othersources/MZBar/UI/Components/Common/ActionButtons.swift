import SwiftUI

struct EnhancedActionButtons: View {
    @ObservedObject var viewModel: MosaicViewModel
    let mode: TabSelection
    
    var body: some View {
        HStack(spacing: 16) {
            if viewModel.isProcessing {
                CancelButton(action: {
                    withAnimation {
                        viewModel.cancelGeneration()
                    }
                })
            } else {
                actionButtonsForMode
            }
        }
    }
    
    @ViewBuilder
    private var actionButtonsForMode: some View {
        Group {
            switch mode {
            case .mosaic:
                mosaicButtons
            case .preview:
                previewButtons
            case .playlist:
                playlistButtons
            case .settings:
                settingsButtons
            case .navigator:
                navigatorButtons
            }
        }
        .disabled(mode != .settings && viewModel.inputPaths.isEmpty)
    }
    
    private var mosaicButtons: some View {
        Group {
            PrimaryActionButton(title: "Generate Mosaic", icon: "square.grid.3x3.fill") {
                viewModel.processMosaics()
            }
            SecondaryActionButton(title: "Generate Today", icon: "calendar") {
                viewModel.generateMosaictoday()
            }
        }
    }
    
    private var previewButtons: some View {
        PrimaryActionButton(title: "Generate Previews", icon: "play.circle.fill") {
            viewModel.processPreviews()
        }
    }
    
    private var playlistButtons: some View {
        Group {
            PrimaryActionButton(title: "Generate Playlist", icon: "music.note.list") {
                if let path = viewModel.inputPaths.first?.0 {
                    viewModel.generatePlaylist(path)
                }
            }
            SecondaryActionButton(title: "Generate Playlist Today", icon: "music.note.list") {
                viewModel.generatePlaylisttoday()
            }
            SecondaryActionButton(title: "Generate Date Range Playlist", icon: "calendar.badge.clock") {
                viewModel.generateDateRangePlaylist()
            }
        }
    }
    
    private var settingsButtons: some View {
        PrimaryActionButton(title: "Save Settings", icon: "checkmark.circle.fill") {
            viewModel.updateConfig()
        }
    }
    
    private var navigatorButtons: some View {
        PrimaryActionButton(title: "Generate Mosaic", icon: "square.grid.3x3.fill") {
            viewModel.processMosaics()
        }
    }
}

 struct PrimaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ActionButtonStyle(style: .primary))
    }
}

 struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .buttonStyle(ActionButtonStyle(style: .secondary))
    }
}

 struct CancelButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(role: .destructive, action: action) {
            Label("Cancel", systemImage: "stop.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ActionButtonStyle(style: .destructive))
    }
}

struct ActionButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary, destructive
        
        var background: Material {
            switch self {
            case .primary: return .thick
            case .secondary, .destructive: return .regular
            }
        }
        
        var foreground: Color {
            switch self {
            case .primary: return .teal
            case .secondary: return .primary
            case .destructive: return .red
            }
        }
    }
    
    let style: Style
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(style.background)
            .foregroundStyle(style.foreground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
} 
