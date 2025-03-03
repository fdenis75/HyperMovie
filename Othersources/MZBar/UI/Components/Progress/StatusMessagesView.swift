import SwiftUI

struct StatusMessagesView: View {
    let messages: [StatusMessage]
    @State private var previousMessages: [StatusMessage] = []
    @Namespace private var bottomID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(messages) { message in
                StatusMessageRow(message: message)
            }
        }
        .onChange(of: messages) { oldValue, newValue in
            if !newValue.isEmpty {
                scrollToBottom()
            }
        }
    }
    
    private func scrollToBottom() {
        withAnimation {
            bottomID
        }
    }
}

struct StatusMessage: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let text: String
    let type: MessageType
    
    enum MessageType {
        case info, success, warning, error
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    static func == (lhs: StatusMessage, rhs: StatusMessage) -> Bool {
        lhs.id == rhs.id
    }
}

private struct StatusMessageRow: View {
    let message: StatusMessage
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.icon)
                .foregroundStyle(message.type.color)
            
            Text(message.text)
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .transition(.opacity.combined(with: .slide))
    }
} 