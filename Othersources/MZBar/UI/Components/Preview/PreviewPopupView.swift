import SwiftUI

struct PreviewPopupView: View {
    let url: URL
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .padding()
            }
            
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 800, maxHeight: 600)
            } else {
                Text("Unable to load preview")
                    .foregroundStyle(.secondary)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .frame(maxWidth: .infinity, maxHeight: 2000)
    }
} 