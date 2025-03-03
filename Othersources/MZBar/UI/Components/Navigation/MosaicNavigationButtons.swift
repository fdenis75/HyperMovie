import SwiftUI

struct MosaicNavigationButtons: View {
    let hasPreviousMosaic: Bool
    let hasNextMosaic: Bool
    let navigateToPrevious: () -> Void
    let navigateToNext: () -> Void
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack {
            Button(action: navigateToPrevious) {
                Label("Previous", systemImage: "chevron.left.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title)
            }
            .buttonStyle(.plain)
            .disabled(!hasPreviousMosaic)
            .keyboardShortcut(.leftArrow, modifiers: [])
            
            Spacer()
            
            Button(action: navigateToNext) {
                Label("Next", systemImage: "chevron.right.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title)
            }
            .buttonStyle(.plain)
            .disabled(!hasNextMosaic)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .padding(.horizontal)
    }
} 