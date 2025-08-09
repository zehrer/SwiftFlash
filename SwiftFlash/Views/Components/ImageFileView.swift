//
//  ImageFileView.swift
//  SwiftFlash
//
//  Created by Stephan Zehrer on 27.07.25.
//

import SwiftUI

struct ImageFileView: View {
    let imageFile: ImageFile
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "doc.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Selected Image")
                    .font(.headline)
                
                Spacer()
                
                Button("Remove") {
                    onRemove()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            
            // File info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Name:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(imageFile.displayName)
                        .lineLimit(1)
                    Spacer()
                }
                
                HStack {
                    Text("Size:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(imageFile.formattedSize)
                    Spacer()
                }
                
                HStack {
                    Text("Type:")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(imageFile.fileType.displayName)
                    Spacer()
                }
                
                // Checksum (if available)
                if let checksum = imageFile.sha256Checksum {
                    HStack {
                        Text("Checksum:")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(checksum)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    let sampleImage = ImageFile(
        name: "raspberry-pi-os.img",
        path: "/path/to/file.img",
        size: 1024 * 1024 * 1024, // 1GB
        fileType: .img
    )
    
    ImageFileView(
        imageFile: sampleImage,
        onRemove: {}
    )
    .padding()
} 