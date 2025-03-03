import SwiftUI
import AVKit

struct MovieInfoCard: View {
    let movie: MovieFile
    let onOpenIINA: () -> Void
    let expectedThumbnailCount: Int
    @State private var isShowingPreviewGenerator = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack {
                Text(movie.name)
                    .font(.headline)
                Spacer()
                
                Button(action: { isShowingPreviewGenerator = true }) {
                    Label("Generate Preview", systemImage: "film.stack")
                }
                .buttonStyle(.bordered)
                
                Button(action: onOpenIINA) {
                    Label("Open in IINA", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            
            MovieInfoGrid(movie: movie)
        }
        .cardStyle()
        .padding(.horizontal)
        .sheet(isPresented: $isShowingPreviewGenerator) {
            VideoPreviewGeneratorView(videoURL: movie.url)
        }
    }
} 