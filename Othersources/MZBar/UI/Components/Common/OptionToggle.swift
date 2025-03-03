import SwiftUI

struct OptionToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    init(_ title: String, icon: String, isOn: Binding<Bool>) {
        self.title = title
        self.icon = icon
        self._isOn = isOn
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon)
                .lineLimit(1)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
    }
} 