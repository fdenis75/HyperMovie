//
//  SegmentedPicker.swift
//  MZBar
//
//  Created by Francois on 31/12/2024.
//

import SwiftUI

struct SegmentedPicker<T: Hashable, Label: View>: View {
    @Binding var selection: T
    let options: [T]
    let label: (T) -> Label
    
    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.self) { option in
                label(option).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }
}
