import SQLite
import Foundation

typealias Expression = SQLite.Expression

struct DatabaseSchema {
    static let movies = Table("movies")
    static let mosaicBatches = Table("mosaic_batches")
    static let mosaicsNew = Table("mosaics_new")
    static let previewBatches = Table("preview_batches")
    static let previews = Table("previews")
    static let playlists = Table("playlists")
    static let playlistItems = Table("playlist_items")
    
    // Movies table columns
    struct Movies {
        static let id = Expression<Int64>("movie_id")
        static let filePath = Expression<String>("file_path")
        static let duration = Expression<Double>("duration")
        static let resolutionWidth = Expression<Double>("resolution_width")
        static let resolutionHeight = Expression<Double>("resolution_height")
        static let codec = Expression<String>("codec")
        static let videoType = Expression<String>("video_type")
        static let creationDate = Expression<String>("creation_date")
        static let hash = Expression<String>("hash")
        static let lastScanDate = Expression<String>("last_scan_date")
    }
    
    // Mosaic Batches table columns
    struct MosaicBatches {
        static let id = Expression<Int64>("batch_id")
        static let startTime = Expression<String>("start_time")
        static let endTime = Expression<String?>("end_time")
        static let status = Expression<String>("status")
        static let settingsJson = Expression<String>("settings_json")
        static let errorMessage = Expression<String?>("error_message")
    }
    
    // Mosaics table columns
    struct MosaicsNew {
        static let id = Expression<Int64>("mosaic_id")
        static let movieId = Expression<Int64>("movie_id")
        static let batchId = Expression<Int64>("batch_id")
        static let filePath = Expression<String>("file_path")
        static let size = Expression<String>("size")
        static let density = Expression<String>("density")
        static let layout = Expression<String?>("layout")
        static let folderHierarchy = Expression<String>("folder_hierarchy")
        static let generationDate = Expression<String>("generation_date")
        static let status = Expression<String>("status")
    }
    
    // Preview Batches table columns
    struct PreviewBatches {
        static let id = Expression<Int64>("batch_id")
        static let startTime = Expression<String>("start_time")
        static let endTime = Expression<String?>("end_time")
        static let status = Expression<String>("status")
        static let settingsJson = Expression<String>("settings_json")
        static let errorMessage = Expression<String?>("error_message")
    }
    
    // Previews table columns
    struct Previews {
        static let id = Expression<Int64>("preview_id")
        static let mosaicId = Expression<Int64>("mosaic_id")
        static let batchId = Expression<Int64>("batch_id")
        static let filePath = Expression<String>("file_path")
        static let type = Expression<String>("type")
        static let size = Expression<String>("size")
        static let generationDate = Expression<String>("generation_date")
    }
    
    // Playlists table columns
    struct Playlists {
        static let id = Expression<Int64>("playlist_id")
        static let name = Expression<String>("name")
        static let creationDate = Expression<String>("creation_date")
        static let lastModified = Expression<String>("last_modified")
    }
    
    // Playlist Items table columns
    struct PlaylistItems {
        static let id = Expression<Int64>("item_id")
        static let playlistId = Expression<Int64>("playlist_id")
        static let movieId = Expression<Int64>("movie_id")
        static let position = Expression<Int>("position")
        static let addedDate = Expression<String>("added_date")
    }
    
    static func createTables(db: Connection) throws {
        // Create Movies table
        try db.run(movies.create(ifNotExists: true) { t in
            t.column(Movies.id, primaryKey: .autoincrement)
            t.column(Movies.filePath, unique: true)
            t.column(Movies.duration)
            t.column(Movies.resolutionWidth)
            t.column(Movies.resolutionHeight)
            t.column(Movies.codec)
            t.column(Movies.videoType)
            t.column(Movies.creationDate)
            t.column(Movies.hash, unique: true)
            t.column(Movies.lastScanDate)
        })
        
        // Create Mosaic Batches table
        try db.run(mosaicBatches.create(ifNotExists: true) { t in
            t.column(MosaicBatches.id, primaryKey: .autoincrement)
            t.column(MosaicBatches.startTime)
            t.column(MosaicBatches.endTime)
            t.column(MosaicBatches.status)
            t.column(MosaicBatches.settingsJson)
            t.column(MosaicBatches.errorMessage)
        })
        
        // Create Mosaics table
        try db.run(mosaicsNew.create(ifNotExists: true) { t in
            t.column(MosaicsNew.id, primaryKey: .autoincrement)
            t.column(MosaicsNew.movieId)
            t.column(MosaicsNew.batchId)
            t.column(MosaicsNew.filePath)
            t.column(MosaicsNew.size)
            t.column(MosaicsNew.density)
            t.column(MosaicsNew.layout)
            t.column(MosaicsNew.folderHierarchy)
            t.column(MosaicsNew.generationDate)
            t.column(MosaicsNew.status)
            t.foreignKey(MosaicsNew.movieId, references: movies, Movies.id)
            t.foreignKey(MosaicsNew.batchId, references: mosaicBatches, MosaicBatches.id)
        })
        
        // Create Preview Batches table
        try db.run(previewBatches.create(ifNotExists: true) { t in
            t.column(PreviewBatches.id, primaryKey: .autoincrement)
            t.column(PreviewBatches.startTime)
            t.column(PreviewBatches.endTime)
            t.column(PreviewBatches.status)
            t.column(PreviewBatches.settingsJson)
            t.column(PreviewBatches.errorMessage)
        })
        
        // Create Previews table
        try db.run(previews.create(ifNotExists: true) { t in
            t.column(Previews.id, primaryKey: .autoincrement)
            t.column(Previews.mosaicId)
            t.column(Previews.batchId)
            t.column(Previews.filePath)
            t.column(Previews.type)
            t.column(Previews.size)
            t.column(Previews.generationDate)
            t.foreignKey(Previews.mosaicId, references: mosaicsNew, MosaicsNew.id)
            t.foreignKey(Previews.batchId, references: previewBatches, PreviewBatches.id)
        })
        
        // Create Playlists table
        try db.run(playlists.create(ifNotExists: true) { t in
            t.column(Playlists.id, primaryKey: .autoincrement)
            t.column(Playlists.name)
            t.column(Playlists.creationDate)
            t.column(Playlists.lastModified)
        })
        
        // Create Playlist Items table
        try db.run(playlistItems.create(ifNotExists: true) { t in
            t.column(PlaylistItems.id, primaryKey: .autoincrement)
            t.column(PlaylistItems.playlistId)
            t.column(PlaylistItems.movieId)
            t.column(PlaylistItems.position)
            t.column(PlaylistItems.addedDate)
            t.foreignKey(PlaylistItems.playlistId, references: playlists, Playlists.id)
            t.foreignKey(PlaylistItems.movieId, references: movies, Movies.id)
        })
    }
} 