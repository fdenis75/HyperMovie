import SwiftUI

struct FileCompletedView: View {
    let result: ResultFiles
    let onShowInFinder: (URL) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Text("Processing complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: { onShowInFinder(result.output) }) {
                Image(systemName: "folder")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
} 