//
//  DropZoneView.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var isTargeted: Bool
    let onDrop: (URL) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(isTargeted ? .blue : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            Text("Drop image file here")
                .font(.headline)
                .foregroundColor(isTargeted ? .blue : .primary)
            
            Text("Supports .img and .iso files")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isTargeted ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let error = error {
                    print("Error loading dropped file: \(error)")
                    return
                }
                
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                DispatchQueue.main.async {
                    onDrop(url)
                }
            }
            
            return true
        }
    }
}

#Preview {
    DropZoneView(isTargeted: .constant(false)) { url in
        print("Dropped: \(url)")
    }
} 