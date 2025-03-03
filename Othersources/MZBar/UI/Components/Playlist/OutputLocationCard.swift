import SwiftUI

struct OutputLocationCard: View {
    @ObservedObject var viewModel: MosaicViewModel
    @Binding var isShowingFolderPicker: Bool
    
    var body: some View {
        SettingsCard(title: "Output Location", icon: "folder.fill", viewModel: viewModel) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(viewModel.playlistOutputFolder?.path ?? "Default Location")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button {
                        isShowingFolderPicker = true
                    } label: {
                        Text("Change")
                            .foregroundColor(viewModel.currentTheme.colors.primary)
                    }
                    .buttonStyle(.plain)
                }
                
                if viewModel.playlistOutputFolder != nil {
                    Button {
                        viewModel.resetPlaylistOutputFolder()
                    } label: {
                        Text("Reset to Default")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }
} 