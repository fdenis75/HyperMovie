import Foundation
import AVKit
import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movieview", category: "FolderProcessing")

protocol MovieFileProtocol: Identifiable, Equatable, Hashable {
    var id: UUID { get }
    var url: URL { get }
    var relativePath: String { get }
    var name: String { get }
}

// Default implementation of Hashable for MovieFileProtocol
extension MovieFileProtocol {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Default implementation of Equatable for MovieFileProtocol
extension MovieFileProtocol {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

protocol FolderProcessorProtocol: ObservableObject {
    associatedtype MovieType: MovieFileProtocol
    var movies: [MovieType] { get }
    var isProcessing: Bool { get }
    var error: Error? { get }
    var showAlert: Bool { get }
    var smartFolderName: String? { get }
    
    func cancelProcessing()
    func dismissAlert()
    func setError(_ error: Error)
    func processFolder(at url: URL) async throws
    func processVideos(from urls: [URL]) async
    func setSmartFolderName(_ name: String) async
}

@MainActor
class FolderProcessor: FolderProcessorProtocol {
    typealias MovieType = MovieFile
    
    @Published var movies: [MovieFile] = []
    @Published var isProcessing = false
    @Published private(set) var error: Error?
    @Published private(set) var showAlert = false
    @Published var smartFolderName: String?
    
    private var processTask: Task<Void, Never>?
    private let diskCache = ThumbnailCacheManager.shared
    private let memoryCache = ThumbnailMemoryCache.shared
    private let thumbnailQueue = DispatchQueue(label: "com.movieview.thumbnail-generation", qos: .utility)
    
    func setError(_ error: Error) {
        self.error = error
        self.showAlert = true
    }
    
    func dismissAlert() {
        error = nil
        showAlert = false
    }
    
    func setSmartFolderName(_ name: String) {
        smartFolderName = name
    }
    
    private func generateAndCacheThumbnail(for url: URL) async throws -> NSImage? {
        // Check memory cache first
        if let metadata = try? ThumbnailCacheMetadata.generateCacheKey(for: url),
           let (cached, _, _) = await memoryCache.retrieve(forKey: metadata) {
            return cached
        }
        
        // Check disk cache
        if let metadata = try? ThumbnailCacheMetadata.generateCacheKey(for: url),
           let cached = try? await diskCache.retrieveThumbnail(for: url, at: 0, quality: .standard) {
            await memoryCache.store(
                image: cached,
                forKey: metadata,
                timestamp: 0,
                quality: .standard
            )
            return cached
        }
        
        // Generate new thumbnail if not cached
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            let size = try await track.load(.naturalSize)
            let aspectRatio = size.width / size.height
            generator.maximumSize = CGSize(width: 320, height: 320 / aspectRatio)
        }
        
        do {
            let duration = try await asset.load(.duration)
            let time = CMTimeMultiplyByFloat64(duration, multiplier: 0.1)
            let cgImage = try await generator.image(at: time).image
            let thumbnail = NSImage(cgImage: cgImage, size: NSSizeFromCGSize(generator.maximumSize))
            
            // Cache the generated thumbnail
            if let metadata = try? ThumbnailCacheMetadata.generateCacheKey(for: url) {
                await memoryCache.store(
                    image: thumbnail,
                    forKey: metadata,
                    timestamp: 0,
                    quality: .standard
                )
                try? await diskCache.storeThumbnail(
                    cgImage,
                    for: url,
                    at: 0,
                    quality: .standard,
                    parameters: .standard
                )
            }
            
            return thumbnail
        } catch {
            logger.error("Failed to generate thumbnail for \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
    
    func processVideos(from urls: [URL]) async {
        logger.info("Processing \(urls.count) videos")
        isProcessing = true
        movies.removeAll()
        
        processTask = Task {
            for url in urls {
                guard !Task.isCancelled else { break }
                
                do {
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        logger.error("File not found: \(url.path)")
                        throw AppError.fileNotFound(url)
                    }
                    
                    guard FileManager.default.isReadableFile(atPath: url.path) else {
                        logger.error("File not accessible: \(url.path)")
                        throw AppError.fileNotAccessible(url)
                    }
                    
                    var movie = MovieFile(url: url)
                    
                    if let thumbnail = try? await generateAndCacheThumbnail(for: url) {
                        await MainActor.run {
                            movie.thumbnail = thumbnail
                            if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                                movies[index] = movie
                            } else {
                                movies.append(movie)
                            }
                        }
                    } else {
                        await MainActor.run {
                            movies.append(movie)
                        }
                    }
                } catch {
                    logger.error("Error processing video \(url.path): \(error.localizedDescription)")
                    setError(error)
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    func processFolder(at url: URL) async throws {
        logger.info("Processing folder at: \(url.path)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.error("Folder not found: \(url.path)")
            throw AppError.fileNotFound(url)
        }
        
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            logger.error("Folder not accessible: \(url.path)")
            throw AppError.fileNotAccessible(url)
        }
        
        isProcessing = true
        processTask?.cancel()
        movies = []
        
        processTask = Task {
            await processDirectory(at: url)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func processDirectory(at url: URL) async {
        guard !Task.isCancelled else { return }
        
        do {
            let resourceKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .contentModificationDateKey,
                .fileSizeKey,
                .typeIdentifierKey
            ]
            
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            guard let enumerator = enumerator else {
                logger.error("Failed to create enumerator for folder: \(url.path)")
                throw AppError.folderProcessingFailed(url, "Failed to enumerate directory")
            }
            
            for case let fileURL as URL in enumerator {
                guard !Task.isCancelled else { break }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    
                    if resourceValues.isDirectory ?? false { continue }
                    
                    if let typeIdentifier = resourceValues.typeIdentifier,
                       UTType(typeIdentifier)?.conforms(to: .movie) ?? false {
                        let relativePath = fileURL.path.replacingOccurrences(of: url.path, with: "")
                        let movie = MovieFile(url: fileURL, relativePath: relativePath)
                        
                        await MainActor.run {
                            movies.append(movie)
                        }
                        
                        if let thumbnail = try? await generateAndCacheThumbnail(for: fileURL) {
                            await MainActor.run {
                                if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                                    movies[index].thumbnail = thumbnail
                                }
                            }
                        }
                    }
                } catch {
                    logger.error("Error processing file \(fileURL.path): \(error.localizedDescription)")
                    continue
                }
            }
        } catch {
            logger.error("Error processing folder \(url.path): \(error.localizedDescription)")
            setError(AppError.folderProcessingFailed(url, error.localizedDescription))
        }
    }
    
    func cancelProcessing() {
        logger.info("Cancelling folder processing")
        processTask?.cancel()
        processTask = nil
        isProcessing = false
    }
} 
