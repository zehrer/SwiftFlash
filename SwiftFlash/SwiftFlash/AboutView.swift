import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // App Icon
            Image("icon")
                .resizable()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
            
            // App Title
            VStack(spacing: 8) {
                Text("SwiftFlash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Simple. Safe. Swift.")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Description
            VStack(spacing: 12) {
                Text("A lightweight, native macOS application for flashing .img and .iso files to USB drives.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("Built with SwiftUI and Swift 6, SwiftFlash aims to be a minimal, safe, and open-source alternative to bulky tools like balenaEtcher or Raspberry Pi Imager.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Version and Copyright
            VStack(spacing: 4) {
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("© 2025 Stephan Zehrer. MIT License.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Close Button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 400, height: 500)
    }
}

#Preview {
    AboutView()
} 