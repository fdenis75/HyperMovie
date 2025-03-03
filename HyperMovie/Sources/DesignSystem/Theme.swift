import SwiftUI
//@_exported import struct HyperMovie.Shadow

/// Theme selection options
public enum ThemeType: String, CaseIterable, Identifiable {
    case classic = "Classic"
    case chromia = "Chromia"
    
    public var id: String { self.rawValue }
}

/// Theme manager to handle theme selection and persistence
public class ThemeManager: ObservableObject {
    @Published public var currentTheme: ThemeType {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    public init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? ThemeType.classic.rawValue
        self.currentTheme = ThemeType(rawValue: savedTheme) ?? .classic
    }
    
    public func switchTheme(to theme: ThemeType) {
        self.currentTheme = theme
    }
}

/// HyperMovie Design System
/// A modern, dark-themed design system inspired by Chromia UI that provides consistent styling across the app.
public enum Theme {
    /// Semantic colors for the application
    public enum Colors {
        /// Get the appropriate color based on the current theme
        public static func forTheme(_ theme: ThemeType) -> ThemeColors {
            switch theme {
            case .classic:
                return ClassicThemeColors()
            case .chromia:
                return ChromiaThemeColors()
            }
        }
        
        /// Primary brand color - Vibrant purple-pink gradient
        public static var accent: Color {
            ThemeManager.shared.currentTheme == .classic ? Color.blue : Color("AccentColor")
        }
        
        public static var accentGradient: LinearGradient {
            ThemeManager.shared.currentTheme == .classic ? 
                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.7)], startPoint: .leading, endPoint: .trailing) :
                LinearGradient(colors: [Color(hex: "#9D4EDD"), Color(hex: "#FF007F")], startPoint: .leading, endPoint: .trailing)
        }
        
        /// Background colors
        public enum Background {
            /// Deep charcoal/near-black
            public static var primary: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#1A1A1A") : Color(hex: "#121214")
            }
            
            /// Slightly lighter dark gray for cards
            public static var secondary: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#2A2A2A") : Color(hex: "#1E1E24")
            }
            
            /// Medium gray for inactive elements
            public static var elevated: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#333333") : Color(hex: "#252530")
            }
        }
        
        /// Text colors
        public enum Text {
            public static var primary: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#F5F5F5") : Color(hex: "#FFFFFF")
            }
            
            public static var secondary: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#D0D0D0") : Color(hex: "#E5E5E5")
            }
            
            public static var tertiary: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#A0A0A0") : Color(hex: "#AAAAAA")
            }
            
            public static var quaternary: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#707070") : Color(hex: "#777777")
            }
        }
        
        /// UI element colors
        public enum UI {
            public static var border: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#404040") : Color(hex: "#303040")
            }
            
            public static var shadow: Color {
                ThemeManager.shared.currentTheme == .classic ? Color.black.opacity(0.25) : Color.black.opacity(0.3)
            }
            
            public static var overlay: Color {
                ThemeManager.shared.currentTheme == .classic ? Color.black.opacity(0.4) : Color.black.opacity(0.5)
            }
            
            public static var inactive: Color {
                ThemeManager.shared.currentTheme == .classic ? Color(hex: "#606060") : Color(hex: "#505060")
            }
            
            public static var success: Color {
                ThemeManager.shared.currentTheme == .classic ? Color.green : Color(hex: "#4ADE80")
            }
        }
    }
    
    /// Typography scale for the application
    public enum Typography {
        public static let largeTitle = Font.system(size: 42, weight: .bold)
        public static let title1 = Font.system(size: 28, weight: .bold)
        public static let title2 = Font.system(size: 22, weight: .medium)
        public static let title3 = Font.system(size: 20, weight: .medium)
        public static let headline = Font.system(size: 18, weight: .medium)
        public static let body = Font.system(size: 16, weight: .regular)
        public static let callout = Font.system(size: 16, weight: .regular)
        public static let subheadline = Font.system(size: 14, weight: .regular)
        public static let footnote = Font.system(size: 13, weight: .light)
        public static let caption1 = Font.system(size: 12, weight: .light)
        public static let caption2 = Font.system(size: 11, weight: .light)
        
        // For large numbers/stats
        public static let statistic = Font.system(size: 36, weight: .bold)
    }
    
    /// Layout metrics and spacing
    public enum Layout {
        /// Standard spacing units
        public enum Spacing {
            public static let xxxs: CGFloat = 2
            public static let xxs: CGFloat = 4
            public static let xs: CGFloat = 8
            public static let sm: CGFloat = 12
            public static let md: CGFloat = 16
            public static let lg: CGFloat = 24
            public static let xl: CGFloat = 32
            public static let xxl: CGFloat = 48
            public static let xxxl: CGFloat = 64
        }
        
        /// Corner radius values
        public enum CornerRadius {
            public static var sm: CGFloat {
                ThemeManager.shared.currentTheme == .classic ? 4 : 8
            }
            
            public static var md: CGFloat {
                ThemeManager.shared.currentTheme == .classic ? 8 : 10
            }
            
            public static var lg: CGFloat {
                ThemeManager.shared.currentTheme == .classic ? 12 : 16
            }
            
            public static var xl: CGFloat {
                ThemeManager.shared.currentTheme == .classic ? 16 : 24
            }
            
            public static var pill: CGFloat {
                999
            }
        }
        
        /// Standard icon sizes
        public enum IconSize {
            public static let sm: CGFloat = 16
            public static let md: CGFloat = 20
            public static let lg: CGFloat = 24
            public static let xl: CGFloat = 32
        }
    }
    
    /// Animation timings and curves
    public enum Animation {
        public static var standard: SwiftUI.Animation {
            ThemeManager.shared.currentTheme == .classic ? 
                SwiftUI.Animation.easeInOut(duration: 0.2) : 
                SwiftUI.Animation.easeOut(duration: 0.2)
        }
        
        public static var quick: SwiftUI.Animation {
            ThemeManager.shared.currentTheme == .classic ? 
                SwiftUI.Animation.easeInOut(duration: 0.1) : 
                SwiftUI.Animation.easeOut(duration: 0.15)
        }
        
        public static var slow: SwiftUI.Animation {
            ThemeManager.shared.currentTheme == .classic ? 
                SwiftUI.Animation.easeInOut(duration: 0.3) : 
                SwiftUI.Animation.easeOut(duration: 0.3)
        }
        
        public static var spring: SwiftUI.Animation {
            ThemeManager.shared.currentTheme == .classic ? 
                SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0) :
                SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
        }
    }
    
    /// Shadows for elevation
    public enum Elevation {
        public static var none: Shadow {
            Shadow(radius: 0, y: 0, opacity: 0)
        }
        
        public static var low: Shadow {
            ThemeManager.shared.currentTheme == .classic ? 
                Shadow(radius: 2, y: 1, opacity: 0.1, color: .black) :
                Shadow(radius: 4, y: 2, opacity: 0.15, color: .black)
        }
        
        public static var medium: Shadow {
            ThemeManager.shared.currentTheme == .classic ? 
                Shadow(radius: 4, y: 2, opacity: 0.15, color: .black) :
                Shadow(radius: 8, y: 4, opacity: 0.2, color: .black)
        }
        
        public static var high: Shadow {
            ThemeManager.shared.currentTheme == .classic ? 
                Shadow(radius: 8, y: 4, opacity: 0.2, color: .black) :
                Shadow(radius: 12, y: 6, opacity: 0.25, color: .black)
        }
        
        public static var glow: Shadow {
            ThemeManager.shared.currentTheme == .classic ? 
                Shadow(radius: 6, y: 0, opacity: 0.3, color: .blue) :
                Shadow(radius: 8, y: 0, opacity: 0.5, color: Color(hex: "#9D4EDD"))
        }
    }
}

