import SwiftUI

struct FileListView: View {
    @Binding var inputPaths: [(String, Int)]
    let onRemove: (Int) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(Array(inputPaths.enumerated()), id: \.offset) { index, path in
                    FileRowView(
                        path: path.0,
                        count: path.1,
                        onRemove: { onRemove(index) }
                    )
                }
            }
            .padding(8)
        }
        .frame(maxHeight: 200)
    }
}

struct FileRowView: View {
    let path: String
    let count: Int
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // File Icon
            Image(systemName: "doc.fill")
                .foregroundStyle(.blue)
                .font(.system(size: 12))
            
            // File Path
            Text(path)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(size: 12))
            
            Spacer()
            
            // File Count
            if count > 0 {
                Text("\(count) files")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color(.quaternarySystemFill))
        .cornerRadius(6)
    }
} 