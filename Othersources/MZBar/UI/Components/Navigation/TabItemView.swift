import SwiftUI

struct TabItemView: View {
    let tab: TabSelection
    let icon: String
    let title: String
    @ObservedObject var viewModel: MosaicViewModel
    
    var body: some View {
        NavigationLink(value: tab) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(viewModel.selectedMode == tab ? Color.white : Color.secondary)
                    .frame(width: 32, height: 32, alignment: .center)
            }
            .padding(8)
        }
        .buttonStyle(.plain)
        .frame(alignment: .center)
    }
} 

