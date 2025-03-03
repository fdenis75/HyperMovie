import Foundation
import QuickLookUI
import SwiftUI

@available(macOS 14.0, *)
struct MosaicNavigatorView: View {
    @ObservedObject var viewModel: MosaicViewModel
    
    // Search and Filter State
    @State private var searchQuery = ""
    @State private var activeFilters: [FilterCategory: String] = [:]
    @State private var viewMode: ViewMode = .grid
    @State private var sortOrder: SortOrder = .dateDesc
    
    // UI State
    @State private var selectedMosaicId: Int64?
    @State private var selectedMosaic: MosaicEntry?
    @State private var showVersionsPanel = false
    @State private var gridColumns = 3
    @State private var showMigrationConfirmation = false
    @State private var isMigrating = false
    @State private var migrationError: String?
    @Environment(\.dismiss) private var dismiss
    
    // Add new state variables
    @State private var showDatePicker = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var scrollPosition: CGPoint = .zero
    
    // Add focus state at the top level
    @FocusState private var gridHasFocus: Bool
    
    // MARK: - Enums
    
    enum ViewMode: String {
        case grid = "Grid"
        case list = "List"
    }
    
    enum SortOrder: String, CaseIterable {
        case dateDesc = "Newest First"
        case dateAsc = "Oldest First"
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case sizeAsc = "Size (Small to Large)"
        case sizeDesc = "Size (Large to Small)"
        
        var comparator: (MosaicEntry, MosaicEntry) -> Bool {
            switch self {
            case .dateDesc:
                return { $0.creationDate > $1.creationDate }
            case .dateAsc:
                return { $0.creationDate < $1.creationDate }
            case .nameAsc:
                return { $0.movieFilePath.localizedStandardCompare($1.movieFilePath) == .orderedAscending }
            case .nameDesc:
                return { $0.movieFilePath.localizedStandardCompare($1.movieFilePath) == .orderedDescending }
            case .sizeAsc:
                return { $0.size.localizedStandardCompare($1.size) == .orderedAscending }
            case .sizeDesc:
                return { $0.size.localizedStandardCompare($1.size) == .orderedDescending }
            }
        }
    }
    
