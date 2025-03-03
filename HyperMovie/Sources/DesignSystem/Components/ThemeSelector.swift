import SwiftUI

/// A component that allows users to select between different themes
public struct ThemeSelector: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    public init() {}
    
    public var body: some View {
        Picker("Theme", selection: $themeManager.currentTheme) {
            ForEach(ThemeType.allCases) { theme in
                Text(theme.rawValue).tag(theme)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 120)
    }
}

/// A preview of the theme selector
struct ThemeSelector_Previews: PreviewProvider {
    static var previews: some View {
        ThemeSelector()
            .padding()
            .background(Theme.Colors.Background.primary)
    }
} 