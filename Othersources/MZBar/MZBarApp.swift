import SwiftUI
import UniformTypeIdentifiers

// Import ContentView
//@_spi(MZBar) import MZBarUI

@main
struct MZBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
            
        }
    }
}

extension Notification.Name {
    static let receivedURLsNotification = Notification.Name("receivedURLsNotification")
}

// Add a WindowManager class to handle window retention
class WindowManager: NSObject {
    static let shared = WindowManager()
    private var windows: Set<NSWindow> = []
    
    func addWindow(_ window: NSWindow) {
        windows.insert(window)
        window.delegate = self
    }
    
    func removeWindow(_ window: NSWindow) {
        windows.remove(window)
    }
}

extension WindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        removeWindow(window)
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupService()
    }
    
    private func setupService() {
        NSApp.servicesProvider = MosaicServiceHandler()
    }
     
    func application(_ sender: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        NotificationCenter.default.post(name: .receivedURLsNotification, object: nil, userInfo: ["URLs": urls])
    }
        
    /*
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        
        // Create a new window with its own view model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let contentView = ContentView()
        window.contentView = NSHostingView(rootView: contentView)
        
        // Update the view model with the dropped files
        DispatchQueue.main.async {
            if urls.count == 1 {
                let url = urls[0]
                contentView.viewModel.inputPaths = [(url.path, 0)]
                
                if url.hasDirectoryPath {
                    contentView.viewModel.inputType = .folder
                } else if url.pathExtension.lowercased() == "m3u8" {
                    contentView.viewModel.inputType = .m3u8
                } else {
                    contentView.viewModel.inputType = .files
                }
            } else {
                contentView.viewModel.inputPaths = urls.map { ($0.path, 0) }
                contentView.viewModel.inputType = .files
            }
        }
        
        window.makeKeyAndOrderFront(nil)
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        
        NSApp.activate(ignoringOtherApps: true)
    }*/
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.borderless, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            let contentView = ContentView()
            window.contentView = NSHostingView(rootView: contentView)
            window.makeKeyAndOrderFront(nil)
            window.center()
            window.isReleasedWhenClosed = false
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.titlebarAppearsTransparent = true
        }
        return true
    }
}


