import SwiftUI
import UniformTypeIdentifiers

struct EnhancedDropZone: View {
    @ObservedObject var viewModel: MosaicViewModel
    @Binding var inputPaths: [(String, Int)]
    @Binding var inputType: MosaicViewModel.InputType
    @State private var isTargeted = false
    @State private var isHovered = false
    @State private var isLoading = false
    @State private var discoveredFiles = 0
    @State private var isShowingFilePicker = false
    
    var body: some View {
        ZStack {
            if inputPaths.isEmpty {
                EmptyStateView(isLoading: isLoading, discoveredFiles: discoveredFiles, selectFiles: selectFiles)
            } else {
                FileListView(inputPaths: $inputPaths, onRemove: removeFile)
            }
        }
        .frame(minHeight: 60)
        .background(viewModel.currentTheme.colors.surfaceBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? viewModel.currentTheme.colors.primary : Color.gray.opacity(0.3), lineWidth: isHovered ? 2 : 1)
        )
        .animation(.spring(), value: isHovered)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            Task {
                await handleDrop(providers: providers)
            }
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: .receivedURLsNotification)) { notification in
            guard let urls = notification.userInfo?["URLs"] as? [URL] else { return }
            Task {
                await handleDrop(providers: urls.map { NSItemProvider(item: $0 as NSSecureCoding, typeIdentifier: UTType.fileURL.identifier) })
            }
        }
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
    }
    private func handleDrop(providers: [NSItemProvider]) async -> Bool {
            isLoading = true
            discoveredFiles = 0
            viewModel.isFileDiscoveryCancelled = false
            
            var droppedPaths: [(path: String, count: Int)] = []
            
            for provider in providers {
                guard !viewModel.isFileDiscoveryCancelled else {
                    break
                }
                
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    do {
                        let item = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil)
                        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            let gen = PlaylistGenerator()
                            var count: Int = 0
                            do {
                                if url.pathExtension.lowercased() == "m3u8" {
                                    let content = try String(contentsOf: url, encoding: .utf8)
                                    count = content.components(separatedBy: .newlines)
                                        .filter { !$0.hasPrefix("#") && !$0.isEmpty }
                                        .count
                                    discoveredFiles = count
                                } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false {
                                    // Set up progress handler before finding files
                                    gen.setDiscoveryProgress { count in
                                        Task { @MainActor in
                                            discoveredFiles = count
                                        }
                                    }
                                    do {
                                        let files = try await gen.findVideoFiles(in: url)
                                        if !viewModel.isFileDiscoveryCancelled {
                                            count = files.count
                                        }
                                    } catch {
                                        count = 0
                                    }
                                }
                                if !viewModel.isFileDiscoveryCancelled {
                                    droppedPaths.append((path: url.path, count: count))
                                }
                                else {
                                    droppedPaths.append((path: url.path, count: 0))
                                }
                            } catch {
                                count = 0
                            }
                        }
                    } catch {
                        print("Error loading dropped item: \(error)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                withAnimation {
                    //if !viewModel.isFileDiscoveryCancelled {
                        self.inputPaths.append(contentsOf: droppedPaths.map { ($0.path, $0.count) })
                        self.updateInputType()
                    //}
                    self.isLoading = false
                }
            }
            
            return true
        }

    private func removeFile(at index: Int) {
        withAnimation {
            inputPaths.remove(at: index)
            updateInputType()
        }
    }
    
    private func clearAll() {
        withAnimation {
            inputPaths.removeAll()
            inputType = .files
        }
    }
    
    private func updateInputType() {
        if inputPaths.isEmpty {
            inputType = .files
        } else if inputPaths.count == 1 {
            let url = URL(fileURLWithPath: inputPaths[0].0)
            if url.hasDirectoryPath {
                inputType = .folder
            } else if url.pathExtension.lowercased() == "m3u8" {
                inputType = .m3u8
            } else {
                inputType = .files
            }
        } else {
            inputType = .files
        }
    }
    
    private func selectFiles() {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = true
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, UTType(filenameExtension: "m3u8")!]
            
            panel.begin { response in
                if response == .OK {
                    Task {
                        isLoading = true
                        discoveredFiles = 0
                        viewModel.isFileDiscoveryCancelled = false
                        
                        var droppedPaths: [(path: String, count: Int)] = []
                        
                        for url in panel.urls {
                            guard !viewModel.isFileDiscoveryCancelled else {
                                break
                            }
                            
                            let gen = PlaylistGenerator()
                            var count: Int = 0
                            
                            do {
                                if url.pathExtension.lowercased() == "m3u8" {
                                    let content = try String(contentsOf: url, encoding: .utf8)
                                    count = content.components(separatedBy: .newlines)
                                        .filter { !$0.hasPrefix("#") && !$0.isEmpty }
                                        .count
                                    await MainActor.run {
                                        discoveredFiles = count
                                    }
                                } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false {
                                    gen.setDiscoveryProgress { count in
                                        Task { @MainActor in
                                            discoveredFiles = count
                                        }
                                    }
                                    let files = try await gen.findVideoFiles(in: url)
                                    if !viewModel.isFileDiscoveryCancelled {
                                        count = files.count
                                    }
                                }
                                
                                if !viewModel.isFileDiscoveryCancelled {
                                    droppedPaths.append((path: url.path, count: count))
                                }
                            } catch {
                                print("Error processing selected file: \(error)")
                            }
                        }
                        
                        await MainActor.run {
                            withAnimation {
                                self.inputPaths.append(contentsOf: droppedPaths)
                                self.updateInputType()
                                self.isLoading = false
                            }
                        }
                    }
                }
            }
        }
    
    
} 
