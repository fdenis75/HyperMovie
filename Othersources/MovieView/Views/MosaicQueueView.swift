import SwiftUI
import OSLog

struct MosaicQueueView: View {
    @ObservedObject var coordinator: MosaicGenerationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Mosaic Generation Queue")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(role: .destructive) {
                    coordinator.cancelAllTasks()
                } label: {
                    Label("Cancel All", systemImage: "xmark.circle.fill")
                }
                .disabled(coordinator.queuedTasks.isEmpty && coordinator.activeTasksProgress.isEmpty)
            }
            .padding(.bottom, 8)
            
            // Concurrent tasks control
            HStack {
                Text("Maximum Concurrent Tasks:")
                Stepper(
                    value: $coordinator.maxConcurrentTasks,
                    in: 1...24
                ) {
                    Text("\(coordinator.maxConcurrentTasks)")
                        .monospacedDigit()
                        .frame(width: 30)
                }
            }
            .padding(.horizontal)
            
            // Statistics bar
            HStack(spacing: 16) {
                StatCard(
                    title: "Total",
                    value: "\(coordinator.activeTasksProgress.count)",
                    icon: "square.stack.3d.up"
                )
                
                StatCard(
                    title: "Processing",
                    value: "\(groupedTasks[.processing]?.count ?? 0)",
                    icon: "arrow.triangle.2.circlepath",
                    color: .blue
                )
                
                StatCard(
                    title: "Queued",
                    value: "\(groupedTasks[.queued]?.count ?? 0)",
                    icon: "clock",
                    color: .secondary
                )
                
                StatCard(
                    title: "Completed",
                    value: "\(groupedTasks[.completed]?.count ?? 0)",
                    icon: "checkmark.circle",
                    color: .green
                )
                
                if let rate = processingRate {
                    StatCard(
                        title: "Rate",
                        value: String(format: "%.1f/min", rate),
                        icon: "speedometer",
                        color: .orange
                    )
                }
            }
            .padding(.horizontal)
            
            // Tasks list
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Processing Tasks
                    if let processingTasks = groupedTasks[.processing], !processingTasks.isEmpty {
                        Section(header: sectionHeader("Processing", systemImage: "arrow.triangle.2.circlepath")) {
                            ForEach(processingTasks, id: \.key) { id, progress in
                                MosaicTaskProgressView(progress: progress)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            coordinator.cancelTask(id: id)
                                        } label: {
                                            Label("Cancel", systemImage: "xmark.circle")
                                        }
                                    }
                            }
                        }
                    }
                    
                    // Queued Tasks
                    if let queuedTasks = groupedTasks[.queued], !queuedTasks.isEmpty {
                        Section(header: sectionHeader("Queued", systemImage: "clock")) {
                            ForEach(queuedTasks, id: \.key) { id, progress in
                                MosaicTaskProgressView(progress: progress)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            coordinator.cancelTask(id: id)
                                        } label: {
                                            Label("Cancel", systemImage: "xmark.circle")
                                        }
                                    }
                            }
                        }
                    }
                    
                    // Completed Tasks
                    if let completedTasks = groupedTasks[.completed], !completedTasks.isEmpty {
                        Section(header: sectionHeader("Completed", systemImage: "checkmark.circle")) {
                            ForEach(completedTasks, id: \.key) { id, progress in
                                MosaicTaskProgressView(progress: progress)
                            }
                        }
                    }
                    
                    // Failed Tasks
                    if let failedTasks = groupedTasks[.failed(NSError(domain: "", code: 0))], !failedTasks.isEmpty {
                        Section(header: sectionHeader("Failed", systemImage: "exclamationmark.triangle")) {
                            ForEach(failedTasks, id: \.key) { id, progress in
                                MosaicTaskProgressView(progress: progress)
                            }
                        }
                    }
                    
                    // Cancelled Tasks
                    if let cancelledTasks = groupedTasks[.cancelled], !cancelledTasks.isEmpty {
                        Section(header: sectionHeader("Cancelled", systemImage: "xmark.circle")) {
                            ForEach(cancelledTasks, id: \.key) { id, progress in
                                MosaicTaskProgressView(progress: progress)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Footer
            HStack {
                if coordinator.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Processing queue...")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private var groupedTasks: [MosaicTaskStatus: [(key: UUID, value: MosaicTaskProgress)]] {
        Dictionary(grouping: coordinator.activeTasksProgress.sorted(by: { $0.value.startTime ?? Date() > $1.value.startTime ?? Date() })) { item in
            switch item.value.status {
            case .processing:
                return .processing
            case .queued:
                return .queued
            case .completed:
                return .completed
            case .failed:
                return .failed(NSError(domain: "", code: 0))
            case .cancelled:
                return .cancelled
            }
        }
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
            Divider()
        }
        .padding(.vertical, 8)
    }
    
    private var processingRate: Double? {
        let completedTasks = groupedTasks[.completed] ?? []
        guard !completedTasks.isEmpty else { return nil }
        
        // Get the earliest start time and latest end time
        let startTimes = completedTasks.compactMap { $0.value.startTime }
        let endTimes = completedTasks.compactMap { $0.value.endTime }
        
        guard let firstStart = startTimes.min(),
              let lastEnd = endTimes.max() else { return nil }
        
        let totalDuration = lastEnd.timeIntervalSince(firstStart) / 60 // Convert to minutes
        guard totalDuration > 0 else { return nil }
        
        return Double(completedTasks.count) / totalDuration
    }
}

struct MosaicTaskProgressView: View {
    let progress: MosaicTaskProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status and progress
            HStack {
                statusIcon
                    .foregroundColor(statusColor)
                
                Text(statusText)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                if case .processing = progress.status {
                    Text(String(format: "%.1f%%", progress.progress * 100))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                
                if let duration = progress.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Progress bar
            if case .processing = progress.status {
                ProgressView(value: progress.progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var statusIcon: Image {
        switch progress.status {
        case .queued:
            Image(systemName: "clock")
        case .processing:
            Image(systemName: "arrow.triangle.2.circlepath")
        case .completed:
            Image(systemName: "checkmark.circle")
        case .failed:
            Image(systemName: "exclamationmark.triangle")
        case .cancelled:
            Image(systemName: "xmark.circle")
        }
    }
    
    private var statusColor: Color {
        switch progress.status {
        case .queued:
            return .secondary
        case .processing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .secondary
        }
    }
    
    private var statusText: String {
        switch progress.status {
        case .queued:
            return "Queued"
        case .processing:
            return "Processing"
        case .completed:
            return "Completed"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            
            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
    }
} 