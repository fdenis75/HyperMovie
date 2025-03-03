import SwiftUI

struct OverallProgressGrid: View {
    let title: String
    let progress: Double
    let icon: String
    let color: Color
    let fileCount: Int
    
    private var columns: Int {
        min(max(Int(ceil(sqrt(Double(fileCount)))), 8), 100)
    }
    
    private var rows: Int {
        min(max(Int(ceil(Double(fileCount) / Double(columns))), 4), 5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            GridProgressView(
                progress: progress,
                color: color,
                columns: columns,
                rows: rows
            )
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct GridProgressView: View {
    let progress: Double
    let color: Color
    let columns: Int
    let rows: Int
    
    var body: some View {
        GeometryReader { geometry in
            let itemSize = min(
                (geometry.size.width * 0.8 - CGFloat(columns - 1) * 4) / CGFloat(columns),
                (geometry.size.height * 0.8 - CGFloat(rows - 1) * 4) / CGFloat(rows)
            )
            
            VStack {
                GridContent(
                    itemSize: itemSize,
                    progress: progress,
                    color: color,
                    columns: columns,
                    rows: rows
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
            }
        }
        .frame(height: 120)
    }
}

private struct GridContent: View {
    let itemSize: CGFloat
    let progress: Double
    let color: Color
    let columns: Int
    let rows: Int
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(itemSize), spacing: 4), count: columns),
            spacing: 4
        ) {
            ForEach(0..<(columns * rows), id: \.self) { index in
                GridCell(
                    index: index,
                    totalCells: columns * rows,
                    progress: progress,
                    color: color,
                    itemSize: itemSize
                )
            }
        }
    }
}

private struct GridCell: View {
    let index: Int
    let totalCells: Int
    let progress: Double
    let color: Color
    let itemSize: CGFloat
    
    var body: some View {
        let cellProgress = Double(index + 1) / Double(totalCells)
        let isActive = cellProgress <= progress
        
        RoundedRectangle(cornerRadius: 4)
            .fill(isActive ?
                  LinearGradient(colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing) :
                    LinearGradient(colors: [color.opacity(0.2), color.opacity(0.2)],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .frame(width: itemSize, height: itemSize)
            .scaleEffect(isActive ? 1 : 0.65)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.3), value: isActive)
            .opacity(isActive ? progress : 0.5)
    }
} 