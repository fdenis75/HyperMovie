import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                List(selection: $viewModel.selectedMode) {
                    ForEach([
                        (TabSelection.mosaic, "square.grid.3x3.fill", "Mosaic"),
                        (TabSelection.preview, "play.square.fill", "Preview"),
                        (TabSelection.playlist, "music.note.list", "Playlist")
                    ], id: \.0) { tab, icon, title in
                        TabItemView(tab: tab, icon: icon, title: title, viewModel: viewModel)
                    }
                }
                
                Spacer()
                MosaicNavigatorButton(viewModel: viewModel)
                
                Spacer()
                SettingsButton()
            }.frame(minWidth: 80, maxWidth: 80, alignment: .center)
                .padding(.horizontal, 16)
                .opacity(1)
        }
    }
} 