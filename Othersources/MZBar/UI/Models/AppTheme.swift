import SwiftUI

struct AppTheme {
    let colors: ThemeColors
    
    struct ThemeColors {
        let primary: Color
        let accent: Color
        let background: Color
        let surfaceBackground: Color
    }
    
    init(from mode: TabSelection) {
        switch mode {
        case .mosaic:
            self.colors = ThemeColors(
                primary: .blue,
                accent: .purple,
                background: .black.opacity(0.1),
                surfaceBackground: .white.opacity(0.1)
            )
        case .preview:
            self.colors = ThemeColors(
                primary: .green,
                accent: .blue,
                background: .black.opacity(0.1),
                surfaceBackground: .white.opacity(0.1)
            )
        case .playlist:
            self.colors = ThemeColors(
                primary: .purple,
                accent: .pink,
                background: .black.opacity(0.1),
                surfaceBackground: .white.opacity(0.1)
            )
        case .settings, .navigator:
            self.colors = ThemeColors(
                primary: .orange,
                accent: .yellow,
                background: .black.opacity(0.1),
                surfaceBackground: .white.opacity(0.1)
            )
        }
    }
    
    static var mosaic: AppTheme {
        AppTheme(from: .mosaic)
    }
} 