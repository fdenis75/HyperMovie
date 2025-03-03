
extension SmartFolderManager {
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
                
                Task {
                    do {
                        var videos: [MovieFile] = []
                        
                        for item in query.results as! [NSMetadataItem] {
                            guard let path = item.value(forAttribute: "kMDItemPath") as? String else {
                                continue
                            }
                            
                            let url = URL(fileURLWithPath: path)
                            guard !(url.lastPathComponent.lowercased().contains("amprv") || 
                                   url.pathExtension.lowercased().contains("rmvb")) else {
                                continue
                            }
                            
                            var movie = MovieFile(url: url)
                            
                            // Try to get cached thumbnail
                            if let metadata = try? ThumbnailCacheMetadata.generateCacheKey(for: url) {
                                if let (cached, _, _) = await self.memoryCache.retrieve(forKey: metadata) {
                                    movie.thumbnail = cached
                                } else if let cached = try? await self.diskCache.retrieveThumbnail(for: url, at: 0, quality: .standard) {
                                    movie.thumbnail = cached
                                   
                                        await self.memoryCache.store(
                                            image: cached,
                                            forKey: metadata,
                                            timestamp: 0,
                                            quality: .standard
                                    )
                                    }
                                }
                            
                            
                            videos.append(movie)
                        }
                        
                        continuation.resume(returning: videos)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            DispatchQueue.main.async {
                query.start()
            }
        }
    }
}
