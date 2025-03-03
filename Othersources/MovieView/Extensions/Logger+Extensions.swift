import Foundation
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier!
    
    static let shared = Logger(subsystem: subsystem, category: "default")
    static let mosaicGeneration = Logger(subsystem: subsystem, category: "MosaicGeneration")
    static let videoProcessing = Logger(subsystem: subsystem, category: "VideoProcessing")
    static let folderProcessing = Logger(subsystem: subsystem, category: "FolderProcessing")
    static let cache = Logger(subsystem: subsystem, category: "Cache")
    static let ui = Logger(subsystem: subsystem, category: "UI")
} 