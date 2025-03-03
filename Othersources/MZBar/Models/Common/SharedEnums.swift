import Foundation

// MARK: - Processing Mode
public enum ProcessingMode: String, CaseIterable, Identifiable {
    case mosaic = "Mosaic"
    case preview = "Preview"
    case playlist = "Playlist"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .mosaic: "photo.on.rectangle"
        case .preview: "eye"
        case .playlist: "music.note.list"
        case .settings: "gear"
        }
    }
    
    public var description: String {
        switch self {
        case .mosaic: "Create video mosaics"
        case .preview: "Generate video previews"
        case .playlist: "Build M3U8 playlists"
        case .settings: "Application settings"
        }
    }
}

// MARK: - Quality Preset
public enum QualityPreset: Int, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2
    case ultra = 3
    
    public var id: Int { rawValue }
    
    public var description: String {
        switch self {
        case .low: "Faster processing, lower quality"
        case .medium: "Balanced processing and quality"
        case .high: "Higher quality, slower processing"
        case .ultra: "Best quality, slowest processing"
        }
    }
    public var icon: String {
        switch self {
        case .low: "tortoise"
        case .medium: "figure.walk"
        case .high: "hare"
        case .ultra: "bolt.fill"
        }
    }
    
    public var compressionQuality: Float {
        switch self {
        case .low: 0.2
        case .medium: 0.4
        case .high: 0.6
        case .ultra: 0.8
        }
    }
} 
