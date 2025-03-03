import SwiftUI
@_exported import struct SwiftUI.EmptyView
//@_exported import enum HyperMovie.Theme

/// A list item component that provides consistent styling for list rows.
public struct HMListItem<Leading: View, Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let leading: Leading
    private let trailing: Trailing
    private let showDivider: Bool
    private let isSelected: Bool
    private let action: (() -> Void)?
    
    @State private var isHovering = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init(
        title: String,
        subtitle: String? = nil,
        showDivider: Bool = true,
        isSelected: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showDivider = showDivider
        self.isSelected = isSelected
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Layout.Spacing.md) {
                leading
                
                VStack(alignment: .leading, spacing: Theme.Layout.Spacing.xxs) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.Text.primary)
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.Text.secondary)
                    }
                }
                
                Spacer(minLength: Theme.Layout.Spacing.md)
                
                trailing
            }
            .padding(.vertical, Theme.Layout.Spacing.sm)
            .padding(.horizontal, Theme.Layout.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.sm)
                    .fill(backgroundFill)
            )
            
            if showDivider {
                Divider()
                    .padding(.leading, Theme.Layout.Spacing.md)
                    .background(Color.clear)
                    .opacity(themeManager.currentTheme == .chromia ? 0.3 : 0.2)
            }
        }
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
    
    private var backgroundFill: Color {
        if isSelected {
            return themeManager.currentTheme == .chromia ? 
                Theme.Colors.Background.elevated : 
                Theme.Colors.Background.elevated.opacity(0.8)
        } else if isHovering && action != nil {
            return themeManager.currentTheme == .chromia ? 
                Theme.Colors.Background.secondary.opacity(0.5) : 
                Theme.Colors.Background.secondary.opacity(0.3)
        } else {
            return Color.clear
        }
    }
}

// Convenience initializers for common use cases
public extension HMListItem {
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        showDivider: Bool = true,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) where Leading == AnyView, Trailing == EmptyView {
        self.init(
            title: title,
            subtitle: subtitle,
            showDivider: showDivider,
            isSelected: isSelected,
            action: action,
            leading: {
                AnyView(
                    Image(systemName: icon)
                        .font(.system(size: Theme.Layout.IconSize.md))
                        .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.Text.secondary)
                )
            },
            trailing: { EmptyView() }
        )
    }
    
    init(
        title: String,
        subtitle: String? = nil,
        showDivider: Bool = true,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) where Leading == EmptyView, Trailing == EmptyView {
        self.init(
            title: title,
            subtitle: subtitle,
            showDivider: showDivider,
            isSelected: isSelected,
            action: action,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

// Helper extension for optional view modifier
extension View {
    @ViewBuilder
    public func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        HMListItem(
            title: "Movie Project",
            subtitle: "Last edited 2 days ago",
            icon: "film",
            action: {}
        )
        
        HMListItem(
            title: "Selected Item",
            subtitle: "This item is currently selected",
            icon: "star.fill",
            isSelected: true,
            action: {}
        )
        
        HMListItem(
            title: "Custom Item",
            subtitle: "With custom leading and trailing views",
            showDivider: true,
            action: {},
            leading: {
                Circle()
                    .fill(Theme.Colors.accentGradient)
                    .frame(width: 32, height: 32)
            },
            trailing: {
                Text("Details")
                    .font(Theme.Typography.caption1)
                    .foregroundStyle(Theme.Colors.accent)
            }
        )
        
        ThemeSelector()
    }
    .padding()
    .frame(width: 400)
    .background(Theme.Colors.Background.primary)
}
    
