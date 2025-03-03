import Foundation

struct SmartFolder: Identifiable, Codable {
    let id: UUID
    var name: String
    var criteria: SmartFolderCriteria
    let dateCreated: Date
    var mosaicDirName: String?
    
    init(name: String, criteria: SmartFolderCriteria) {
        self.id = UUID()
        self.name = name
        self.criteria = criteria
        self.dateCreated = Date()
        self.mosaicDirName = criteria.generateMosaicFolderName()
    }
}

struct SmartFolderCriteria: Codable {
    var dateRange: DateRange?
    var nameContains: String?
    var folderNameContains: String?
    var minDuration: TimeInterval?
    var maxDuration: TimeInterval?
    var fileSize: FileSizeRange?
    var fileTypes: [String]?
    
    var description: String {
        var parts: [String] = []
        if let name = nameContains, !name.isEmpty { parts.append("Name: \(name)") }
        if let folder = folderNameContains, !folder.isEmpty { parts.append("Folder: \(folder)") }
        if let dates = dateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            if let start = dates.start { parts.append("From: \(formatter.string(from: start))") }
            if let end = dates.end { parts.append("To: \(formatter.string(from: end))") }
        }
        if let size = fileSize {
            if let min = size.min { parts.append("Min: \(min/1_000_000)MB") }
            if let max = size.max { parts.append("Max: \(max/1_000_000)MB") }
        }
        return parts.isEmpty ? "No criteria set" : parts.joined(separator: ", ")
    }
    
    struct DateRange: Codable {
        var start: Date?
        var end: Date?
    }
    
    struct FileSizeRange: Codable {
        var min: Int64?
        var max: Int64?
    }
    
    /// Returns a short string suitable for use as a mosaic folder name.
    /// The string is generated based on the criteria settings.
    /// - Returns: A string that summarizes the criteria, or nil if no criteria are set.
    func generateMosaicFolderName() -> String? {
        var components: [String] = []
        
        // Add name filter if present
        if let name = nameContains, !name.isEmpty {
            components.append("n-\(name)")
        }
        
        // Add folder filter if present 
        if let folder = folderNameContains, !folder.isEmpty {
            components.append("f-\(folder)")
        }
        
        // Add date range if present
        if let dates = dateRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyMMdd"
            if let start = dates.start {
                components.append("from-\(formatter.string(from: start))")
            }
            if let end = dates.end {
                components.append("to-\(formatter.string(from: end))")
            }
        }
        
        // Add size range if present
        if let size = fileSize {
            if let min = size.min {
                components.append("min\(min/1_000_000)MB")
            }
            if let max = size.max {
                components.append("max\(max/1_000_000)MB") 
            }
        }
        
        // Return nil if no criteria are set
        guard !components.isEmpty else { return nil }
        
        // Join with underscores and limit length
        let joined = components.joined(separator: "_")
        let maxLength = 50
        if joined.count <= maxLength {
            return joined
        }
        return String(joined.prefix(maxLength))
    }
}

@MainActor
class SmartFolderManager: ObservableObject {
    static let shared = SmartFolderManager()
    @Published private(set) var defaultSmartFolders: [SmartFolder] = []
    @Published private(set) var userSmartFolders: [SmartFolder] = []
    public let diskCache = ThumbnailCacheManager.shared
    public let memoryCache = ThumbnailMemoryCache.shared
    
   


    var smartFolders: [SmartFolder] {
        defaultSmartFolders + userSmartFolders
    }
    
    private let smartFoldersKey = "smartFolders"
    
    init() {
        loadSmartFolders()
        defaultSmartFolders = createDefaultSmartFolders()
    }
    
    func addSmartFolder(name: String, criteria: SmartFolderCriteria) {
        let folder = SmartFolder(name: name, criteria: criteria)
        userSmartFolders.append(folder)
        saveSmartFolders()
    }
    
    func removeSmartFolder(id: UUID) {
        // Only remove if it's not a default folder
        if !defaultSmartFolders.contains(where: { $0.id == id }) {
            userSmartFolders.removeAll { $0.id == id }
            saveSmartFolders()
        }
    }
    
    func updateSmartFolder(_ folder: SmartFolder) {
        if let index = userSmartFolders.firstIndex(where: { $0.id == folder.id }) {
            userSmartFolders[index] = folder
            saveSmartFolders()
        }
    }
    
    func matchesCriteria(movie: MovieFile, criteria: SmartFolderCriteria) -> Bool {
        // Check name contains
        if let nameContains = criteria.nameContains,
           !nameContains.isEmpty,
           !movie.name.localizedStandardContains(nameContains) {
            return false
        }
        
        // Check folder name contains
        if let folderNameContains = criteria.folderNameContains,
           !folderNameContains.isEmpty {
            let components = movie.relativePath.split(separator: "/")
            if let folderName = components.first.map(String.init),
               !folderName.localizedStandardContains(folderNameContains) {
                return false
            }
        }
        
        // Check date range
        if let dateRange = criteria.dateRange,
           let resourceValues = try? movie.url.resourceValues(forKeys: [.contentModificationDateKey]),
           let modificationDate = resourceValues.contentModificationDate {
            if let start = dateRange.start, modificationDate < start {
                return false
            }
            if let end = dateRange.end, modificationDate > end {
                return false
            }
        }
        
        // Check file size
        if let fileSize = criteria.fileSize,
           let resourceValues = try? movie.url.resourceValues(forKeys: [.fileSizeKey]),
           let size = resourceValues.fileSize {
            if let min = fileSize.min, Int64(size) < min {
                return false
            }
            if let max = fileSize.max, Int64(size) > max {
                return false
            }
        }
        
        // Check file types
        if let fileTypes = criteria.fileTypes,
           !fileTypes.isEmpty,
           !fileTypes.contains(movie.url.pathExtension.lowercased()) {
            return false
        }
        
        return true
    }
    
