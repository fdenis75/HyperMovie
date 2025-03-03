import SwiftUI

struct SmartFoldersView: View {
    @StateObject private var smartFolderManager = SmartFolderManager.shared
    @ObservedObject var folderProcessor: FolderProcessor
    @ObservedObject var videoProcessor: VideoProcessor
    @StateObject private var mosaicCoordinator = MosaicGenerationCoordinator(videoProcessor: VideoProcessor())
    
    @State private var isShowingNewFolderSheet = false
    @State private var selectedFolder: SmartFolder?
    @State private var isProcessing = false
    @State private var showingMosaicQueue = false
    
    var body: some View {
        ZStack {
                if !folderProcessor.movies.isEmpty {
                    VStack {
                        HStack {
                            Button {
                                folderProcessor.movies.removeAll()
                                folderProcessor.smartFolderName = nil
                                folderProcessor.cancelProcessing()
                            } label: {
                                Label("Back to Smart Folders", systemImage: "chevron.left")
                            }
                            .padding()
                            Spacer()
                        }
                        
                        FolderView(
                            folderProcessor: folderProcessor,
                            videoProcessor: videoProcessor,
                            onMovieSelected: { url in
                                Task { try await videoProcessor.processVideo(url: url) }
                            },
                            smartFolderName: folderProcessor.smartFolderName
                        )
                    }
                } else {
        VStack {
            List {
                Section("Default Smart Folders") {
                    ForEach(smartFolderManager.defaultSmartFolders) { folder in
                        SmartFolderRow(folder: folder)
                            .contextMenu {
                                Button {
                                    selectedFolder = folder
                                    openSmartFolder(folder)
                                } label: {
                                    Label("Open", systemImage: "folder")
                                }
                                
                                Button {
                                    Task {
                                        await generateMosaics(for: folder)
                                    }
                                } label: {
                                    Label("Generate Mosaics", systemImage: "photo.stack")
                                }
                                
                                Button {
                                    let url = URL(fileURLWithPath: "/Volumes/Ext-6TB-2/Mosaics/\(folder.mosaicDirName)")
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                                } label: {
                                    Label("Show in Finder", systemImage: "folder.badge.plus")
                                }
                            }
                            .onTapGesture {
                                selectedFolder = folder
                                openSmartFolder(folder)
                            }
                    }
                }
                
                Section("User Smart Folders") {
                    ForEach(smartFolderManager.userSmartFolders) { folder in
                        SmartFolderRow(folder: folder)
                            .contextMenu {
                                Button {
                                    selectedFolder = folder
                                    openSmartFolder(folder)
                                } label: {
                                    Label("Open", systemImage: "folder")
                                }
                                
                                Button {
                                    Task {
                                        await generateMosaics(for: folder)
                                    }
                                } label: {
                                    Label("Generate Mosaics", systemImage: "photo.stack")
                                }
                                
                                Button {
                                    selectedFolder = folder
                                    isShowingNewFolderSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button {
                                    let url = URL(fileURLWithPath: "/Volumes/Ext-6TB-2/Mosaics/\(folder.mosaicDirName)")
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                                } label: {
                                    Label("Show in Finder", systemImage: "folder.badge.plus")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    smartFolderManager.removeSmartFolder(id: folder.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onTapGesture {
                                openSmartFolder(folder)
                            }
                    }
                    
                    if smartFolderManager.userSmartFolders.isEmpty {
                        Text("No user smart folders yet")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingNewFolderSheet = true
                    } label: {
                        Label("New Smart Folder", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingMosaicQueue.toggle()
                    } label: {
                        Label("Show Mosaic Queue", systemImage: "photo.stack")
                    }
                    .help("Show mosaic generation queue")
                }
            }
        }
        .overlay {
            if isProcessing {
                ProgressView("Scanning videos...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
            }
        }
        .sheet(isPresented: $isShowingNewFolderSheet) {
            SmartFolderEditor(folder: selectedFolder)
        }
        .sheet(isPresented: $showingMosaicQueue) {
            MosaicQueueView(coordinator: mosaicCoordinator)
        }
    }
        }
    }
    private func openSmartFolder(_ folder: SmartFolder) {
        isProcessing = true
        
        Task {
            do {
                let videos = try await smartFolderManager.getVideos(for: folder)
                await folderProcessor.setSmartFolderName(folder.mosaicDirName ?? folder.name.replacingOccurrences(of: " ", with: "_"))
                await folderProcessor.processVideos(from: videos.map(\.url))
            } catch {
                Logger.folderProcessing.error("Failed to get videos: \(error.localizedDescription)")
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func generateMosaics(for folder: SmartFolder) async {
        do {
            let videos = try await smartFolderManager.getVideos(for: folder)
            for video in videos {
                let task = MosaicGenerationTask(
                    id: UUID(),
                    url: video.url,
                    config: .default,
                    smartFolderName: folder.mosaicDirName ?? folder.name.replacingOccurrences(of: " ", with: "_")
                )
                mosaicCoordinator.addTask(task)
            }
        } catch {
            Logger.mosaicGeneration.error("Failed to get videos for mosaic generation: \(error.localizedDescription)")
        }
    }
}


struct SmartFolderRow: View {
    let folder: SmartFolder
    
    var body: some View {
        HStack {
            Label(folder.name, systemImage: "folder.fill.badge.gearshape")
            Spacer()
            Text(formatDate(folder.dateCreated))
                .foregroundStyle(.secondary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct SmartFolderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var smartFolderManager = SmartFolderManager.shared
    
    let folder: SmartFolder?
    @State private var name: String
    @State private var criteria: SmartFolderCriteria
    @State private var hasDateRange = false
    @State private var hasFileSize = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var nameFilter = ""
    @State private var folderNameFilter = ""
    @State private var minSize = 0
    @State private var maxSize = 0
    
    init(folder: SmartFolder?) {
        self.folder = folder
        _name = State(initialValue: folder?.name ?? "")
        _criteria = State(initialValue: folder?.criteria ?? SmartFolderCriteria())
        _hasDateRange = State(initialValue: folder?.criteria.dateRange != nil)
        _hasFileSize = State(initialValue: folder?.criteria.fileSize != nil)
        _startDate = State(initialValue: folder?.criteria.dateRange?.start ?? Date())
        _endDate = State(initialValue: folder?.criteria.dateRange?.end ?? Date())
        _nameFilter = State(initialValue: folder?.criteria.nameContains ?? "")
        _folderNameFilter = State(initialValue: folder?.criteria.folderNameContains ?? "")
        _minSize = State(initialValue: Int(folder?.criteria.fileSize?.min ?? 0) / 1_000_000)
        _maxSize = State(initialValue: Int(folder?.criteria.fileSize?.max ?? 0) / 1_000_000)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Smart Folder Name", text: $name)
                }
                
                Section("Criteria") {
                    Toggle("Date Range", isOn: $hasDateRange)
                    if hasDateRange {
                        DatePicker("Start Date", selection: $startDate)
                        DatePicker("End Date", selection: $endDate)
                    }
                    
                    TextField("File Name Contains", text: $nameFilter)
                    TextField("Folder Name Contains", text: $folderNameFilter)
                    
                    Toggle("File Size", isOn: $hasFileSize)
                    if hasFileSize {
                        HStack {
                            Text("Min:")
                            TextField("Min Size (MB)", value: $minSize, format: .number)
                        }
                        HStack {
                            Text("Max:")
                            TextField("Max Size (MB)", value: $maxSize, format: .number)
                        }
                    }
                }
            }
            .navigationTitle(folder == nil ? "New Smart Folder" : "Edit Smart Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedCriteria = SmartFolderCriteria(
                            dateRange: hasDateRange ? .init(start: startDate, end: endDate) : nil,
                            nameContains: nameFilter.isEmpty ? nil : nameFilter,
                            folderNameContains: folderNameFilter.isEmpty ? nil : folderNameFilter,
                            fileSize: hasFileSize ? .init(
                                min: Int64(minSize) * 1_000_000,
                                max: Int64(maxSize) * 1_000_000
                            ) : nil
                        )
                        
                        if let folder = folder {
                            var updatedFolder = folder
                            updatedFolder.name = name
                            updatedFolder.criteria = updatedCriteria
                            smartFolderManager.updateSmartFolder(updatedFolder)
                        } else {
                            smartFolderManager.addSmartFolder(name: name, criteria: updatedCriteria)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
} 
