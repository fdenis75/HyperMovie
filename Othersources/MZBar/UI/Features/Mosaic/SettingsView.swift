import SwiftUI
import Foundation


struct SettingsView: View {
    @Binding var cleanupMethod: Int
    @Binding var missingMosaics: [(MosaicEntry, String)]
    @Binding var missingVideos: [(MosaicEntry, String)]
    @Binding var updateStats: [String: Int]
    @Binding var isLoading: Bool
    let onCleanup: () -> Void
    let onScan: () -> Void
    let onUpdateDates: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Cleanup Method", selection: $cleanupMethod) {
                Text("Remove Missing Files").tag(0)
                Text("Remove All").tag(1)
            }
            .pickerStyle(.segmented)
            
            HStack {
                Button("Scan for Missing Files", action: onScan)
                    .disabled(isLoading)
                Button("Cleanup Database", action: onCleanup)
                    .disabled(isLoading || (missingMosaics.isEmpty && missingVideos.isEmpty))
                Button("Update Creation Dates", action: onUpdateDates)
                    .disabled(isLoading)
            }
            
            if !missingMosaics.isEmpty {
                Text("Missing Mosaics: \(missingMosaics.count)")
                    .foregroundStyle(.red)
            }
            
            if !missingVideos.isEmpty {
                Text("Missing Videos: \(missingVideos.count)")
                    .foregroundStyle(.red)
            }
            
            if !updateStats.isEmpty {
                Text("Updated: \(updateStats["updated"] ?? 0)")
                Text("Removed: \(updateStats["removed"] ?? 0)")
            }
        }
        .padding()
    }
} 