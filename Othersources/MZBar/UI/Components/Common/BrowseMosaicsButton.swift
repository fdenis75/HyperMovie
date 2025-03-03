import SwiftUI

struct BrowseMosaicsButton: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        Button(action: { viewModel.showMosaicBrowser() }) {
            Label("Browse Mosaics", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }
} 