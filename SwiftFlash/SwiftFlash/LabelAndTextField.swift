//
//  LabelAndTextField.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 03.08.25.
//


import SwiftUI

struct LabelAndTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let labelWidth: CGFloat
    
    init(label: String, text: Binding<String>, placeholder: String, labelWidth: CGFloat = 80) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.labelWidth = labelWidth
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(InspectorFonts.label)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(InspectorFonts.value)
        }
    }
}