import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ObservedObject var viewModel: MosaicViewModel
    let content: Content
    @State private var isHovered = false
    
    init(
        title: String,
        icon: String,
        viewModel: MosaicViewModel,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.viewModel = viewModel
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(viewModel.currentTheme.colors.primary)
            
            content
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? viewModel.currentTheme.colors.primary : Color.gray.opacity(0.3), lineWidth: isHovered ? 2 : 1)
        )
    }
} 