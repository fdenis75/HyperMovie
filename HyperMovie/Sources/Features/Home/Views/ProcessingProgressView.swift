import SwiftUI
 //import DesignSystem

struct ProcessingProgressView: View {
    let totalFolders: Int
    let processedFolders: Int
    let currentFolderName: String
    let totalVideos: Int
    let processedVideos: Int
    let currentVideoName: String
    @Binding var concurrentOperations: Int
    let processingRate: Double // Files per second
    let skippedFiles: Int
    let errorFiles: Int
    @State private var showThreadsPopover = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var folderProgress: Double {
        guard totalFolders > 0 else { return 0 }
        return Double(processedFolders) / Double(totalFolders)
    }
    
    private var videoProgress: Double {
        guard totalVideos > 0 else { return 0 }
        return Double(processedVideos) / Double(totalVideos)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.Spacing.sm) {
            Text("Processing Library")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.Text.primary)
            
            // Performance Metrics
            HStack(spacing: Theme.Layout.Spacing.lg) {
                // Concurrent Operations Gauge
                VStack {
                    Gauge(value: Double(concurrentOperations), in: 2...16) {
                        Image(systemName: "cpu")
                            .foregroundStyle(Theme.Colors.Text.secondary)
                    } currentValueLabel: {
                        Text("\(concurrentOperations)")
                            .font(Theme.Typography.caption1)
                            .foregroundStyle(Theme.Colors.Text.primary)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(Theme.Colors.accent)
                    .onTapGesture {
                        showThreadsPopover = true
                    }
                    
                    Text("Concurrent Tasks")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                }
                .popover(isPresented: $showThreadsPopover) {
                    VStack(spacing: Theme.Layout.Spacing.sm) {
                        Text("Configure Processing Threads")
                            .font(Theme.Typography.headline)
                            .padding(.bottom, Theme.Layout.Spacing.xs)
                        
                        Stepper(value: $concurrentOperations, in: 2...16) {
                            Text("\(concurrentOperations) threads")
                                .font(Theme.Typography.body)
                        }
                        .frame(width: 200)
                        
                        Text("Min: 2, Max: 16")
                            .font(Theme.Typography.caption1)
                            .foregroundStyle(Theme.Colors.Text.secondary)
                    }
                    .padding()
                }
                
                // Processing Rate Gauge
                VStack {
                    Gauge(value: min(processingRate / 10.0, 1.0)) {
                        Image(systemName: "speedometer")
                            .foregroundStyle(Theme.Colors.Text.secondary)
                    } currentValueLabel: {
                        Text(String(format: "%.1f/s", processingRate))
                            .font(Theme.Typography.caption1)
                            .foregroundStyle(Theme.Colors.Text.primary)
                    }
                    .gaugeStyle(.accessoryCircular)
                    .tint(Theme.Colors.accent)
                    
                    Text("Processing Rate")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                }
                
                // Status Indicators
                VStack(alignment: .leading, spacing: Theme.Layout.Spacing.xxs) {
                    HStack(spacing: Theme.Layout.Spacing.xs) {
                        Image(systemName: "arrow.forward.circle")
                            .foregroundStyle(Theme.Colors.Text.secondary)
                        Text("\(skippedFiles) skipped")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(Theme.Colors.Text.secondary)
                    }
                    
                    HStack(spacing: Theme.Layout.Spacing.xs) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.red)
                        Text("\(errorFiles) errors")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.vertical, Theme.Layout.Spacing.sm)
            
            // Folder Progress
            VStack(alignment: .leading, spacing: Theme.Layout.Spacing.xxs) {
                HStack {
                    Text("Folders")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                    Spacer()
                    Text("\(processedFolders)/\(totalFolders)")
                        .font(Theme.Typography.caption1)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                }
                
                ProgressView(value: folderProgress)
                    .tint(Theme.Colors.accent)
                
                Text(currentFolderName)
                    .font(Theme.Typography.caption1)
                    .foregroundStyle(Theme.Colors.Text.secondary)
                    .lineLimit(1)
            }
            
            // Video Progress
            VStack(alignment: .leading, spacing: Theme.Layout.Spacing.xxs) {
                HStack {
                    Text("Videos")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                    Spacer()
                    Text("\(processedVideos)/\(totalVideos)")
                        .font(Theme.Typography.caption1)
                        .foregroundStyle(Theme.Colors.Text.secondary)
                }
                
                ProgressView(value: videoProgress)
                    .tint(Theme.Colors.accent)
                
                Text(currentVideoName)
                    .font(Theme.Typography.caption1)
                    .foregroundStyle(Theme.Colors.Text.secondary)
                    .lineLimit(1)
            }
        }
        .padding(Theme.Layout.Spacing.md)
        .background(.ultraThinMaterial)
    }
} 
