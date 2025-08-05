import SwiftUI

struct ImageInspectorView: View {
    let image: ImageFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Information Section
            InspectorSectionView(title: "Image Information") {
                // Name
                LabelAndText(
                    label: "Name",
                    value: image.displayName
                )
                
                // File Type
                LabelAndText(
                    label: "Type",
                    value: image.fileType.displayName
                )
                
                // Size
                LabelAndText(
                    label: "Size",
                    value: image.formattedSize
                )
            }
            
            // File Details Section
            InspectorSectionView(title: "File Details") {
                // File Path
                LabelAndText(
                    label: "Path",
                    value: image.path
                )
                
                // File Extension
                LabelAndText(
                    label: "Extension",
                    value: image.fileType.fileExtension
                )
            }
            
            // Compatibility Section
            InspectorSectionView(title: "Compatibility") {
                // Supported Drives
                LabelAndText(
                    label: "Min Drive Size",
                    value: image.formattedSize
                )
                
                // Format Info
                LabelAndText(
                    label: "Format",
                    value: image.fileType.displayName
                )
            }
            
            // Checksum Section
            InspectorSectionView(title: "Integrity Verification") {
                // Checksum Status
                LabelAndText(
                    label: "SHA256 Status",
                    value: image.checksumStatus
                )
                
                // Partition Scheme
                LabelAndText(
                    label: "Partition Scheme",
                    value: image.partitionSchemeDisplay
                )
                
                // Full Checksum (if available)
                if let checksum = image.sha256Checksum {
                    LabelAndText(
                        label: "Full Checksum",
                        value: checksum
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ImageInspectorView(
        image: ImageFile(
            name: "ubuntu-22.04-desktop-amd64.iso",
            path: "/Users/stephan/Downloads/ubuntu-22.04-desktop-amd64.iso",
            size: 4_500_000_000, // 4.5 GB
            fileType: .iso
        )
    )
    .frame(width: 250)
} 