import SwiftUI

struct PreviewQueueView: View {
    @ObservedObject var coordinator: PreviewGenerationCoordinator
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Preview Generation Queue")
                .font(.headline)
                .padding()
            
            List {
                ForEach(coordinator.tasks) { task in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(task.videoURL.lastPathComponent)
                                .fontWeight(.medium)
                            Text(task.status.displayString)
                                .foregroundColor(task.status.color)
                            Text("Queued: \(task.timestamp, style: .time)")
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        if task.status == .inProgress {
                            ProgressView()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
} 