// Singleton instance of ThemeManager for easy access
extension ThemeManager {
    public static let shared = ThemeManager()
}

// Protocol for theme colors
public protocol ThemeColors {
    var accent: Color { get }
    var accentGradient: LinearGradient { get }
    
    var backgroundPrimary: Color { get }
    var backgroundSecondary: Color { get }
    var backgroundElevated: Color { get }
    
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textQuaternary: Color { get }
    
    var uiBorder: Color { get }
    var uiShadow: Color { get }
    var uiOverlay: Color { get }
    var uiInactive: Color { get }
    var uiSuccess: Color { get }
}

// Classic theme colors implementation
public struct ClassicThemeColors: ThemeColors {
    public var accent: Color = Color.blue
    public var accentGradient: LinearGradient = LinearGradient(
        colors: [Color.blue, Color.blue.opacity(0.7)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public var backgroundPrimary: Color = Color(hex: "#1A1A1A")
    public var backgroundSecondary: Color = Color(hex: "#2A2A2A")
    public var backgroundElevated: Color = Color(hex: "#333333")
    
    public var textPrimary: Color = Color(hex: "#F5F5F5")
    public var textSecondary: Color = Color(hex: "#D0D0D0")
    public var textTertiary: Color = Color(hex: "#A0A0A0")
    public var textQuaternary: Color = Color(hex: "#707070")
    
    public var uiBorder: Color = Color(hex: "#404040")
    public var uiShadow: Color = Color.black.opacity(0.25)
    public var uiOverlay: Color = Color.black.opacity(0.4)
    public var uiInactive: Color = Color(hex: "#606060")
    public var uiSuccess: Color = Color.green
}

// Chromia theme colors implementation
public struct ChromiaThemeColors: ThemeColors {
    public var accent: Color = Color(hex: "#9D4EDD")
    public var accentGradient: LinearGradient = LinearGradient(
        colors: [Color(hex: "#9D4EDD"), Color(hex: "#FF007F")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public var backgroundPrimary: Color = Color(hex: "#121214")
    public var backgroundSecondary: Color = Color(hex: "#1E1E24")
    public var backgroundElevated: Color = Color(hex: "#252530")
    
    public var textPrimary: Color = Color(hex: "#FFFFFF")
    public var textSecondary: Color = Color(hex: "#E5E5E5")
    public var textTertiary: Color = Color(hex: "#AAAAAA")
    public var textQuaternary: Color = Color(hex: "#777777")
    
    public var uiBorder: Color = Color(hex: "#303040")
    public var uiShadow: Color = Color.black.opacity(0.3)
    public var uiOverlay: Color = Color.black.opacity(0.5)
    public var uiInactive: Color = Color(hex: "#505060")
    public var uiSuccess: Color = Color(hex: "#4ADE80")
}

// Helper extension to create colors from hex values
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 