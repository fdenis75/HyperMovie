import SwiftUI
import AppKit
import MZBar

@available(macOS 14.0, *)
struct MosaicNavigatorDetailView: View {
    let file: MosaicEntry
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        VStack {
            if let image = NSImage(contentsOf: URL(fileURLWithPath: file.mosaicFilePath)) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Button(action: {
                    openInIINA(sourceFile: file.movieFilePath)
                }) {
                    Label("Play in IINA", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .navigationTitle("Mosaic Preview")
    }
    
    private func openInIINA(sourceFile: String) {
        let url = URL(fileURLWithPath: sourceFile)
        let iinaURL = URL(string: "iina://open?url=\(url.path)")!
        NSWorkspace.shared.open(iinaURL)
    }
} 