import SwiftUI

struct FileTypeIcon: View {
    let path: String
    
    private var iconName: String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "m3u", "m3u8":
            return "music.note.list"
        case "mp4", "mov", "m4v":
            return "play.rectangle.fill"
        case "":
            return "folder.fill"
        default:
            return "doc.fill"
        }
    }
    
    private var iconColor: Color {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "m3u", "m3u8":
            return .purple
        case "mp4", "mov", "m4v":
            return .blue
        case "":
            return .orange
        default:
            return .gray
        }
    }
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
            .font(.system(size: 12))
    }
} 