    // MARK: - Main View
    var body: some View {
        NavigationSplitView {
            FilterSidebarView(
                activeFilters: $activeFilters,
                availableFilters: viewModel.cachedFilterValues,
                startDate: $startDate,
                endDate: $endDate,
                showDatePicker: $showDatePicker,
                viewModel: viewModel
            )
            .frame(minWidth: 200, maxWidth: 500)
        } content: {
            if viewMode == .grid {
                MosaicGridView(
                    mosaics: viewModel.filteredMosaics,
                    columns: gridColumns,
                    selection: $selectedMosaicId,
                    selectedMosaic: $selectedMosaic
                )
            } else {
                MosaicListView(
                    mosaics: viewModel.filteredMosaics,
                    selection: $selectedMosaicId,
                    selectedMosaic: $selectedMosaic
                )
            }
        } detail: {
            if let selectedMosaic = selectedMosaic {
                MosaicDetailView(
                    mosaic: selectedMosaic,
                    versions: getVersions(for: selectedMosaic),
                    showVersions: $showVersionsPanel
                )
            }
        }.searchable(text: $searchQuery)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            SearchToolbar(
                searchText: $searchQuery,
                viewMode: $viewMode,
                sortOrder: $sortOrder,
                gridColumns: $gridColumns,
                showMigrationConfirmation: $showMigrationConfirmation,
                viewModel: viewModel
            ).frame(maxHeight: 100)
            
            if viewModel.isLoading {
                loadingView
            } else {
                gridOrListView
            }
        }
        .task {
            await initialDataLoad()
        }
    }
    
    private var gridOrListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: gridColumns),
                    spacing: 16
                ) {
                    if viewModel.filteredMosaics.isEmpty {
                        Text("No mosaics found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                    } else {
                        ForEach(viewModel.filteredMosaics, id: \.id) { mosaic in
                            NavigationLink(value: mosaic) {
                                MosaicGridItem(
                                    mosaic: mosaic,
                                    isSelected: mosaic.id == selectedMosaicId
                                )
                                .id(mosaic.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .focused($gridHasFocus)
            .onKeyPress(.leftArrow) {
                navigateGrid(direction: .left, proxy: proxy)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                navigateGrid(direction: .right, proxy: proxy)
                return .handled
            }
            .onKeyPress(.upArrow) {
                navigateGrid(direction: .up, proxy: proxy)
                return .handled
            }
            .onKeyPress(.downArrow) {
                navigateGrid(direction: .down, proxy: proxy)
                return .handled
            }
            .onAppear { gridHasFocus = true }
        }
        .onChange(of: searchQuery) { _ in
            viewModel.applyFilters(searchQuery: searchQuery, filters: activeFilters)
        }
        .onChange(of: activeFilters) { _ in
            viewModel.applyFilters(searchQuery: searchQuery, filters: activeFilters)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .frame(width: 300)
            Text("Loading...")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func initialDataLoad() async {
        print("🔄 Starting initial data load")
        await viewModel.fetchAllMosaics()
        print("✅ Initial data load complete")
    }
    
    private func navigateGrid(direction: NavigationDirection, proxy: ScrollViewProxy) {
        guard let currentId = selectedMosaicId,
              let currentIndex = viewModel.filteredMosaics.firstIndex(where: { $0.id == currentId })
        else { return }
        
        let totalItems = viewModel.filteredMosaics.count
        let itemsPerRow = gridColumns
        let rowCount = Int(ceil(Double(totalItems) / Double(itemsPerRow)))
        
        let newIndex: Int? = {
            switch direction {
            case .left:
                return currentIndex > 0 ? currentIndex - 1 : nil
            case .right:
                return currentIndex < totalItems - 1 ? currentIndex + 1 : nil
            case .up:
                let newIndex = currentIndex - itemsPerRow
                return newIndex >= 0 ? newIndex : nil
            case .down:
                let newIndex = currentIndex + itemsPerRow
                return newIndex < totalItems ? newIndex : nil
            }
        }()
        
        if let newIndex = newIndex, newIndex >= 0, newIndex < viewModel.filteredMosaics.count {
            let newId = viewModel.filteredMosaics[newIndex].id
            selectedMosaicId = newId
            selectedMosaic = viewModel.filteredMosaics[newIndex]
            withAnimation {
                proxy.scrollTo(newId, anchor: .center)
            }
        }
        
        // After selection update
        gridHasFocus = true
        DispatchQueue.main.async {
            gridHasFocus = true
        }
    }
    
    private enum NavigationDirection {
        case left, right, up, down
    }
    
    // MARK: - Helper Methods
    private func getVersions(for mosaic: MosaicEntry) -> [MosaicEntry] {
        viewModel.allMosaics.filter { entry in
            entry.movieFilePath == mosaic.movieFilePath && entry.id != mosaic.id
        }
    }
    
    private func migrateDatabaseAsync() async {
        isMigrating = true
        defer { isMigrating = false }
        
        do {
            try await viewModel.migrateDatabase()
            // Refresh the view after successful migration
            await viewModel.fetchMosaics()
        } catch {
            migrationError = error.localizedDescription
        }
    }
    
    private func shouldLoadMore(currentPosition: CGPoint) -> Bool {
        let threshold: CGFloat = 200
        let contentHeight = currentPosition.y
        let screenHeight = NSScreen.main?.frame.height ?? 1000
        let shouldLoad = contentHeight > screenHeight - threshold
        
        if shouldLoad {
            print("📜 Triggering load more at position: \(currentPosition.y)")
        }
        
        return shouldLoad
    }
    
    // MARK: - Supporting Views
    private struct SearchToolbar: View {
        @Binding var searchText: String
        @Binding var viewMode: MosaicNavigatorView.ViewMode
        @Binding var sortOrder: MosaicNavigatorView.SortOrder
        @Binding var gridColumns: Int
        @Binding var showMigrationConfirmation: Bool
        @ObservedObject var viewModel: MosaicViewModel
        var body: some View {
            VStack{
                HStack(spacing: 12) {
                    // Search field
                    
                    // View mode toggle
                    Picker("View Mode", selection: $viewMode) {
                        Image(systemName: "square.grid.3x3").tag(MosaicNavigatorView.ViewMode.grid)
                        Image(systemName: "list.bullet").tag(MosaicNavigatorView.ViewMode.list)
                    }
                    .pickerStyle(.inline)
                    .frame(width: 100)
                    
                    // Grid columns control (only show in grid mode)
                    if viewMode == .grid {
                        Stepper(value: $gridColumns, in: 1...6) {
                            Text("\(gridColumns) columns")
                        }
                        .frame(width: 120)
                    }
                    
                }
                
                // Sort order menu
                Menu {
                    ForEach(MosaicNavigatorView.SortOrder.allCases, id: \.rawValue) { order in
                        Button(action: { sortOrder = order }) {
                            HStack {
                                Text(order.rawValue)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                
                
                
                // Migration menu
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
    
    private struct FilterSidebarView: View {
        @Binding var activeFilters: [FilterCategory: String]
        let availableFilters: [FilterCategory: Set<String>]
        @Binding var startDate: Date
        @Binding var endDate: Date
        @Binding var showDatePicker: Bool
        @ObservedObject var viewModel: MosaicViewModel
        
        var body: some View {
            List {
                // Clear All Filters Button
                if !activeFilters.isEmpty {
                    Button(action: {
                        activeFilters.removeAll()
                        viewModel.selectedDateRange = nil
                        startDate = Date()
                        endDate = Date()
                    }) {
                        Label("Clear All Filters", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                
                // Movie Filters
                Section("Movie Properties") {
                    // Duration Filter
                    VStack(alignment: .leading) {
                        Text("Duration")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Picker("Duration", selection: $viewModel.selectedDurationFilter) {
                            Text("All").tag(DurationFilter.all)
                            Text("< 1 min").tag(DurationFilter.lessThanOneMin)
                            Text("< 5 min").tag(DurationFilter.lessThanFiveMin)
                            Text("< 10 min").tag(DurationFilter.lessThanTenMin)
                            Text("< 30 min").tag(DurationFilter.lessThanThirtyMin)
                            Text("< 1 hour").tag(DurationFilter.lessThanOneHour)
                            Text("> 1 hour").tag(DurationFilter.moreThanOneHour)
                        }
                        .pickerStyle(.automatic)
                        .onChange(of: viewModel.selectedDurationFilter) { _ in
                            Task {
                                await viewModel.refreshMosaics()
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    FilterGroup(
                        activeFilters: $activeFilters,
                        availableFilters: availableFilters,
                        categories: [.folder, .resolution, .codec, .videoType]
                    )
                    
                    // Movie Creation Date Range
                    DisclosureGroup("Creation Date Range") {
                        if viewModel.selectedDateRange != nil {
                            Button(action: {
                                viewModel.selectedDateRange = nil
                                startDate = Date()
                                endDate = Date()
                                Task {
                                    await viewModel.refreshMosaics()
                                }
                            }) {
                                Label("Clear Date Filter", systemImage: "xmark.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                        DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                        
                        Button("Apply Date Filter") {
                            viewModel.selectedDateRange = DateRange(
                                start: ISO8601DateFormatter().string(from: startDate),
                                end: ISO8601DateFormatter().string(from: endDate)
                            )
                            Task {
                                await viewModel.refreshMosaics()
                            }
                        }
                        .disabled(endDate < startDate)
                    }
                }
                
                // Mosaic Filters
                Section("Mosaic Properties") {
                    FilterGroup(
                        activeFilters: $activeFilters,
                        availableFilters: availableFilters,
                        categories: [.size, .density, .layout]
                    )
                }
                
                // Mosaic Batch Filters
                Section("Batch Properties") {
                    DisclosureGroup("Generation Date Range") {
                        if viewModel.selectedBatchDateRange != nil {
                            Button(action: {
                                viewModel.selectedBatchDateRange = nil
                                Task {
                                    await viewModel.refreshMosaics()
                                }
                            }) {
                                Label("Clear Batch Date Filter", systemImage: "xmark.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        DatePicker("From", selection: $viewModel.batchStartDate, displayedComponents: [.date])
                        DatePicker("To", selection: $viewModel.batchEndDate, displayedComponents: [.date])
                        
                        Button("Apply Batch Date Filter") {
                            viewModel.selectedBatchDateRange = DateRange(
                                start: ISO8601DateFormatter().string(from: viewModel.batchStartDate),
                                end: ISO8601DateFormatter().string(from: viewModel.batchEndDate)
                            )
                            Task {
                                await viewModel.refreshMosaics()
                            }
                        }
                        .disabled(viewModel.batchEndDate < viewModel.batchStartDate)
                    }
                }
            }
        }
    }
    
    private struct FilterGroup: View {
        @Binding var activeFilters: [FilterCategory: String]
        let availableFilters: [FilterCategory: Set<String>]
        let categories: [FilterCategory]
        
        var body: some View {
            ForEach(categories, id: \.rawValue) { category in
                if let values = availableFilters[category] {
                    DisclosureGroup(
                        content: {
                            if let activeValue = activeFilters[category] {
                                Button(action: {
                                    activeFilters.removeValue(forKey: category)
                                }) {
                                    Label("Clear \(category.rawValue) Filter", systemImage: "xmark.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            ForEach(Array(values).sorted(), id: \.self) { value in
                                HStack {
                                    Text(value)
                                    Spacer()
                                    if activeFilters[category] == value {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if activeFilters[category] == value {
                                        activeFilters.removeValue(forKey: category)
                                    } else {
                                        activeFilters[category] = value
                                    }
                                }
                            }
                        },
                        label: {
                            HStack {
                                Text(category.rawValue)
                                if activeFilters[category] != nil {
                                    Spacer()
                                    Text(activeFilters[category]!)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    )
                }
            }
        }
    }
    
    private struct MosaicGridView: View {
        let mosaics: [MosaicEntry]
        let columns: Int
        @Binding var selection: Int64?
        @Binding var selectedMosaic: MosaicEntry?
        @FocusState private var gridFocus: Bool
        
        var body: some View {
            ScrollViewReader { proxy in
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns),
                    spacing: 16
                ) {
                    ForEach(mosaics, id: \.id) { mosaic in
                        NavigationLink(value: mosaic) {
                            MosaicGridItem(
                                mosaic: mosaic,
                                isSelected: mosaic.id == selection
                            )
                            .id(mosaic.id)
                            .onTapGesture {
                                selection = mosaic.id
                                selectedMosaic = mosaic
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .focused($gridFocus)
                .onAppear { gridFocus = true }
                .onKeyPress(.leftArrow) { handleKey(.left, proxy); return .handled }
                .onKeyPress(.rightArrow) { handleKey(.right, proxy); return .handled }
                .onKeyPress(.upArrow) { handleKey(.up, proxy); return .handled }
                .onKeyPress(.downArrow) { handleKey(.down, proxy); return .handled }
            }
        }
        
        private func handleKey(_ direction: NavigationDirection, _ proxy: ScrollViewProxy) {
            // Original navigation logic here
            gridFocus = true
        }
    }
    
    private struct MosaicListView: View {
        let mosaics: [MosaicEntry]
        @Binding var selection: Int64?
        @Binding var selectedMosaic: MosaicEntry?
        
        var body: some View {
            ScrollViewReader { proxy in
                List(mosaics, id: \.id) { mosaic in
                    NavigationLink(value: mosaic) {
                        MosaicListItem(mosaic: mosaic)
                            .id(mosaic.id)
                            .onTapGesture {
                                selection = mosaic.id
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private struct MosaicListItem: View {
        let mosaic: MosaicEntry
        @State private var isImageLoaded = false
        @State private var isVisible = false
        
        var body: some View {
            LazyHStack(spacing: 16) {
                // Thumbnail
                Group {
                    if !isImageLoaded {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: 120)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay {
                                ProgressView()
                            }
                    }
                    if isVisible {
                        AsyncImage(url: URL(fileURLWithPath: mosaic.mosaicFilePath)) { phase in
                            switch phase {
                            case .empty:
                                EmptyView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120)
                                    .onAppear { isImageLoaded = true }
                            case .failure(_):
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.red)
                                    .onAppear { isImageLoaded = true }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .opacity(isImageLoaded ? 1 : 0)
                    }
                }
                .cornerRadius(6)
                .onAppear { isVisible = true }
                .onDisappear {
                    isVisible = false
                    isImageLoaded = false
                }
                
                // Metadata
                LazyVStack(alignment: .leading, spacing: 8) {
                    Text(URL(fileURLWithPath: mosaic.movieFilePath).lastPathComponent)
                        .font(.headline)
                    
                    Text(mosaic.folderHierarchy)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        Label(mosaic.size, systemImage: "ruler")
                        Label(mosaic.density, systemImage: "chart.bar")
                        if let layout = mosaic.layout {
                            Label(layout, systemImage: "square.grid.3x3")
                        }
                        Label(mosaic.resolution, systemImage: "arrow.up.left.and.arrow.down.right")
                        Label(mosaic.formattedDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }
    
    private struct MosaicDetailView: View {
        let mosaic: MosaicEntry
        let versions: [MosaicEntry]
        @Binding var showVersions: Bool
        
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Main mosaic image
                    AsyncImage(url: URL(fileURLWithPath: mosaic.mosaicFilePath)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaledToFit()
                            .containerRelativeFrame(.vertical) { size, axis in
                                size * 0.9
                            }
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .overlay {
                                ProgressView()
                            }
                    }
                    .cornerRadius(12)
                    HStack(spacing: 20) {
                        Button(action: {
                            if let url = URL(
                                string: "iina://open?url=" + mosaic.movieFilePath.addingPercentEncoding(
                                    withAllowedCharacters: .urlQueryAllowed)!)
                            {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Open in IINA", systemImage: "play.circle.fill")
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            NSWorkspace.shared.selectFile(mosaic.movieFilePath, inFileViewerRootedAtPath: "")
                        }) {
                            Label("Show in Finder", systemImage: "folder.circle.fill")
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    // Metadata section
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // File information
                        GroupBox("File Information") {
                            DetailRow("File Name", URL(fileURLWithPath: mosaic.movieFilePath).lastPathComponent)
                            DetailRow("Location", URL(fileURLWithPath: mosaic.movieFilePath).deletingLastPathComponent().path())
                            DetailRow("Creation Date", mosaic.creationDate)
                        }
                        
                        // Video information
                        GroupBox("Video Information") {
                            DetailRow("Resolution", mosaic.resolution)
                            DetailRow("Duration", mosaic.formattedDuration)
                            DetailRow("Codec", mosaic.codec)
                            DetailRow("Type", mosaic.videoType)
                        }
                        
                        // Mosaic settings
                        GroupBox("Mosaic Settings") {
                            DetailRow("Size", mosaic.size)
                            DetailRow("Density", mosaic.density)
                            if let layout = mosaic.layout {
                                DetailRow("Layout", layout)
                            }
                        }
                        
                        // Versions section
                        if !versions.isEmpty {
                            GroupBox {
                                DisclosureGroup(
                                    isExpanded: $showVersions,
                                    content: {
                                        VersionsList(versions: versions)
                                    },
                                    label: {
                                        Label("\(versions.count) other versions", systemImage: "clock.arrow.circlepath")
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private struct DetailRow: View {
        let label: String
        let value: String
        
        init(_ label: String, _ value: String) {
            self.label = label
            self.value = value
        }
        
        var body: some View {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
            }
            .padding(.vertical, 4)
        }
    }
    
    private struct VersionsList: View {
        let versions: [MosaicEntry]
        
        var body: some View {
            LazyVStack(spacing: 12) {
                ForEach(versions, id: \.id) { version in
                    LazyHStack {
                        AsyncImage(url: URL(fileURLWithPath: version.mosaicFilePath)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 60)
                        } placeholder: {
                            Rectangle()
                                .fill(.quaternary)
                                .frame(height: 60)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .overlay {
                                    ProgressView()
                                }
                        }
                        .cornerRadius(4)
                        
                        LazyVStack(alignment: .leading) {
                            Text("Size: \(version.size)")
                            Text("Density: \(version.density)")
                            if let layout = version.layout {
                                Text("Layout: \(layout)")
                            }
                        }
                        .font(.caption)
                        
                        Spacer()
                        
                        Text(version.creationDate)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private struct PlaceholderView: View {
        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Select a mosaic to view details")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private struct EnlargedMosaicView: View {
        let mosaic: MosaicEntry
        let onDismiss: () -> Void
        @State private var previewItem: URL? = nil
        @Environment(\.dismiss) private var dismiss
        
        var body: some View {
            VStack(spacing: 16) {
                // QuickLook preview
                // QuickLookPreview(url: URL(fileURLWithPath: mosaic.mosaicFilePath))
                //     .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let image = NSImage(contentsOf: URL(fileURLWithPath: mosaic.mosaicFilePath)) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: {
                        if let url = URL(
                            string: "iina://open?url=" + mosaic.movieFilePath.addingPercentEncoding(
                                withAllowedCharacters: .urlQueryAllowed)!)
                        {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("Open in IINA", systemImage: "play.circle.fill")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NSWorkspace.shared.selectFile(mosaic.movieFilePath, inFileViewerRootedAtPath: "")
                    }) {
                        Label("Show in Finder", systemImage: "folder.circle.fill")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
            .navigationTitle("Mosaic Preview")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { onDismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
    
    private struct QuickLookPreview: NSViewRepresentable {
        let url: URL
        
        func makeNSView(context: Context) -> QLPreviewView {
            guard let preview = QLPreviewView(frame: .zero, style: .normal) else {
                fatalError("Failed to create QLPreviewView")
            }
            preview.autostarts = true
            preview.previewItem = url as QLPreviewItem
            return preview
        }
        
        func updateNSView(_ nsView: QLPreviewView, context: Context) {
            nsView.previewItem = url as QLPreviewItem
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = MosaicViewModel()
    return MosaicNavigatorView(viewModel: viewModel)
}
