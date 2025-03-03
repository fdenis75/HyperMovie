import SwiftUI

struct SettingsButton: View {
    var body: some View {
        Button {
            // Handle settings
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "gear")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                Text("Settings")
                    .font(.caption)
            }
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
} 