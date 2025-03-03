import SwiftUI

struct PreviewSaveSettings: View {
    @Binding var savePath: String
    @Binding var useDefaultPath: Bool
    let defaultPath: String
    let onSavePathSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use default save location", isOn: $useDefaultPath)
                .help("When enabled, previews will be saved in a '0Previews' folder next to the original video")
            
            if !useDefaultPath {
                HStack {
                    TextField("Save Path", text: $savePath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(useDefaultPath)
                    
                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        
                        if panel.runModal() == .OK {
                            if let url = panel.url {
                                savePath = url.path
                                onSavePathSelected(url.path)
                            }
                        }
                    }
                    .disabled(useDefaultPath)
                }
            } else {
                Text("Saving to: \(defaultPath)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }
}

#Preview {
    PreviewSaveSettings(
        savePath: .constant("/Users/example/Movies"),
        useDefaultPath: .constant(true),
        defaultPath: "/Users/example/Movies/video/0Previews",
        onSavePathSelected: { _ in }
    )
} 