import SwiftUI

struct EmptyStateView: View {
    let isLoading: Bool
    let discoveredFiles: Int
    let selectFiles: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                LoadingStateView(discoveredFiles: discoveredFiles)
            } else {
                DefaultEmptyState(selectFiles: selectFiles)
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity)
        .padding(32)
    }
}

private struct LoadingStateView: View {
    let discoveredFiles: Int
    @State private var isLoadingCancelled = false
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Counting files... (\(discoveredFiles) found)")
                .foregroundColor(.secondary)
            
            Button(action: {
                isLoadingCancelled = true
                // Notify view model to cancel file discovery
            }) {
                Text("Cancel")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

private struct DefaultEmptyState: View {
    let selectFiles: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 32))
            
            Text("Drop files here")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("Videos, Folders, or M3U8 Playlists")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: selectFiles) {
                Label("Select Files", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .padding(.top, 8)
        }
    }
} 