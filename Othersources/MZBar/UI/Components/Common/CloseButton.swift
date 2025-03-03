import SwiftUI

struct CloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("Close", systemImage: "xmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ActionButtonStyle(style: .secondary))
    }
} 