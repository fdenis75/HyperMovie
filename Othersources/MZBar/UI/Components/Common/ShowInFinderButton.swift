import SwiftUI

struct ShowInFinderButton: View {
    let playlistURL: URL
    
    var body: some View {
        Button {
            NSWorkspace.shared.selectFile(
                playlistURL.path,
                inFileViewerRootedAtPath: playlistURL.deletingLastPathComponent().path
            )
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                Text("Show in Finder")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .foregroundColor(.blue)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.blue, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }
} 