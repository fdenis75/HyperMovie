import SwiftUI
import HyperMovieCore
import HyperMovieModels
import HyperMovieServices
import UniformTypeIdentifiers
     

struct LibrarySidebar: View {
    @Binding var selection: HyperMovieModels.LibraryItem?
    @Environment(HyperMovieServices.AppState.self) private var appState
    @State private var showFolderPicker = false
    @State private var isLoading = false
    @State private var expandedFolders: Set<URL> = []
    @State private var concurrentThreads = 8
    @State private var showThreadsPopover = false
    
    // Progress tracking states
    @State private var totalFolders = 0
    @State private var processedFolders = 0
    @State private var currentFolderName = ""
    @State private var totalVideos = 0
    @State private var processedVideos = 0
    @State private var currentVideoName = ""
    @State private var processingStartTime = Date()
    @State private var processingRate: Double = 0
    @State private var skippedFiles = 0
    @State private var errorFiles = 0
    @State private var showDeleteConfirmation = false
    
    private let videoFinder = HyperMovieServices.VideoFinderService()
    private let updateTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProcessingProgressView(
                    totalFolders: totalFolders,
                    processedFolders: processedFolders,
                    currentFolderName: currentFolderName,
                    totalVideos: totalVideos,
                    processedVideos: processedVideos,
                    currentVideoName: currentVideoName,
                    concurrentOperations: Binding(get: { concurrentThreads }, set: { concurrentThreads = $0 }),
                    processingRate: processingRate,
                    skippedFiles: skippedFiles,
                    errorFiles: errorFiles
                )
            }
            
            List(selection: $selection) {
                Section("Library") {
                    ForEach(rootFolders) { volume in
                        FolderItemView(
                            item: volume, 
                            selection: $selection, 
                            expandedFolders: $expandedFolders,
                            handleFolderSelection: handleFolderSelection
                        )
                            /*.contextMenu {
                                Button(action: {
                                    Task {
                                        await rescanFolder(volume)
                                    }
                                }) {
                                    Label("Rescan Folder", systemImage: "arrow.clockwise")
                                }
                            }*/
                    }
                    
                    HMButton(
                        "Add Folder",
                        icon: "folder.badge.plus",
                        style: .tertiary,
                        size: .small
                    ) {
                        showFolderPicker = true
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("HyperMovie")
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleFolderSelection(result)
                }
            }
            .onReceive(updateTimer) { _ in
                if isLoading {
                    let elapsedTime = Date().timeIntervalSince(processingStartTime)
                    if elapsedTime > 0 {
                        processingRate = Double(processedVideos) / elapsedTime
                    }
                }
            }
        }
    }
    
    private var rootFolders: [HyperMovieModels.LibraryItem] {
        let volumesPrefix = "/Volumes/"
        var volumes: [String: HyperMovieModels.LibraryItem] = [:]
        
        for item in appState.library {
            guard let url = item.url,
                  url.path.hasPrefix(volumesPrefix) else { continue }
            
            let components = url.path.dropFirst(volumesPrefix.count).split(separator: "/")
            guard let volumeName = components.first else { continue }
            
            let volumePath = volumesPrefix + volumeName
            if volumes[volumePath] == nil {
                // Use existing library item if available
                if let existingVolume = appState.library.first(where: { $0.url?.path == volumePath }) {
                    volumes[volumePath] = existingVolume
                } else {
                    volumes[volumePath] = HyperMovieModels.LibraryItem(
                        name: String(volumeName),
                        type: .folder,
                        url: URL(fileURLWithPath: volumePath)
                    )
                }
            }
        }
        
        return Array(volumes.values).sorted { $0.name < $1.name }
    }
    
    public func handleFolderSelection(_ result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let rootFolderURL = urls.first else { return }
            var newVideos: [URL] = []

            print("📂 Starting folder selection handling for root URL: \(rootFolderURL.path)")
            
            await MainActor.run { 
                isLoading = true
                totalFolders = 0
                processedFolders = 0
                totalVideos = 0
                processedVideos = 0
                skippedFiles = 0
                errorFiles = 0
                currentFolderName = rootFolderURL.lastPathComponent
                currentVideoName = ""
                processingStartTime = Date()
                processingRate = 0
            }
            defer { Task { @MainActor in isLoading = false } }
            
            // Create library items for the entire path hierarchy
            let pathComponents = rootFolderURL.path.split(separator: "/").filter { !$0.isEmpty }
            var currentPath = ""
            
            print("🔍 Processing path components: \(pathComponents)")
            
            // First pass: Count total folders and videos
            let enumerator = FileManager.default.enumerator(
                at: rootFolderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            
            var foldersToProcess: [URL] = []
            var totalVideoCount = 0
            
            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    foldersToProcess.append(fileURL)
                } else if fileURL.pathExtension.lowercased() == "mp4" {
                    totalVideoCount += 1
                }
            }
            
            await MainActor.run {
                totalFolders = foldersToProcess.count + pathComponents.count
                totalVideos = totalVideoCount
            }
            
            // Create entries for each level of the path
            for component in pathComponents {
                currentPath += "/" + component
                let currentURL = URL(fileURLWithPath: currentPath)
                
                await MainActor.run {
                    currentFolderName = String(component)
                }
                
                if let existingFolder = appState.library.first(where: { $0.url == currentURL }) {
                    print("⚠️ Found existing folder: \(existingFolder.name) at \(currentPath)")
                }
                else {
                    let folderItem = HyperMovieModels.LibraryItem(
                        name: String(component),
                        type: .folder,
                        url: currentURL
                    )
                    
                    await MainActor.run {
                        appState.modelContext.insert(folderItem)
                        appState.library.append(folderItem)
                        processedFolders += 1
                    }
                }
            }
            
            // Sort folders by path to ensure parent folders are processed before children
            foldersToProcess.sort { $0.path.count < $1.path.count }
            
            // Process each folder
            for folderURL in foldersToProcess {
                await MainActor.run {
                    currentFolderName = folderURL.lastPathComponent
                }
                
                guard folderURL != rootFolderURL else { continue }
                
                if let existingFolder = appState.library.first(where: { $0.url == folderURL }) {
                    let videoURLs = try await videoFinder.findVideos(in: folderURL, recursive: false)
                    newVideos = videoURLs.filter { url in !appState.videos.contains(where: { $0.url == url }) }
                    
                    await MainActor.run {
                        skippedFiles += (videoURLs.count - newVideos.count)
                    }
                    
                    if !newVideos.isEmpty {
                        do {
                            let processedVideos = try await appState.videoProcessor.processMultiple(urls: newVideos)
                            await MainActor.run {
                                for video in processedVideos {
                                    appState.modelContext.insert(video)
                                    appState.videos.append(video)
                                    self.processedVideos += 1
                                }
                            }
                        } catch {
                            await MainActor.run {
                                errorFiles += 1
                            }
                            print("❌ Failed to process videos in folder \(folderURL.path): \(error.localizedDescription)")
                        }
                    }
                } else {
                    let folderItem = HyperMovieModels.LibraryItem(
                        name: folderURL.lastPathComponent,
                        type: .folder,
                        url: folderURL
                    )
                    
                    let videoURLs = try await videoFinder.findVideos(in: folderURL, recursive: false)
                    newVideos = videoURLs.filter { url in !appState.videos.contains(where: { $0.url == url }) }
                    
                    await MainActor.run {
                        appState.modelContext.insert(folderItem)
                        appState.library.append(folderItem)
                        processedFolders += 1
                    }
                    
                    if !newVideos.isEmpty {
                        do {
                            let processedVideos = try await appState.videoProcessor.processMultiple(urls: newVideos)
                            await MainActor.run {
                                for video in processedVideos {
                                    appState.modelContext.insert(video)
                                    appState.videos.append(video)
                                    self.processedVideos += 1
                                }
                            }
                        } catch {
                            await MainActor.run {
                                errorFiles += 1
                            }
                            print("❌ Failed to process videos in folder \(folderURL.path): \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // Update concurrent operations based on system metrics
            let metrics = await appState.videoProcessor.getCurrentMetrics()
            await MainActor.run {
                concurrentThreads = min(max(metrics.recommendedConcurrency, 2), 16)
            }
            
            // Process videos with adaptive concurrency
            if !newVideos.isEmpty {
                let processedVideos = try await appState.videoProcessor.processMultiple(
                    urls: newVideos,
                    minConcurrent: 2,
                    maxConcurrent: 16
                )
                await MainActor.run {
                    for video in processedVideos {
                        appState.modelContext.insert(video)
                        appState.videos.append(video)
                        self.processedVideos += 1
                        self.currentVideoName = video.title
                    }
                }
            }
            
            if let rootItem = appState.library.first(where: { $0.url == rootFolderURL }) {
                await MainActor.run {
                    selection = rootItem
                    expandedFolders.insert(rootFolderURL)
                }
            }
            
        } catch {
            print("❌ Error loading folder: \(error.localizedDescription)")
        }
    }
    
    private func rescanFolder(_ folder: HyperMovieModels.LibraryItem) async {
        guard let folderURL = folder.url else { return }
        
        // Reset progress tracking
        totalFolders = 0
        processedFolders = 0
        currentFolderName = ""
        totalVideos = 0
        processedVideos = 0
        currentVideoName = ""
        skippedFiles = 0
        errorFiles = 0
        processingStartTime = Date()
        processingRate = 0
        
        do {
            // Get all subfolders of the selected folder
            let enumerator = FileManager.default.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var foldersToProcess: [URL] = [folderURL]
            while let url = enumerator?.nextObject() as? URL {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    foldersToProcess.append(url)
                }
            }
            
            totalFolders = foldersToProcess.count
            
            // Process each folder
            for folderURL in foldersToProcess {
                await MainActor.run {
                    currentFolderName = folderURL.lastPathComponent
                }
                
                let videoURLs = try await videoFinder.findVideos(in: folderURL, recursive: false)
                let newVideos = videoURLs.filter { url in !appState.videos.contains(where: { $0.url == url }) }
                
                await MainActor.run {
                    skippedFiles += (videoURLs.count - newVideos.count)
                }
                
                if !newVideos.isEmpty {
                    do {
                        let processedVideos = try await appState.videoProcessor.processMultiple(urls: newVideos)
                        await MainActor.run {
                            for video in processedVideos {
                                appState.modelContext.insert(video)
                                appState.videos.append(video)
                                self.processedVideos += 1
                            }
                        }
                    } catch {
                        await MainActor.run {
                            errorFiles += 1
                        }
                        print("❌ Failed to process videos in folder \(folderURL.path): \(error.localizedDescription)")
                    }
                }
                
                await MainActor.run {
                    processedFolders += 1
                }
            }
            
            // Update concurrent operations based on system metrics
            let metrics = await appState.videoProcessor.getCurrentMetrics()
            await MainActor.run {
                concurrentThreads = min(max(metrics.recommendedConcurrency, 2), 16)
            }
            
        } catch {
            print("❌ Error rescanning folder: \(error.localizedDescription)")
        }
    }
}

struct FolderItemView: View {
    @Environment(HyperMovieServices.AppState.self) private var appState
    let item: HyperMovieModels.LibraryItem
    @Binding var selection: HyperMovieModels.LibraryItem?
    @Binding var expandedFolders: Set<URL>
    let handleFolderSelection: (Result<[URL], Error>) async -> Void
    @State private var isRescanning = false
    @State private var totalVideos = 0
    @State private var processedVideos = 0
    @State private var skippedFiles = 0
    @State private var errorFiles = 0
    @State private var processingStartTime = Date()
    @State private var processingRate: Double = 0
    @State private var concurrentThreads = 8
    @State private var totalFolders = 1
    @State private var processedFolders = 0
    @State private var currentFolderName = ""
    @State private var currentVideoName = ""
    @State private var showDeleteConfirmation = false
    
    private let videoFinder = HyperMovieServices.VideoFinderService()
    private let updateTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { item.url.map { expandedFolders.contains($0) } ?? false },
            set: { newValue, _ in
                guard let url = item.url else { return }
                if newValue {
                    expandedFolders.insert(url)
                } else {
                    expandedFolders.remove(url)
                }
            }
        )) {
            ForEach(immediateSubfolders) { subfolder in
                FolderItemView(
                    item: subfolder, 
                    selection: $selection, 
                    expandedFolders: $expandedFolders,
                    handleFolderSelection: handleFolderSelection
                )
                    .padding(.leading)
            }
        } label: {
            LibraryItemView(item: item)
                .tag(item)
                .contextMenu {
                    Button(action: {
                        Task {
                            await rescanFolder(item)
                        }
                    }) {
                        Label("Rescan Folder", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRescanning)
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete Folder Data", systemImage: "trash")
                    }
                }
                .confirmationDialog(
                    "Delete Folder Data",
                    isPresented: $showDeleteConfirmation,
                    actions: {
                        Button("Delete", role: .destructive) {
                            Task {
                                await deleteFolder(item)
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    },
                    message: {
                        Text("Are you sure you want to delete all data for this folder? This will remove all database entries, thumbnails, and cached data.")
                    }
                )
                .overlay {
                    if isRescanning {
                        ProcessingProgressView(
                            totalFolders: totalFolders,
                            processedFolders: processedFolders,
                            currentFolderName: item.name,
                            totalVideos: totalVideos,
                            processedVideos: processedVideos,
                            currentVideoName: "",
                            concurrentOperations: Binding(get: { concurrentThreads }, set: { concurrentThreads = $0 }),
                            processingRate: processingRate,
                            skippedFiles: skippedFiles,
                            errorFiles: errorFiles
                        )
                    }
                }
                .onReceive(updateTimer) { _ in
                    if isRescanning {
                        let elapsedTime = Date().timeIntervalSince(processingStartTime)
                        if elapsedTime > 0 {
                            processingRate = Double(processedVideos) / elapsedTime
                        }
                    }
                }
        }
    }
    
    private func rescanFolder(_ folder: HyperMovieModels.LibraryItem) async {
        guard let folderURL = folder.url else { return }
        
        // Reset progress tracking
        totalFolders = 0
        processedFolders = 0
        currentFolderName = ""
        totalVideos = 0
        processedVideos = 0
        currentVideoName = ""
        skippedFiles = 0
        errorFiles = 0
        processingStartTime = Date()
        processingRate = 0
        
        do {
            // Get all subfolders of the selected folder
            let enumerator = FileManager.default.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var foldersToProcess: [URL] = [folderURL]
            while let url = enumerator?.nextObject() as? URL {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    foldersToProcess.append(url)
                }
            }
            
            totalFolders = foldersToProcess.count
            
            // Process each folder
            for folderURL in foldersToProcess {
                await MainActor.run {
                    currentFolderName = folderURL.lastPathComponent
                }
                
                let videoURLs = try await videoFinder.findVideos(in: folderURL, recursive: false)
                let newVideos = videoURLs.filter { url in !appState.videos.contains(where: { $0.url == url }) }
                
                await MainActor.run {
                    skippedFiles += (videoURLs.count - newVideos.count)
                }
                
                if !newVideos.isEmpty {
                    do {
                        let processedVideos = try await appState.videoProcessor.processMultiple(urls: newVideos)
                        await MainActor.run {
                            for video in processedVideos {
                                appState.modelContext.insert(video)
                                appState.videos.append(video)
                                self.processedVideos += 1
                            }
                        }
                    } catch {
                        await MainActor.run {
                            errorFiles += 1
                        }
                        print("❌ Failed to process videos in folder \(folderURL.path): \(error.localizedDescription)")
                    }
                }
                
                await MainActor.run {
                    processedFolders += 1
                }
            }
            
            // Update concurrent operations based on system metrics
            let metrics = await appState.videoProcessor.getCurrentMetrics()
            await MainActor.run {
                concurrentThreads = min(max(metrics.recommendedConcurrency, 2), 16)
            }
            
        } catch {
            print("❌ Error rescanning folder: \(error.localizedDescription)")
        }
    }
    
    private func deleteFolder(_ folder: HyperMovieModels.LibraryItem) async {
        guard let folderURL = folder.url else { return }
        
        await MainActor.run {
            isRescanning = true
            processingStartTime = Date()
        }
        
        defer {
            Task { @MainActor in
                isRescanning = false
            }
        }
        
        let (itemsDeleted, error) = await videoFinder.deleteAllData(
            for: folderURL,
            modelContext: appState.modelContext
        ) { warningMessage in
            // We've already shown the confirmation dialog, so we can proceed
            return true
        }
        
        if let error {
            print("❌ Error deleting folder data: \(error.localizedDescription)")
        } else {
            await MainActor.run {
                // Remove the folder from the library
                if let index = appState.library.firstIndex(where: { $0.url == folderURL }) {
                    let folder = appState.library[index]
                    appState.modelContext.delete(folder)
                    appState.library.remove(at: index)
                }
                
                // Remove any subfolders
                let subfoldersToRemove = appState.library.filter { subfolder in
                    guard let subfolderURL = subfolder.url else { return false }
                    return subfolderURL.path.hasPrefix(folderURL.path)
                }
                
                for subfolder in subfoldersToRemove {
                    appState.modelContext.delete(subfolder)
                    if let index = appState.library.firstIndex(where: { $0.id == subfolder.id }) {
                        appState.library.remove(at: index)
                    }
                }
                
                try? appState.modelContext.save()
            }
            
            print("✅ Successfully deleted \(itemsDeleted) items from folder \(folderURL.path)")
        }
    }
    
    private var immediateSubfolders: [HyperMovieModels.LibraryItem] {
        guard let itemURL = item.url else { return [] }
        let itemComponents = itemURL.pathComponents
        
        return appState.library
            .filter { subItem in
                guard let subURL = subItem.url else { return false }
                let subComponents = subURL.pathComponents
                
                // Must have more components than parent
                guard subComponents.count > itemComponents.count else { return false }
                
                // Must match all parent components
                guard Array(subComponents.prefix(itemComponents.count)) == itemComponents else { return false }
                
                // Must be immediate child (only one more component)
                return subComponents.count == itemComponents.count + 1
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

struct LibraryItemView: View {
    let item: HyperMovieModels.LibraryItem
    @Environment(HyperMovieServices.AppState.self) private var appState
    
    private var videoCount: Int {
        guard let itemURL = item.url else { return 0 }
        return appState.videos.filter { video in
            video.url.path.hasPrefix(itemURL.path)
        }.count
    }
    
    var body: some View {
        Label {
            HStack {
                Text(item.name)
                    .lineLimit(1)
                if videoCount > 0 {
                    Text("(\(videoCount))")
                        .foregroundStyle(Theme.Colors.Text.secondary)
                        .font(Theme.Typography.caption1)
                }
            }
        } icon: {
            Image(systemName: item.type.icon)
        }
        .tag(item)
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        HMCard(elevation: Theme.Elevation.high) {
            VStack(spacing: Theme.Layout.Spacing.sm) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading Folder...")
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.Text.secondary)
            }
            .padding(Theme.Layout.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.UI.overlay)
    }
}



/*
extension UTType {
    static var folder: UTType {
        UTType(tag: "public.folder", tagClass: .filenameExtension, conformingTo: nil) ?? .folder
    } 
} 
*/

