import Foundation

enum ProcessingState: Equatable {
    case idle
    case processing(progress: Double)
    case completed
    case error(message: String)
    case cancelled
    
    var isProcessing: Bool {
        if case .processing = self {
            return true
        }
        return false
    }
    
    var progress: Double {
        if case .processing(let progress) = self {
            return progress
        }
        return 0
    }
} 