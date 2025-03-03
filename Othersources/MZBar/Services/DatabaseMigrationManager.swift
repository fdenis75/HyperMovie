import SQLite
import Foundation
//typealias Expression = SQLite.Expression


class DatabaseMigrationManager {
    private let db: Connection
    
    init() throws {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        db = try Connection("\(path)/mosaic_metadata.sqlite3")
    }
    
    
    func migrateToNewSchema() throws {
        // Validate old schema exists
        let oldMosaics = Table("mosaics")
        guard try db.scalar(oldMosaics.exists) else {
            throw DatabaseError.migrationError("Old mosaics table does not exist")
        }
        
        // Count records for validation
        let totalRecords = try db.scalar(oldMosaics.count)
        var migratedRecords = 0
        
        print("Starting migration of \(totalRecords) records...")
        
        // Start a transaction
        try db.transaction {
            // 1. Create new tables
            try DatabaseSchema.createTables(db: self.db)
            
            // Create a batch for existing mosaics
            let batchId = try self.createLegacyMigrationBatch()
            
            // Migrate each mosaic entry
            for mosaic in try db.prepare(oldMosaics) {
                try self.migrateMosaicEntry(mosaic, batchId: batchId)
                migratedRecords += 1
                
                if migratedRecords % 100 == 0 {
                    print("Migrated \(migratedRecords)/\(totalRecords) records...")
                }
            }
            
            // Verify migration
            let newMosaicsCount = try db.scalar(DatabaseSchema.mosaicsNew.count)
            let newMoviesCount = try db.scalar(DatabaseSchema.movies.count)
            
            guard newMosaicsCount == totalRecords else {
                throw DatabaseError.migrationError("Migration count mismatch: expected \(totalRecords) mosaics, got \(newMosaicsCount)")
            }
            
            print("Migration completed successfully:")
            print("- Migrated \(newMosaicsCount) mosaics")
            print("- Created \(newMoviesCount) movie entries")
            
            // 3. Drop old tables (optional - can be done later if migration is successful)
            // try db.run(oldMosaics.drop())
        }
    }
    
    private func createLegacyMigrationBatch() throws -> Int64 {
        let insert = DatabaseSchema.mosaicBatches.insert(
            DatabaseSchema.MosaicBatches.startTime <- ISO8601DateFormatter().string(from: Date()),
            DatabaseSchema.MosaicBatches.status <- "completed",
            DatabaseSchema.MosaicBatches.settingsJson <- "{\"migration\": \"legacy\"}"
        )
        return try db.run(insert)
    }
    
    private func migrateMosaicEntry(_ mosaic: Row, batchId: Int64) throws {
        do {
            // Extract required fields first to validate
            let movieFilePath = try mosaic[Expression<String>("movie_file_path")]
            let mosaicFilePath = try mosaic[Expression<String>("mosaic_file_path")]
            
            print("Migrating mosaic: \(mosaicFilePath)")
            print("Associated movie: \(movieFilePath)")
            
            // First, create the movie entry
            let movieId = try insertMovie(mosaic)
            print("Created movie entry with ID: \(movieId)")
            
            // Then create the mosaic entry
            try insertMosaic(mosaic, movieId: movieId, batchId: batchId)
            print("Successfully migrated mosaic entry")
            
        } catch let error as SQLite.Result {
            print("SQLite error during migration:")
            print("- Code: \(error)")
            print("- Description: \(error.description)")
            throw DatabaseError.migrationError("SQLite error: \(error.description)")
        } catch {
            print("Failed to migrate mosaic entry:")
            print("- Error: \(error)")
            print("- Description: \(error.localizedDescription)")
            throw DatabaseError.migrationError("Migration failed: \(error.localizedDescription)")
        }
    }
    
    private func insertMovie(_ mosaic: Row) throws -> Int64 {
        let movieFilePath = mosaic[Expression<String>("movie_file_path")]
        
        // Check if movie already exists by file path
        if let existingMovie = try db.pluck(DatabaseSchema.movies.filter(DatabaseSchema.Movies.filePath == movieFilePath)) {
            print("Movie already exists with file path: \(movieFilePath)")
            return existingMovie[DatabaseSchema.Movies.id]
        }
        
        let hash = mosaic[Expression<String>("hash")]
        let duration = mosaic[Expression<Double>("duration")]
        let resolutionWidth = mosaic[SQLite.Expression<Double>("resolution_width")]
        let resolutionHeight = mosaic[SQLite.Expression<Double>("resolution_height")]
        let codec = mosaic[Expression<String>("codec")]
        let videoType = mosaic[Expression<String>("video_type")]
        let creationDate = mosaic[Expression<String>("creation_date")]
        
        let insert = DatabaseSchema.movies.insert(
            DatabaseSchema.Movies.filePath <- movieFilePath,
            DatabaseSchema.Movies.duration <- duration,
            DatabaseSchema.Movies.resolutionWidth <- resolutionWidth,
            DatabaseSchema.Movies.resolutionHeight <- resolutionHeight,
            DatabaseSchema.Movies.codec <- codec,
            DatabaseSchema.Movies.videoType <- videoType,
            DatabaseSchema.Movies.creationDate <- creationDate,
            DatabaseSchema.Movies.hash <- hash,
            DatabaseSchema.Movies.lastScanDate <- ISO8601DateFormatter().string(from: Date())
        )
        
        return try db.run(insert)
    }
    
    private func insertMosaic(_ mosaic: Row, movieId: Int64, batchId: Int64) throws {
        let mosaicFilePath = mosaic[Expression<String>("mosaic_file_path")]
        let size = mosaic[Expression<String>("size")]
        let density = mosaic[Expression<String>("density")]
        let layout = mosaic[Expression<String?>("layout")]
        let folderHierarchy = mosaic[Expression<String>("folder_hierarchy")]
        
        let insert = DatabaseSchema.mosaicsNew.insert(
            DatabaseSchema.MosaicsNew.movieId <- movieId,
            DatabaseSchema.MosaicsNew.batchId <- batchId,
            DatabaseSchema.MosaicsNew.filePath <- mosaicFilePath,
            DatabaseSchema.MosaicsNew.size <- size,
            DatabaseSchema.MosaicsNew.density <- density,
            DatabaseSchema.MosaicsNew.layout <- layout,
            DatabaseSchema.MosaicsNew.folderHierarchy <- folderHierarchy,
            DatabaseSchema.MosaicsNew.generationDate <- ISO8601DateFormatter().string(from: Date()),
                DatabaseSchema.MosaicsNew.status <- "generated"
        )
        
        try db.run(insert)
    }
}

enum DatabaseError: Error {
    case migrationError(String)
} 
