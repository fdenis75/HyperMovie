import SwiftUI

/// A card component that provides a consistent container style across the app.
public struct HMCard<Content: View>: View {
    private let content: Content
    private var elevation: Shadow
    private var padding: CGFloat
    private var cornerRadius: CGFloat
    private var backgroundColor: Color
    private var isInteractive: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init(
        elevation: Shadow = Theme.Elevation.medium,
        padding: CGFloat = Theme.Layout.Spacing.md,
        cornerRadius: CGFloat = Theme.Layout.CornerRadius.md,
        backgroundColor: Color = Theme.Colors.Background.secondary,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.elevation = elevation
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.isInteractive = isInteractive
    }
    
    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                themeManager.currentTheme == .chromia ? 
                                    Theme.Colors.UI.border.opacity(0.3) : 
                                    Theme.Colors.UI.border.opacity(0.2),
                                lineWidth: themeManager.currentTheme == .chromia ? 1 : 0.5
                            )
                    )
            )
            .elevation(elevation)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .hoverEffect(isInteractive ? .highlight : .inactive)
    }
}

// Hover effect modifier
extension View {
    func hoverEffect(_ effect: HoverEffect) -> some View {
        self.modifier(HoverEffectModifier(effect: effect))
    }
}

enum HoverEffect {
    case highlight
    case lift
    case glow
    case inactive
}

struct HoverEffectModifier: ViewModifier {
    let effect: HoverEffect
    @State private var isHovering = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering && effect == .lift ? 
                         (themeManager.currentTheme == .chromia ? 1.02 : 1.01) : 1.0)
            .brightness(isHovering && (effect == .highlight || effect == .lift) ? 
                        (themeManager.currentTheme == .chromia ? 0.05 : 0.03) : 0)
            .shadow(
                color: isHovering && effect == .glow ? 
                    (themeManager.currentTheme == .chromia ? 
                        Theme.Colors.accent.opacity(0.5) : 
                        Theme.Colors.accent.opacity(0.3)) : 
                    Color.clear,
                radius: themeManager.currentTheme == .chromia ? 8 : 6
            )
            .animation(Theme.Animation.quick, value: isHovering)
            .onHover { hovering in
                guard effect != .inactive else { return }
                isHovering = hovering
            }
    }
}

#Preview {
    VStack(spacing: Theme.Layout.Spacing.lg) {
        HMCard {
            VStack(alignment: .leading, spacing: Theme.Layout.Spacing.sm) {
                Text("Standard Card")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.Text.primary)
                
                Text("Card content with some description text that might span multiple lines to demonstrate the layout.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.Text.secondary)
            }
        }
        
        HMCard(isInteractive: true) {
            VStack(alignment: .leading, spacing: Theme.Layout.Spacing.sm) {
                Text("Interactive Card")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.Text.primary)
                
                Text("This card has hover effects enabled.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.Text.secondary)
            }
        }
        
        ThemeSelector()
    }
    .frame(width: 400)
    .padding()
    .background(Theme.Colors.Background.primary)
}