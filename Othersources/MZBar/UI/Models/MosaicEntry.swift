import Foundation

public struct MosaicEntry: Identifiable, Hashable {
    public let id: Int64
    public let movieId: Int64
    public let movieFilePath: String
    public let mosaicFilePath: String
    public let size: String
    public let density: String
    public let layout: String?
    public let folderHierarchy: String
    public let creationDate: String
    public let duration: Double
    public let resolution: String
    public let codec: String
    public let videoType: String
    public let generationDate: String
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public static func == (lhs: MosaicEntry, rhs: MosaicEntry) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 
