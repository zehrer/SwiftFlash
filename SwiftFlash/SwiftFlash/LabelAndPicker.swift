//
//  LabelAndPicker.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 03.08.25.
//


import SwiftUI

struct LabelAndPicker: View {
    let label: String
    @Binding var selection: DeviceType
    let labelWidth: CGFloat
    
    init(label: String, selection: Binding<DeviceType>, labelWidth: CGFloat = 80) {
        self.label = label
        self._selection = selection
        self.labelWidth = labelWidth
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(InspectorFonts.label)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            HStack(spacing: 8) {
//                Image(systemName: selection.icon)
//                    .foregroundColor(.blue)
//                    .font(InspectorFonts.icon)
                
                Menu {
                    ForEach(DeviceType.allCases, id: \.self) { type in
                        Button(action: {
                            selection = type
                        }) {
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundColor(.blue)
                                    .font(InspectorFonts.icon)
                                Text(type.rawValue)
                                    .font(InspectorFonts.value)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selection.icon)
                            .foregroundColor(.blue)
                            .font(InspectorFonts.icon)
                        Text(selection.rawValue)
                            .font(InspectorFonts.value)
                        Image(systemName: "chevron.down")
                            .font(InspectorFonts.icon)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}