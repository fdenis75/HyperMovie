import SwiftUI

struct MissingMosaicsView: View {
    let missingMosaics: [(MosaicEntry, String)]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
               /* ForEach(missingMosaics, id: \.0.id) { entry, path in
                    VStack(alignment: .leading) {
                        Text(entry.movieFilePath.lastPathComponent)
                            .font(.headline)
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }*/
            }
            .padding()
        }
    }
}

struct MissingVideosView: View {
    let missingVideos: [(MosaicEntry, String, String)]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
               /* ForEach(missingVideos, id: \.0.id) { entry, videoPath, mosaicPath in
                    VStack(alignment: .leading) {
                        Text(videoPath.lastPathComponent)
                            .font(.headline)
                        Text("Mosaic: \(mosaicPath.lastPathComponent)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                */
            }
            .padding()
        }
    }
} 
