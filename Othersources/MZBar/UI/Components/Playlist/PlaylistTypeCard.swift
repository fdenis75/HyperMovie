import SwiftUI

struct PlaylistTypeCard: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        SettingsCard(title: "Playlist Type", icon: "music.note.list", viewModel: viewModel) {
            Picker("Type", selection: $viewModel.selectedPlaylistType) {
                Text("Standard").tag(0)
                Text("Duration Based").tag(1)
            }
            .pickerStyle(.segmented)
        }
    }
} 