//
//  EnhancedWebRenderer.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - Minimal Web Renderer

struct EnhancedWebRenderer: View {
    var urlString: String
    
    @State private var isLoading = false
    @State private var content = "Loading content..."
    
    var body: some View {
        VStack {
            Text("Rendering: \(urlString)")
                .font(.headline)
                .padding()
            
            if isLoading {
                ProgressView("Loading...")
            } else {
                ScrollView {
                    Text(content)
                        .padding()
                }
            }
        }
        .onAppear {
            simulateLoading()
        }
    }
    
    private func simulateLoading() {
        content = "Simple web content for: \(urlString)"
    }
}

#Preview {
    EnhancedWebRenderer(urlString: "https://example.com")
}
