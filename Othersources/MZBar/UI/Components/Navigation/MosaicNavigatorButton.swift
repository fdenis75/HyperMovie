import SwiftUI

struct MosaicNavigatorButton: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        Button(action: { viewModel.showMosaicNavigator() }) {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    //.foregroundStyle(viewModel.selectedMode == tab ? Color.white : Color.secondary)
                    .frame(width: 32, height: 32, alignment: .center)
            }
            .padding(8)
        }
        .buttonStyle(.plain)
         .frame(alignment: .center)
    }
} 
