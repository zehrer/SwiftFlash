import SwiftUI

struct ImageHistoryView: View {
    let imageHistoryService: ImageHistoryService
    let onImageSelected: (ImageFile) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Recent Images")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !imageHistoryService.imageHistory.isEmpty {
                    Button("Clear") {
                        imageHistoryService.clearHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.controlBackgroundColor))
            
            // Content
            if imageHistoryService.imageHistory.isEmpty {
                emptyStateView
            } else {
                historyListView
            }
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No Recent Images")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Images you use will appear here for quick access")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(imageHistoryService.imageHistory) { item in
                    ImageHistoryRowView(
                        item: item,
                        onSelect: {
                            if let imageFile = imageHistoryService.loadImageFromHistory(item) {
                                onImageSelected(imageFile)
                            }
                        },
                        onRemove: {
                            imageHistoryService.removeFromHistory(item)
                        }
                    )
                    
                    if item.id != imageHistoryService.imageHistory.last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
        }
    }
}

// MARK: - ImageHistoryRowView

struct ImageHistoryRowView: View {
    let item: ImageHistoryItem
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // File Icon
            Image(systemName: fileTypeIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            // File Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(item.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.formattedLastUsed)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(0.6)
            .onHover { isHovered in
                // Could add hover effect here
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .background(Color.clear)
        .onHover { isHovered in
            // Could add hover effect here
        }
    }
    
    private var fileTypeIcon: String {
        switch item.fileType {
        case .iso:
            return "opticaldiscdrive"
        case .img:
            return "externaldrive"
        case .dmg:
            return "opticaldiscdrive"
        case .unknown:
            return "doc"
        }
    }
}

// MARK: - Preview

#Preview("ImageHistoryView - Empty") {
    ImageHistoryView(
        imageHistoryService: ImageHistoryService(),
        onImageSelected: { _ in }
    )
    .frame(width: 300, height: 400)
    .padding()
}

#Preview("ImageHistoryView - With Items") {
    let service = ImageHistoryService()
    
    ImageHistoryView(
        imageHistoryService: service,
        onImageSelected: { _ in }
    )
    .frame(width: 300, height: 400)
    .padding()
    .onAppear {
        // Add some demo items
        service.addToHistory(ImageFile(
            name: "Ubuntu 22.04 LTS.iso",
            path: "/Users/demo/Downloads/ubuntu-22.04.iso",
            size: 4_500_000_000,
            fileType: .iso
        ))
        service.addToHistory(ImageFile(
            name: "macOS Ventura.dmg",
            path: "/Users/demo/Downloads/macos-ventura.dmg",
            size: 12_000_000_000,
            fileType: .dmg
        ))
    }
} 