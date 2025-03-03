import SwiftUI

struct HeaderView: View {
    let title: String
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.title3.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .center)
            
            Rectangle()
                .fill(.clear)
                .frame(width: 48, height: 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background {
            if colorScheme == .dark {
                Color(.windowBackgroundColor).opacity(0.8)
            } else {
                Color(.windowBackgroundColor)
                    .opacity(0.9)
                    .overlay(.ultraThinMaterial)
            }
        }
        .onHover { isHovered = $0 }
    }
} 