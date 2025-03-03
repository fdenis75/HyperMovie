import SQLite
import Foundation

class DatabaseManager {
    static let shared = DatabaseManager()
    private let db: Connection
    
    private init() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            db = try Connection("\(path)/mosaic_metadata.sqlite3")
            try DatabaseSchema.createTables(db: db)
        } catch {
            fatalError("Database connection failed: \(error)")
        }
    }
    
    func createMosaicBatch(settingsJson: String) throws -> Int64 {
        let insert = DatabaseSchema.mosaicBatches.insert(
            DatabaseSchema.MosaicBatches.startTime <- ISO8601DateFormatter().string(from: Date()),
            DatabaseSchema.MosaicBatches.status <- "in_progress",
            DatabaseSchema.MosaicBatches.settingsJson <- settingsJson
        )
        return try db.run(insert)
    }
    
    func getOrCreateMovie(filePath: String, hash: String, metadata: VideoMetadata) throws -> Int64 {
        // First try to find existing movie
        if let movie = try db.pluck(DatabaseSchema.movies.filter(DatabaseSchema.Movies.hash == hash)) {
            return movie[DatabaseSchema.Movies.id]
        }
        
        // Create new movie entry
        let insert = DatabaseSchema.movies.insert(
            DatabaseSchema.Movies.filePath <- filePath,
            DatabaseSchema.Movies.duration <- metadata.duration,
            DatabaseSchema.Movies.resolutionWidth <- metadata.resolution.width,
            DatabaseSchema.Movies.resolutionHeight <- metadata.resolution.height,
            DatabaseSchema.Movies.codec <- metadata.codec,
            DatabaseSchema.Movies.videoType <- metadata.type,
            DatabaseSchema.Movies.creationDate <- metadata.creationDate ?? ISO8601DateFormatter().string(from: Date()),
            DatabaseSchema.Movies.hash <- hash,
            DatabaseSchema.Movies.lastScanDate <- ISO8601DateFormatter().string(from: Date())
        )
        return try db.run(insert)
    }
    
    func isDuplicateMosaic(movieId: Int64, size: String, density: String, layout: String) -> Bool {
        do {
            let query = DatabaseSchema.mosaicsNew.filter(
                DatabaseSchema.MosaicsNew.movieId == movieId &&
                DatabaseSchema.MosaicsNew.size == size &&
                DatabaseSchema.MosaicsNew.density == density &&
                DatabaseSchema.MosaicsNew.layout == layout
            )
            return try db.scalar(query.count) > 0
        } catch {
            return false
        }
    }
    
    func insertMosaic(movieId: Int64, batchId: Int64, filePath: String, size: String, density: String, layout: String, folderHierarchy: String, hash: String, metadata: VideoMetadata) throws {
        let insert = DatabaseSchema.mosaicsNew.insert(
            DatabaseSchema.MosaicsNew.movieId <- movieId,
            DatabaseSchema.MosaicsNew.batchId <- batchId,
            DatabaseSchema.MosaicsNew.filePath <- filePath,
            DatabaseSchema.MosaicsNew.size <- size,
            DatabaseSchema.MosaicsNew.density <- density,
            DatabaseSchema.MosaicsNew.layout <- layout,
            DatabaseSchema.MosaicsNew.folderHierarchy <- folderHierarchy,
            DatabaseSchema.MosaicsNew.generationDate <- ISO8601DateFormatter().string(from: Date()),
            DatabaseSchema.MosaicsNew.status <- "generated"
        )
        try db.run(insert)
    }
    
    func updateAllCreationDates() -> [String: Int] {
        var stats = ["updated": 0, "removed": 0]
        do {
            let query = DatabaseSchema.movies
            for movie in try db.prepare(query) {
                let filePath = movie[DatabaseSchema.Movies.filePath]
                if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
                   let creationDate = attributes[.creationDate] as? Date {
                    let dateString = ISO8601DateFormatter().string(from: creationDate)
                    try db.run(query.filter(DatabaseSchema.Movies.id == movie[DatabaseSchema.Movies.id])
                        .update(DatabaseSchema.Movies.creationDate <- dateString))
                    stats["updated"]! += 1
                } else {
                    stats["removed"]! += 1
                }
            }
        } catch {
            print("Error updating dates: \(error)")
        }
        return stats
    }
    
    func findMissingMosaicFiles() -> [(MosaicEntry, String)] {
        var missing: [(MosaicEntry, String)] = []
        do {
            let query = DatabaseSchema.mosaicsNew
                .join(.leftOuter, DatabaseSchema.movies,
                      on: DatabaseSchema.MosaicsNew.movieId == DatabaseSchema.Movies.id)
            for row in try db.prepare(query) {
                let mosaicPath = row[DatabaseSchema.MosaicsNew.filePath]
                if !FileManager.default.fileExists(atPath: mosaicPath) {
                    let entry = MosaicEntry(
                        id: row[DatabaseSchema.MosaicsNew.id],
                        movieId: row[DatabaseSchema.MosaicsNew.movieId],
                        movieFilePath: row[DatabaseSchema.Movies.filePath],
                        mosaicFilePath: mosaicPath,
                        size: row[DatabaseSchema.MosaicsNew.size],
                        density: row[DatabaseSchema.MosaicsNew.density],
                        layout: row[DatabaseSchema.MosaicsNew.layout],
                        folderHierarchy: row[DatabaseSchema.MosaicsNew.folderHierarchy],
                        creationDate: row[DatabaseSchema.Movies.creationDate],
                        duration: Double(row[DatabaseSchema.Movies.duration]),
                        resolution: "\(Int(row[DatabaseSchema.Movies.resolutionWidth]))x\(Int(row[DatabaseSchema.Movies.resolutionHeight]))",
                        codec: row[DatabaseSchema.Movies.codec],
                        videoType: row[DatabaseSchema.Movies.videoType],
                        generationDate: row[DatabaseSchema.MosaicsNew.generationDate]
                    )
                    missing.append((entry, mosaicPath))
                }
            }
        } catch {
            print("Error finding missing files: \(error)")
        }
        return missing
    }
    
    func deleteMissingMosaicEntries(_ entries: [MosaicEntry]) {
        do {
            for entry in entries {
                try db.run(DatabaseSchema.mosaicsNew.filter(DatabaseSchema.MosaicsNew.id == entry.id).delete())
            }
        } catch {
            print("Error deleting entries: \(error)")
        }
    }
    
    func deleteMissingVideoEntries(_ entries: [MosaicEntry]) {
        do {
            for entry in entries {
                let movieQuery = DatabaseSchema.movies.filter(DatabaseSchema.Movies.filePath == entry.movieFilePath)
                if let movieId = try db.pluck(movieQuery)?[DatabaseSchema.Movies.id] {
                    try db.run(DatabaseSchema.mosaicsNew.filter(DatabaseSchema.MosaicsNew.movieId == movieId).delete())
                    try db.run(movieQuery.delete())
                }
            }
        } catch {
            print("Error deleting entries: \(error)")
        }
    }
    /*
    func fetchMosaicEntries() -> [MosaicEntry] {
        do {
            let query = DatabaseSchema.mosaicsNew
                .join(.leftOuter, DatabaseSchema.movies,
                      on: DatabaseSchema.MosaicsNew.movieId == DatabaseSchema.Movies.id)
                .order(DatabaseSchema.MosaicsNew.id.desc)
            
            return try db.prepare(query).map { row in
                MosaicEntry(
                    id: row[DatabaseSchema.MosaicsNew.id],
                    movieId: row[DatabaseSchema.MosaicsNew.movieId],
                    movieFilePath: row[DatabaseSchema.Movies.filePath],
                    mosaicFilePath: row[DatabaseSchema.MosaicsNew.filePath],
                    size: row[DatabaseSchema.MosaicsNew.size],
                    density: row[DatabaseSchema.MosaicsNew.density],
                    layout: row[DatabaseSchema.MosaicsNew.layout],
                    folderHierarchy: row[DatabaseSchema.MosaicsNew.folderHierarchy],
                        hash: row[DatabaseSchema.Movies.hash],
                    duration: String(row[DatabaseSchema.Movies.duration]),
                    resolutionWidth: String(row[DatabaseSchema.Movies.resolutionWidth]),
                    resolutionHeight: String(row[DatabaseSchema.Movies.resolutionHeight]),
                    codec: row[DatabaseSchema.Movies.codec],
                    videoType: row[DatabaseSchema.Movies.videoType],
                    creationDate: row[DatabaseSchema.Movies.creationDate]
                )
            }
        } catch {
            print("Error fetching mosaic entries: \(error)")
            return []
        }
    }
    */
    func fetchAllMosaics() async throws -> [MosaicEntry] {
        let mosaicsTable = DatabaseSchema.mosaicsNew
        let moviesTable = DatabaseSchema.movies
        
        let query = mosaicsTable
            .join(.inner, moviesTable, 
                  on: mosaicsTable[DatabaseSchema.MosaicsNew.movieId] == moviesTable[DatabaseSchema.Movies.id])
            .select(
                mosaicsTable[DatabaseSchema.MosaicsNew.id],
                mosaicsTable[DatabaseSchema.MosaicsNew.movieId],
                moviesTable[DatabaseSchema.Movies.filePath],
                mosaicsTable[DatabaseSchema.MosaicsNew.filePath],
                mosaicsTable[DatabaseSchema.MosaicsNew.size],
                mosaicsTable[DatabaseSchema.MosaicsNew.density],
                mosaicsTable[DatabaseSchema.MosaicsNew.layout],
                mosaicsTable[DatabaseSchema.MosaicsNew.folderHierarchy],
                moviesTable[DatabaseSchema.Movies.creationDate],
                moviesTable[DatabaseSchema.Movies.duration],
                moviesTable[DatabaseSchema.Movies.resolutionWidth],
                moviesTable[DatabaseSchema.Movies.resolutionHeight],
                moviesTable[DatabaseSchema.Movies.codec],
                moviesTable[DatabaseSchema.Movies.videoType],
                mosaicsTable[DatabaseSchema.MosaicsNew.generationDate]
            )
            .order(moviesTable[DatabaseSchema.Movies.creationDate].desc)
        
        var mosaics: [MosaicEntry] = []
        for row in try db.prepare(query) {
            let mosaic = MosaicEntry(
                id: row[mosaicsTable[DatabaseSchema.MosaicsNew.id]],
                movieId: row[mosaicsTable[DatabaseSchema.MosaicsNew.movieId]],
                movieFilePath: row[moviesTable[DatabaseSchema.Movies.filePath]],
                mosaicFilePath: row[mosaicsTable[DatabaseSchema.MosaicsNew.filePath]],
                size: row[mosaicsTable[DatabaseSchema.MosaicsNew.size]],
                density: row[mosaicsTable[DatabaseSchema.MosaicsNew.density]],
                layout: row[mosaicsTable[DatabaseSchema.MosaicsNew.layout]],
                folderHierarchy: row[mosaicsTable[DatabaseSchema.MosaicsNew.folderHierarchy]],
                creationDate: row[moviesTable[DatabaseSchema.Movies.creationDate]],
                duration: row[moviesTable[DatabaseSchema.Movies.duration]],
                resolution: "\(Int(row[moviesTable[DatabaseSchema.Movies.resolutionWidth]]))x\(Int(row[moviesTable[DatabaseSchema.Movies.resolutionHeight]]))",
                codec: row[moviesTable[DatabaseSchema.Movies.codec]],
                videoType: row[moviesTable[DatabaseSchema.Movies.videoType]],
                generationDate: row[mosaicsTable[DatabaseSchema.MosaicsNew.generationDate]]
            )
            mosaics.append(mosaic)
        }
        return mosaics
    }
    
    func fetchMosaicsPage(filterParams: MosaicFilterParams) async throws -> [MosaicEntry] {
        let mosaicsTable = DatabaseSchema.mosaicsNew
        let moviesTable = DatabaseSchema.movies
        let batchesTable = DatabaseSchema.mosaicBatches
        
        // Start building the query
        var query = mosaicsTable
            .join(.inner, moviesTable, 
                  on: mosaicsTable[DatabaseSchema.MosaicsNew.movieId] == moviesTable[DatabaseSchema.Movies.id])
            .join(.inner, batchesTable,
                  on: mosaicsTable[DatabaseSchema.MosaicsNew.batchId] == batchesTable[DatabaseSchema.MosaicBatches.id])
        
        // Apply search filter if present
        if !filterParams.searchQuery.isEmpty {
            query = query.filter(
                moviesTable[DatabaseSchema.Movies.filePath].like("%\(filterParams.searchQuery)%") ||
                mosaicsTable[DatabaseSchema.MosaicsNew.folderHierarchy].like("%\(filterParams.searchQuery)%")
            )
        }
        
        // Apply category filters
        for (category, value) in filterParams.filters {
            switch category {
            // Movie properties
            case .folder:
                query = query.filter(mosaicsTable[DatabaseSchema.MosaicsNew.folderHierarchy].like("%\(value)%"))
            case .resolution:
                // Parse resolution string (e.g., "1920x1080")
                let components = value.split(separator: "x")
                if components.count == 2,
                   let width = Double(components[0]),
                   let height = Double(components[1]) {
                    query = query.filter(
                        moviesTable[DatabaseSchema.Movies.resolutionWidth] == width &&
                        moviesTable[DatabaseSchema.Movies.resolutionHeight] == height
                    )
                }
            case .codec:
                query = query.filter(moviesTable[DatabaseSchema.Movies.codec] == value)
            case .videoType:
                query = query.filter(moviesTable[DatabaseSchema.Movies.videoType] == value)
                
            // Mosaic properties
            case .size:
                query = query.filter(mosaicsTable[DatabaseSchema.MosaicsNew.size] == value)
            case .density:
                query = query.filter(mosaicsTable[DatabaseSchema.MosaicsNew.density] == value)
            case .layout:
                query = query.filter(mosaicsTable[DatabaseSchema.MosaicsNew.layout] == value)
            }
        }
        
        // Apply movie creation date range filter if present
        if let dateRange = filterParams.dateRange {
            query = query.filter(
                moviesTable[DatabaseSchema.Movies.creationDate] >= dateRange.start &&
                moviesTable[DatabaseSchema.Movies.creationDate] <= dateRange.end
            )
        }
        
        // Apply batch generation date range filter if present
        if let batchDateRange = filterParams.batchDateRange {
            query = query.filter(
                batchesTable[DatabaseSchema.MosaicBatches.startTime] >= batchDateRange.start &&
                batchesTable[DatabaseSchema.MosaicBatches.startTime] <= batchDateRange.end
            )
        }
        
        // Add pagination
        query = query
            .order(moviesTable[DatabaseSchema.Movies.creationDate].desc)
            .limit(filterParams.limit, offset: filterParams.offset)
        
        // Select required columns
        query = query.select(
            mosaicsTable[DatabaseSchema.MosaicsNew.id],
            mosaicsTable[DatabaseSchema.MosaicsNew.movieId],
            moviesTable[DatabaseSchema.Movies.filePath],
            mosaicsTable[DatabaseSchema.MosaicsNew.filePath],
            mosaicsTable[DatabaseSchema.MosaicsNew.size],
            mosaicsTable[DatabaseSchema.MosaicsNew.density],
            mosaicsTable[DatabaseSchema.MosaicsNew.layout],
            mosaicsTable[DatabaseSchema.MosaicsNew.folderHierarchy],
            moviesTable[DatabaseSchema.Movies.creationDate],
            moviesTable[DatabaseSchema.Movies.duration],
            moviesTable[DatabaseSchema.Movies.resolutionWidth],
            moviesTable[DatabaseSchema.Movies.resolutionHeight],
            moviesTable[DatabaseSchema.Movies.codec],
            moviesTable[DatabaseSchema.Movies.videoType],
            mosaicsTable[DatabaseSchema.MosaicsNew.generationDate],
            batchesTable[DatabaseSchema.MosaicBatches.startTime]
        )
        
        print("🔍 Executing SQL query: \(query)")
        var mosaics: [MosaicEntry] = []
        for row in try db.prepare(query) {
            let mosaic = MosaicEntry(
                id: row[mosaicsTable[DatabaseSchema.MosaicsNew.id]],
                movieId: row[mosaicsTable[DatabaseSchema.MosaicsNew.movieId]],
                movieFilePath: row[moviesTable[DatabaseSchema.Movies.filePath]],
                mosaicFilePath: row[mosaicsTable[DatabaseSchema.MosaicsNew.filePath]],
                size: row[mosaicsTable[DatabaseSchema.MosaicsNew.size]],
                density: row[mosaicsTable[DatabaseSchema.MosaicsNew.density]],
                layout: row[mosaicsTable[DatabaseSchema.MosaicsNew.layout]],
                folderHierarchy: row[mosaicsTable[DatabaseSchema.MosaicsNew.folderHierarchy]],
                creationDate: row[moviesTable[DatabaseSchema.Movies.creationDate]],
                duration: row[moviesTable[DatabaseSchema.Movies.duration]],
                resolution: "\(Int(row[moviesTable[DatabaseSchema.Movies.resolutionWidth]]))x\(Int(row[moviesTable[DatabaseSchema.Movies.resolutionHeight]]))",
                codec: row[moviesTable[DatabaseSchema.Movies.codec]],
                videoType: row[moviesTable[DatabaseSchema.Movies.videoType]],
                generationDate: row[mosaicsTable[DatabaseSchema.MosaicsNew.generationDate]]
            )
            mosaics.append(mosaic)
        }
        return mosaics
    }
    
    func fetchFilterValues() async throws -> [FilterCategory: Set<String>] {
        var filters: [FilterCategory: Set<String>] = [:]
        
        // Use separate optimized queries for each filter category
        let queries = [
            "SELECT DISTINCT COALESCE(folder_hierarchy, 'N/A') FROM mosaics_new",
            "SELECT DISTINCT COALESCE(size, 'N/A') FROM mosaics_new",
            "SELECT DISTINCT COALESCE(density, 'N/A') FROM mosaics_new",
            "SELECT DISTINCT COALESCE(layout, 'N/A') FROM mosaics_new",
            "SELECT DISTINCT COALESCE(video_type, 'N/A') FROM movies",
            "SELECT DISTINCT COALESCE(codec, 'N/A') FROM movies"
        ]
        
        for (index, query) in queries.enumerated() {
            let category = FilterCategory.allCases[index]
            let results = try await db.prepare(query)
            filters[category] = Set(results.map { $0[0] as! String })
        }
        
        return filters
    }
    
    func countTotalMosaics() async throws -> Int {
        let mosaicsTable = DatabaseSchema.mosaicsNew
        return try db.scalar(mosaicsTable.count)
    }
    
    func fetchMosaicsWithProgress() async throws -> [MosaicEntry] {
        let mosaicsTable = DatabaseSchema.mosaicsNew
        let moviesTable = DatabaseSchema.movies
        
        let query = mosaicsTable
            .join(.inner, moviesTable, 
                  on: mosaicsTable[DatabaseSchema.MosaicsNew.movieId] == moviesTable[DatabaseSchema.Movies.id])
            .select(
                mosaicsTable[DatabaseSchema.MosaicsNew.id],
                mosaicsTable[DatabaseSchema.MosaicsNew.movieId],
                moviesTable[DatabaseSchema.Movies.filePath],
                mosaicsTable[DatabaseSchema.MosaicsNew.filePath],
                mosaicsTable[DatabaseSchema.MosaicsNew.size],
                mosaicsTable[DatabaseSchema.MosaicsNew.density],
                mosaicsTable[DatabaseSchema.MosaicsNew.layout],
                mosaicsTable[DatabaseSchema.MosaicsNew.folderHierarchy],
                mosaicsTable[DatabaseSchema.MosaicsNew.generationDate],
                moviesTable[DatabaseSchema.Movies.creationDate],
                moviesTable[DatabaseSchema.Movies.duration],
                moviesTable[DatabaseSchema.Movies.resolutionWidth],
                moviesTable[DatabaseSchema.Movies.resolutionHeight],
                moviesTable[DatabaseSchema.Movies.codec],
                moviesTable[DatabaseSchema.Movies.videoType]
            )
            .order(moviesTable[DatabaseSchema.Movies.creationDate].desc)
        
        var mosaics: [MosaicEntry] = []
        for row in try db.prepare(query) {
            let mosaic = MosaicEntry(
                id: row[mosaicsTable[DatabaseSchema.MosaicsNew.id]],
                movieId: row[mosaicsTable[DatabaseSchema.MosaicsNew.movieId]],
                movieFilePath: row[moviesTable[DatabaseSchema.Movies.filePath]],
                mosaicFilePath: row[mosaicsTable[DatabaseSchema.MosaicsNew.filePath]],
                size: row[mosaicsTable[DatabaseSchema.MosaicsNew.size]],
                density: row[mosaicsTable[DatabaseSchema.MosaicsNew.density]],
                layout: row[mosaicsTable[DatabaseSchema.MosaicsNew.layout]],
                folderHierarchy: row[mosaicsTable[DatabaseSchema.MosaicsNew.folderHierarchy]],
                creationDate: row[moviesTable[DatabaseSchema.Movies.creationDate]],
                duration: row[moviesTable[DatabaseSchema.Movies.duration]],
                resolution: "\(Int(row[moviesTable[DatabaseSchema.Movies.resolutionWidth]]))x\(Int(row[moviesTable[DatabaseSchema.Movies.resolutionHeight]]))",
                codec: row[moviesTable[DatabaseSchema.Movies.codec]],
                videoType: row[moviesTable[DatabaseSchema.Movies.videoType]],
                generationDate: row[mosaicsTable[DatabaseSchema.MosaicsNew.generationDate]]
            )
            mosaics.append(mosaic)
        }
        return mosaics
    }
} 

