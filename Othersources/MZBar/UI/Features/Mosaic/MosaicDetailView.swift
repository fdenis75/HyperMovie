//
//  MosaicDetailView.swift
//  MZBar
//
//  Created by Francois on 31/12/2024.
//

import SwiftUI

struct MosaicBrowserDetailView: View {
    let file: ResultFiles?
    @State private var isShowingIINA = false
    
    var body: some View {
        VStack {
            if let file = file {
                if let image = NSImage(contentsOf: file.output) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Button(action: {
                        openInIINA(sourceFile: file.video.path())
                    }) {
                        Label("Play in IINA", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            } else {
                Text("Select a file to view its mosaic")
                    .font(.title2)
                    .foregroundStyle(.secondary)
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
