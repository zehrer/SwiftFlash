//
//  LabelAndText 2.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 03.08.25.
//


import SwiftUI

struct LabelAndText: View {
    let label: String
    let value: String
    let labelWidth: CGFloat
    
    init(label: String, value: String, labelWidth: CGFloat = 80) {
        self.label = label
        self.value = value
        self.labelWidth = labelWidth
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(InspectorFonts.label)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            Text(value)
                .font(InspectorFonts.value)
        }
    }
}