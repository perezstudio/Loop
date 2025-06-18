//
//  EnhancedWebRenderer.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - Minimal Enhanced Web Renderer

struct EnhancedWebRenderer: View {
    var urlString: String
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading...")
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            } else {
                Text("Content for: \(urlString)")
                    .padding()
            }
        }
        .task {
            await loadContent()
        }
    }
    
    private func loadContent() async {
        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    EnhancedWebRenderer(urlString: "https://example.com")
}
