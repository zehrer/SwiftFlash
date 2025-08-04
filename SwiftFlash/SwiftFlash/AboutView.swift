import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Red close button (macOS style)
            HStack {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 8)
                .padding(.top, 8)
                Spacer()
            }
            .frame(height: 28)
            
            HStack(alignment: .top, spacing: 24) {
                // App Logo (SwiftUI Vector)
                SwiftFlashVectorLogo()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    // App Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SwiftFlash")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Simple. Safe. Swift.")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A lightweight, native macOS application for flashing .img and .iso files to USB drives.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("Built with SwiftUI and Swift 6, SwiftFlash aims to be a minimal, safe, and open-source alternative to big other tools.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Version and Copyright
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version 0.1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("© 2025 Stephan Zehrer. MIT License.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(32)
            .frame(width: 600, height: 300)
            Spacer()
        }
    }
}

// MARK: - SwiftFlash Vector Logo View
struct SwiftFlashVectorLogo: View {
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            // Vector logo from SVG conversion
            MyIcon()
                .fill(Color.white)
                .padding(16)
        }
    }
}

#Preview {
    AboutView()
}
