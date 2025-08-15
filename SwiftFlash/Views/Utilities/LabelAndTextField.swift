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
    let onCommit: (() -> Void)?
    
    @State private var editingText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    init(label: String, text: Binding<String>, placeholder: String, labelWidth: CGFloat = 80, onCommit: (() -> Void)? = nil) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.labelWidth = labelWidth
        self.onCommit = onCommit
        self._editingText = State(initialValue: text.wrappedValue)
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(InspectorFonts.label)
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            
            TextField(placeholder, text: $editingText)
                .textFieldStyle(.roundedBorder)
                .font(InspectorFonts.value)
                .focused($isFocused)
                .onSubmit {
                    commitChanges()
                }
                .onTapGesture {
                    if !isEditing {
                        isEditing = true
                        editingText = text
                        isFocused = true
                    }
                }
                .onChange(of: text) { _, newValue in
                    if !isEditing {
                        editingText = newValue
                    }
                }
        }
    }
    
    private func commitChanges() {
        text = editingText
        isEditing = false
        isFocused = false
        onCommit?()
    }
}