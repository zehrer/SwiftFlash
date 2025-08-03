//
//  LabelAndStatus.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 03.08.25.
//


import SwiftUI

struct LabelAndStatus: View {
    let label: String
    let isReadOnly: Bool
    let labelWidth: CGFloat
    
    init(label: String, isReadOnly: Bool, labelWidth: CGFloat = 80) {
        self.label = label
        self.isReadOnly = isReadOnly
        self.labelWidth = labelWidth
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(InspectorFonts.label)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            HStack(spacing: 6) {
                Image(systemName: isReadOnly ? "lock.fill" : "lock.open.fill")
                    .foregroundColor(isReadOnly ? .red : .green)
                    .font(InspectorFonts.icon)
                
                Text(isReadOnly ? "Read-only" : "Writable")
                    .font(InspectorFonts.value)
            }
        }
    }
}