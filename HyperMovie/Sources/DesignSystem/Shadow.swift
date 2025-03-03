import SwiftUI

/// A shadow configuration that can be applied to views
public struct Shadow {
    /// The radius of the shadow.
    public let radius: CGFloat
    
    /// The vertical offset of the shadow.
    public let y: CGFloat
    
    /// The opacity of the shadow.
    public let opacity: Double
    
    /// The color of the shadow.
    public let color: Color
    
    /// Creates a new shadow configuration.
    /// - Parameters:
    ///   - radius: The radius of the shadow.
    ///   - y: The vertical offset of the shadow.
    ///   - opacity: The opacity of the shadow.
    ///   - color: The color of the shadow, defaults to black.
    public init(radius: CGFloat, y: CGFloat, opacity: Double, color: Color = .black) {
        self.radius = radius
        self.y = y
        self.opacity = opacity
        self.color = color
    }
}

public extension View {
    /// Applies a shadow from the design system.
    /// - Parameter shadow: The shadow configuration to apply.
    /// - Returns: A view with the specified shadow applied.
    func elevation(_ shadow: Shadow) -> some View {
        self.shadow(
            color: shadow.color.opacity(shadow.opacity),
            radius: shadow.radius,
            y: shadow.y
        )
    }
    
    /// Applies a subtle glow effect using the accent color
    /// - Returns: A view with a glow effect applied
    func glow() -> some View {
        self.elevation(Theme.Elevation.glow)
    }
}

#Preview {
    VStack(spacing: Theme.Layout.Spacing.xl) {
        RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md)
            .fill(Theme.Colors.Background.elevated)
            .frame(width: 100, height: 100)
            .elevation(Theme.Elevation.none)
            .overlay {
                Text("None")
                    .foregroundStyle(Theme.Colors.Text.primary)
            }
        
        RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md)
            .fill(Theme.Colors.Background.elevated)
            .frame(width: 100, height: 100)
            .elevation(Theme.Elevation.low)
            .overlay {
                Text("Low")
                    .foregroundStyle(Theme.Colors.Text.primary)
            }
        
        RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md)
            .fill(Theme.Colors.Background.elevated)
            .frame(width: 100, height: 100)
            .elevation(Theme.Elevation.medium)
            .overlay {
                Text("Medium")
                    .foregroundStyle(Theme.Colors.Text.primary)
            }
        
        RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md)
            .fill(Theme.Colors.Background.elevated)
            .frame(width: 100, height: 100)
            .elevation(Theme.Elevation.high)
            .overlay {
                Text("High")
                    .foregroundStyle(Theme.Colors.Text.primary)
            }
        
        RoundedRectangle(cornerRadius: Theme.Layout.CornerRadius.md)
            .fill(Theme.Colors.Background.elevated)
            .frame(width: 100, height: 100)
            .glow()
            .overlay {
                Text("Glow")
                    .foregroundStyle(Theme.Colors.Text.primary)
            }
    }
    .padding()
    .background(Theme.Colors.Background.primary)
}