import Foundation

// MARK: - File Progress
public struct FileProgress: Identifiable, Hashable {
    public let id = UUID()
    public let filename: String
    public var progress: Double = 0.0
    public var stage: String = "Queued"
    public var isComplete: Bool = false
    public var isCancelled: Bool = false
    public var isSkipped: Bool = false
    public var isError: Bool = false
    public var errorMessage: String?
    public var outputURL: URL?
    
    public init(filename: String) {
        self.filename = filename
    }
    
    public static func == (lhs: FileProgress, rhs: FileProgress) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Result Files
public struct ResultFiles: Identifiable {
    public let id = UUID()
    public let video: URL
    public let output: URL
    
    public init(video: URL, output: URL) {
        self.video = video
        self.output = output
    }
    
    public var description: String {
        video.lastPathComponent
    }
} 