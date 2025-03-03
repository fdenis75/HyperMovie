//
//  FormatPicker.swift
//  MZBar
//
//  Created by Francois on 30/12/2024.
//

import SwiftUI

// MARK: - Format Picker
struct FormatPicker: View {
    @Binding var selection: String
    
    struct FormatOption: Identifiable {
        let id = UUID()
        let value: String
        let name: String
        let icon: String
        let description: String
    }
    
    private let formats: [FormatOption] = [
        .init(value: "heic", name: "HEIC", icon: "photo.fill",
              description: "High efficiency, smaller file size"),
        .init(value: "jpeg", name: "JPEG", icon: "photo.circle.fill",
              description: "Best compatibility"),
        .init(value: "png", name: "PNG", icon: "photo.stack.fill",
              description: "Lossless quality")
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Format Selection
            HStack(spacing: 2) {
                ForEach(formats) { format in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selection = format.value
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: format.icon)
                                .font(.headline)
                            Text(format.name)
                                .font(.caption2.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection == format.value ? .blue : Color.clear)
                        .foregroundStyle(selection == format.value ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(4)
            .background(Color(.quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Format Description
            if let selectedFormat = formats.first(where: { $0.value == selection }) {
                Text(selectedFormat.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Duration Picker
struct DurationPicker: View {
    @Binding var selection: Int
    
    let durations = [
        (0, "No limit"),
        (10, "10s"),
        (30, "30s"),
        (60, "1m"),
        (300, "5m"),
        (600, "10m")
    ]
    
    var body: some View {
        Picker("Duration", selection: $selection) {
            ForEach(durations, id: \.0) { duration, label in
                Text(label)
                    .tag(duration)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
    }
}
