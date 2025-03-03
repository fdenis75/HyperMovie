import SwiftUI

/// Style variants for the button
public enum HMButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
}

/// Size variants for the button
public enum HMButtonSize {
    case small
    case regular
    case large
}

/// A button component that provides consistent styling across the app.
public struct HMButton: View {
    private let title: String
    private let icon: String?
    private let style: HMButtonStyle
    private let size: HMButtonSize
    private let action: () -> Void
    private let isLoading: Bool
    private let isDisabled: Bool
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init(
        _ title: String,
        icon: String? = nil,
        style: HMButtonStyle = .primary,
        size: HMButtonSize = .regular,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Layout.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .controlSize(controlSize)
                        .tint(textColor)
                } else if let icon {
                    Image(systemName: icon)
                        .font(iconFont)
                        .foregroundStyle(textColor)
                }
                
                Text(title)
                    .font(textFont)
                    .foregroundStyle(textColor)
            }
            .frame(height: height)
            .padding(.horizontal, horizontalPadding)
            .background {
                if style == .primary {
                    if themeManager.currentTheme == .chromia {
                        Theme.Colors.accentGradient
                            .clipShape(Capsule())
                    } else {
                        Capsule()
                            .fill(Theme.Colors.accent)
                    }
                } else if style == .secondary {
                    Capsule()
                        .fill(Theme.Colors.Background.elevated)
                        .overlay(
                            Capsule()
                                .strokeBorder(Theme.Colors.UI.border, lineWidth: 1)
                        )
                } else if style == .destructive {
                    Capsule()
                        .fill(Color.red)
                }
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .elevation(style == .primary ? Theme.Elevation.low : Theme.Elevation.none)
        }
        .buttonStyle(HMButtonPressStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
    
    // MARK: - Private Helpers
    
    private var textColor: Color {
        switch style {
        case .primary, .destructive:
            return Theme.Colors.Text.primary
        case .secondary:
            return Theme.Colors.Text.primary
        case .tertiary:
            return Theme.Colors.accent
        }
    }
    
    private var height: CGFloat {
        switch size {
        case .small: return themeManager.currentTheme == .chromia ? 32 : 28
        case .regular: return themeManager.currentTheme == .chromia ? 40 : 36
        case .large: return themeManager.currentTheme == .chromia ? 48 : 44
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return Theme.Layout.Spacing.md
        case .regular: return Theme.Layout.Spacing.lg
        case .large: return Theme.Layout.Spacing.xl
        }
    }
    
    private var textFont: Font {
        switch size {
        case .small: return Theme.Typography.subheadline
        case .regular: return Theme.Typography.body
        case .large: return Theme.Typography.headline
        }
    }
    
    private var iconFont: Font {
        switch size {
        case .small: return .system(size: 14)
        case .regular: return .system(size: 16)
        case .large: return .system(size: 18)
        }
    }
    
    private var controlSize: ControlSize {
        switch size {
        case .small: return .small
        case .regular: return .regular
        case .large: return .large
        }
    }
}

// Custom button press style
struct HMButtonPressStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? (themeManager.currentTheme == .chromia ? 0.97 : 0.98) : 1.0)
            .opacity(configuration.isPressed ? (themeManager.currentTheme == .chromia ? 0.9 : 0.8) : 1.0)
            .animation(themeManager.currentTheme == .chromia ? 
                       .easeOut(duration: 0.15) : 
                       .easeInOut(duration: 0.1), 
                       value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: Theme.Layout.Spacing.lg) {
        HMButton("Primary Button", icon: "star.fill") {}
        HMButton("Secondary Button", icon: "gear", style: .secondary) {}
        HMButton("Tertiary Button", style: .tertiary) {}
        HMButton("Destructive Button", icon: "trash", style: .destructive) {}
        HMButton("Loading Button", isLoading: true) {}
        HMButton("Disabled Button", isDisabled: true) {}
        
        HStack {
            HMButton("Small", size: .small) {}
            HMButton("Regular", size: .regular) {}
            HMButton("Large", size: .large) {}
        }
        
        ThemeSelector()
    }
    .padding()
    .background(Theme.Colors.Background.primary)
} 