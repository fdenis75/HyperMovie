import SwiftUI
import SwiftData
import OSLog
import AVFoundation
import CoreGraphics
import HyperMovieCore
import HyperMovieModels
import HyperMovieServices
 //import DesignSystem

/// The main entry point for the HyperMovie application.
/// Configures the app's window, data model, and global state.
@main
struct HyperMovieApp: App {
    /// Global application state
    @State private var appState: HyperMovieServices.AppState
    @ObservedObject private var themeManager = ThemeManager.shared
    private let logger = Logger(subsystem: "com.hypermovie", category: "app")
    
    init() {
        do {
            _appState = State(initialValue: try HyperMovieServices.AppState())
        } catch {
            fatalError("Failed to initialize AppState: \(error)")
        }
    }
    /*
    /// SwiftData model container configuration
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            HyperMovieModels.Video.self,
            HyperMovieModels.LibraryItem.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize SwiftData: \(error)")
        }
    }()*/
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .modelContainer(appState.modelContainer)
                .task {
                    do {
                        try await appState.loadLibrary()
                    } catch {
                        logger.error("Failed to load library: \(error.localizedDescription)")
                    }
                }
        }
        .windowStyle(.hiddenTitleBar) // Modern macOS style
        .windowToolbarStyle(.unified)
        .commands {
            // App menu commands
            CommandGroup(after: .appInfo) {
                Button("Preferences...") {
                    appState.showPreferences.toggle()
                }
                .keyboardShortcut(",")
            }
            
            // File menu commands
            CommandGroup(after: .newItem) {
                Button("Import Videos...") {
                    appState.showImportDialog.toggle()
                }
                .keyboardShortcut("i")
            }
            
            // View menu commands
            CommandGroup(after: .sidebar) {
                Button("Toggle Preview Panel") {
                    appState.showPreviewPanel.toggle()
                }
                .keyboardShortcut("p")
                
                Divider()
                
                Menu("Theme") {
                    ForEach(ThemeType.allCases) { theme in
                        Button(theme.rawValue) {
                            themeManager.switchTheme(to: theme)
                        }
                        .checkmark(themeManager.currentTheme == theme)
                    }
                }
            }
            
            SidebarCommands()
            ToolbarCommands()
        }
        
        // Settings window
        Settings {
            SettingsView(appState: appState)
                .environment(appState)
                .modelContainer(appState.modelContainer)
        }
    }
}

// Helper extension for menu checkmarks
extension View {
    func checkmark(_ condition: Bool) -> some View {
        if condition {
            return AnyView(HStack {
                self
                Spacer()
                Image(systemName: "checkmark")
            })
        } else {
            return AnyView(self)
        }
    }
}

