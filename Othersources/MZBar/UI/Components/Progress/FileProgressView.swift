import SwiftUI

struct FileProgressView: View {
    let progress: FileProgress
    let onCancel: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressIcon(progress: progress)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.filename)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                ProgressDetails(progress: progress)
            }
            
            Spacer()
            
            ProgressActions(
                progress: progress,
                onCancel: onCancel,
                onRetry: onRetry
            )
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProgressIcon: View {
    let progress: FileProgress
    
    var body: some View {
        Group {
            if progress.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if progress.isError {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            } else if progress.isCancelled {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            } else {
                ProgressCircle(value: progress.progress)
            }
        }
        .font(.title2)
    }
}

private struct ProgressCircle: View {
    let value: Double
    
    var body: some View {
        Circle()
            .trim(from: 0, to: value)
            .stroke(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 24, height: 24)
    }
}

private struct ProgressDetails: View {
    let progress: FileProgress
    
    var body: some View {
        Group {
            if progress.isError {
                Text(progress.errorMessage ?? "Error occurred")
                    .foregroundStyle(.red)
            } else if progress.isCancelled {
                Text("Cancelled")
                    .foregroundStyle(.secondary)
            } else if progress.isComplete {
                Text("Complete")
                    .foregroundStyle(.green)
            } else {
                Text(progress.stage)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }
}

private struct ProgressActions: View {
    let progress: FileProgress
    let onCancel: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        Group {
            if progress.isError {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.blue)
                }
            } else if !progress.isComplete && !progress.isCancelled {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
} 