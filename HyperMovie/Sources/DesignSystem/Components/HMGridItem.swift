import SwiftUI
@_exported import struct SwiftUI.Image
@_exported import struct SwiftUI.EmptyView
//@_exported import enum HyperMovie.Theme

/// A grid item component that provides consistent styling for grid layouts.
public struct HMGridItem<Content: View>: View {
    private let content: Content
    private let title: String
    private let subtitle: String?
    private let isSelected: Bool
    private let action: (() -> Void)?
    
    @State private var isHovering = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: Theme.Layout.Spacing.xs) {
            ZStack {
                content
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md))
                
                // Selection indicator or hover effect
                if isSelected || (isHovering && action != nil) {
                    RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md)
                        .stroke(
                            isSelected ? Theme.Colors.accent : Theme.Colors.UI.border, 
                            lineWidth: isSelected ? 
                                (themeManager.currentTheme == .chromia ? 2 : 1.5) : 
                                (themeManager.currentTheme == .chromia ? 1 : 0.5)
                        )
                        .opacity(isSelected ? 1.0 : (themeManager.currentTheme == .chromia ? 0.7 : 0.5))
                }
            }
            
            VStack(alignment: .leading, spacing: Theme.Layout.Spacing.xxs) {
                Text(title)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.Text.primary)
                    .lineLimit(1)
                
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption1)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Layout.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.lg)
                .fill(Theme.Colors.Background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.lg)
                        .strokeBorder(
                            isSelected ? 
                                Theme.Colors.accent.opacity(themeManager.currentTheme == .chromia ? 0.3 : 0.2) : 
                                Theme.Colors.UI.border.opacity(themeManager.currentTheme == .chromia ? 0.3 : 0.2),
                            lineWidth: themeManager.currentTheme == .chromia ? 1 : 0.5
                        )
                )
        )
        .scaleEffect(isHovering && action != nil ? 
                    (themeManager.currentTheme == .chromia ? 1.02 : 1.01) : 1.0)
        .elevation(isSelected ? 
                  Theme.Elevation.medium : 
                  (isHovering && action != nil ? Theme.Elevation.low : Theme.Elevation.none))
        .animation(Theme.Animation.quick, value: isHovering)
        .animation(Theme.Animation.quick, value: isSelected)
        .contentShape(Rectangle())
        .if(action != nil) { view in
            view
                .onTapGesture {
                    action?()
                }
                .onHover { hovering in
                    isHovering = hovering
                }
        }
    }
}

// Convenience initializer for image-based grid items
public extension HMGridItem where Content == AnyView {
    init(
        title: String,
        subtitle: String? = nil,
        image: Image,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            action: action
        ) {
            AnyView(
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
        }
    }
    
    // New initializer that accepts a decorated image view
    init<ImageContent: View>(
        title: String,
        subtitle: String? = nil,
        decoratedImage: ImageContent,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            isSelected: isSelected,
            action: action
        ) {
            AnyView(decoratedImage)
        }
    }
}

#Preview {
    VStack {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 160, maximum: 200), spacing: Theme.Layout.Spacing.md)
        ], spacing: Theme.Layout.Spacing.md) {
            HMGridItem(
                title: "Grid Item 1",
                subtitle: "Description"
            ) {
                Color(hex: "#9D4EDD")
                    .frame(height: 120)
            }
            
            HMGridItem(
                title: "Selected Item",
                subtitle: "With longer description text",
                isSelected: true
            ) {
                Color(hex: "#FF007F")
                    .frame(height: 120)
            }
            
            HMGridItem(
                title: "Tappable Item",
                subtitle: "Click me!",
                action: {}
            ) {
                LinearGradient(
                    colors: [Color(hex: "#9D4EDD"), Color(hex: "#FF007F")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)
            }
            
            HMGridItem(
                title: "Image Item",
                subtitle: "Using image initializer",
                decoratedImage: Image(systemName: "photo.fill")
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(Theme.Colors.Background.elevated),
                action: {}
            )
        }
        
        ThemeSelector()
    }
    .padding()
    .background(Theme.Colors.Background.primary)
}