    private func createDefaultSmartFolders() -> [SmartFolder] {
        let calendar = Calendar.current
        let now = Date()
        
        // Today's videos with date in name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let todayString = dateFormatter.string(from: now)
        
        let today = SmartFolder(
            name: "Videos \(todayString)",
            criteria: SmartFolderCriteria(
                dateRange: .init(
                    start: calendar.startOfDay(for: now),
                    end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
                )
            )
        )
        
        // This week's videos
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        let weekStartString = dateFormatter.string(from: weekStart)
        let weekEndString = dateFormatter.string(from: weekEnd)
        
        let thisWeek = SmartFolder(
            name: "Week \(weekStartString) - \(weekEndString)",
            criteria: SmartFolderCriteria(
                dateRange: .init(
                    start: weekStart,
                    end: weekEnd
                )
            )
        )
        
        // This month's videos
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        dateFormatter.dateFormat = "MMMM yyyy"
        let monthString = dateFormatter.string(from: now)
        
        let thisMonth = SmartFolder(
            name: "Month \(monthString)",
            criteria: SmartFolderCriteria(
                dateRange: .init(
                    start: monthStart,
                    end: monthEnd
                )
            )
        )
        
        // This year's videos
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)!
        dateFormatter.dateFormat = "yyyy"
        let yearString = dateFormatter.string(from: now)
        
        let thisYear = SmartFolder(
            name: "Year \(yearString)",
            criteria: SmartFolderCriteria(
                dateRange: .init(
                    start: yearStart,
                    end: yearEnd
                )
            )
        )
        
        // Large videos (keeping this from the original defaults)
        let large = SmartFolder(
            name: "Large Videos",
            criteria: SmartFolderCriteria(
                fileSize: .init(min: 4_000_000_000)
            )
        )
        
        return [today, thisWeek, thisMonth, thisYear, large]
    }
    
    private func loadSmartFolders() {
        guard let data = UserDefaults.standard.data(forKey: smartFoldersKey) else { return }
        do {
            userSmartFolders = try JSONDecoder().decode([SmartFolder].self, from: data)
        } catch {
            print("Error loading smart folders: \(error)")
        }
    }
    
    private func saveSmartFolders() {
        do {
            let data = try JSONEncoder().encode(userSmartFolders)
            UserDefaults.standard.set(data, forKey: smartFoldersKey)
        } catch {
            print("Error saving smart folders: \(error)")
        }
    }

/*
    func getVideos(for folder: SmartFolder) async throws -> [MovieFile] {
        let query = NSMetadataQuery()
        var predicates: [NSPredicate] = []
        
        // Add file name filter
        if let nameFilter = folder.criteria.nameContains {
            predicates.append(NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", nameFilter))
        }
        
        // Add folder name filter
        if let folderNameFilter = folder.criteria.folderNameContains {
            predicates.append(NSPredicate(format: "kMDItemPath CONTAINS[cd] %@", folderNameFilter))
        }
        
        // Add date range
        if let dateRange = folder.criteria.dateRange {
            if let start = dateRange.start {
                predicates.append(NSPredicate(format: "kMDItemContentCreationDate >= %@", start as NSDate))
            }
            if let end = dateRange.end {
                predicates.append(NSPredicate(format: "kMDItemContentCreationDate < %@", end as NSDate))
            }
        }
        
        // Add file size range
        if let fileSize = folder.criteria.fileSize {
            if let min = fileSize.min {
                predicates.append(NSPredicate(format: "kMDItemFSSize >= %lld", min))
            }
            if let max = fileSize.max {
                predicates.append(NSPredicate(format: "kMDItemFSSize <= %lld", max))
            }
        }
        
        // Add video type filter
        let typePredicates = videoTypes.map { type in
            NSPredicate(format: "kMDItemContentTypeTree == %@", type)
        }
        predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates))
        
        // Combine all predicates
        query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.sortDescriptors = [.init(key: "kMDItemContentCreationDate", ascending: false)]
        
        return try await withCheckedThrowingContinuation { continuation in
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { [weak observer] _ in
                defer {
                    if let observer = observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    query.stop()
                }
                
                do {
                    let videos = (query.results as! [NSMetadataItem]).compactMap { item -> MovieFile? in
                        guard let path = item.value(forAttribute: "kMDItemPath") as? String else {
                            return nil
                        }
                        let url = URL(fileURLWithPath: path)
                        guard !(url.lastPathComponent.lowercased().contains("amprv") || 
                               url.pathExtension.lowercased().contains("rmvb")) else {
                            return nil
                        }
                        
                        // Create movie file with cached thumbnail if available
                        let movie = MovieFile(url: url)
                        if let cachedThumb = try? await self.diskCache.getThumbnail(for: url) {
                            movie.thumbnail = cachedThumb
                        } else if let memoryThumb = await self.memoryCache.get(forKey: movie.id.uuidString) {
                            movie.thumbnail = memoryThumb
                        }
                        
                        return movie
                    }
                    continuation.resume(returning: videos)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            DispatchQueue.main.async {
                query.start()
            }
        }
    }
    */
} 
