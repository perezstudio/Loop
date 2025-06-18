//
//  WebCoreTest.swift
//  Loop - WebCore Engine Test
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - WebCore Test

class WebCoreTest {
    
    static func testBasicRendering() async {
        print("🧪 Testing WebCore Engine...")
        
        // Create WebCore engine
        let config = WebCoreConfiguration()
        let engine = WebCoreEngine(configuration: config)
        
        // Test HTML
        let testHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { margin: 20px; font-family: Arial, sans-serif; }
                h1 { color: blue; font-size: 24px; margin-bottom: 16px; }
                p { color: black; margin: 8px 0; }
                .highlight { background-color: yellow; padding: 4px; }
                #main { border: 2px solid red; padding: 10px; }
            </style>
        </head>
        <body>
            <div id="main">
                <h1>WebCore Test Page</h1>
                <p>This is a test paragraph with <span class="highlight">highlighted text</span>.</p>
                <p>Another paragraph to test layout.</p>
                <ul>
                    <li>List item 1</li>
                    <li>List item 2</li>
                </ul>
            </div>
        </body>
        </html>
        """
        
        // Set viewport
        engine.setViewport(CGSize(width: 800, height: 600))
        
        // Load HTML
        engine.loadHTML(testHTML)
        
        // Wait for loading to complete
        await waitForLoading(engine)
        
        // Test rendering
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: 800,
            height: 600,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            print("❌ Failed to create test context")
            return
        }
        
        // Flip coordinate system
        context.translateBy(x: 0, y: 600)
        context.scaleBy(x: 1, y: -1)
        
        // Render
        let success = engine.render(to: context)
        
        if success {
            print("✅ WebCore Engine test completed successfully!")
            
            // Print debug info
            engine.printDebugInfo()
            
            // Create image for verification
            if let image = engine.createImage() {
                print("🖼️ Generated image: \(image.width)x\(image.height)")
                
                // In a real app, you would save this image or display it
                // For testing, we just verify it was created
            }
        } else {
            print("❌ WebCore Engine test failed during rendering")
        }
    }
    
    private static func waitForLoading(_ engine: WebCoreEngine) async {
        // Simple polling - in real implementation would use proper async/await
        for _ in 0..<50 { // Max 5 seconds
            if !engine.isLoading {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    static func testFlexboxLayout() async {
        print("🧪 Testing Flexbox Layout...")
        
        let config = WebCoreConfiguration()
        let engine = WebCoreEngine(configuration: config)
        
        let flexHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                .container {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    height: 200px;
                    border: 1px solid black;
                    padding: 20px;
                }
                .item {
                    background-color: lightblue;
                    padding: 10px;
                    border: 1px solid blue;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="item">Item 1</div>
                <div class="item">Item 2</div>
                <div class="item">Item 3</div>
            </div>
        </body>
        </html>
        """
        
        engine.setViewport(CGSize(width: 800, height: 400))
        engine.loadHTML(flexHTML)
        
        await waitForLoading(engine)
        
        if let image = engine.createImage() {
            print("✅ Flexbox test completed: \(image.width)x\(image.height)")
        } else {
            print("❌ Flexbox test failed")
        }
    }
}

// MARK: - Integration Helper

extension WebCoreEngine {
    
    /// Simple helper to run the engine in a SwiftUI view
    func renderToSwiftUIImage() -> NSImage? {
        guard let cgImage = createImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

// MARK: - SwiftUI Integration View

struct WebCoreTestView: View {
    @State private var renderedImage: NSImage?
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            Text("WebCore Engine Test")
                .font(.title)
                .padding()
            
            if let image = renderedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 800, maxHeight: 600)
                    .border(Color.gray, width: 1)
            } else if isLoading {
                ProgressView("Rendering...")
                    .frame(width: 800, height: 600)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 800, height: 600)
                    .overlay(
                        Text("Click 'Render Test' to see WebCore in action")
                            .foregroundColor(.secondary)
                    )
            }
            
            HStack {
                Button("Render Test") {
                    renderTest()
                }
                .disabled(isLoading)
                
                Button("Flexbox Test") {
                    renderFlexboxTest()
                }
                .disabled(isLoading)
                
                Button("Clear") {
                    renderedImage = nil
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func renderTest() {
        isLoading = true
        
        Task {
            let config = WebCoreConfiguration()
            let engine = WebCoreEngine(configuration: config)
            
            let testHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body { 
                        margin: 20px; 
                        font-family: -apple-system, sans-serif;
                        background-color: white;
                    }
                    h1 { 
                        color: #007AFF; 
                        font-size: 28px; 
                        margin-bottom: 20px;
                        text-align: center;
                    }
                    .container {
                        border: 2px solid #007AFF;
                        border-radius: 8px;
                        padding: 20px;
                        background-color: #F8F9FA;
                    }
                    p { 
                        color: #333; 
                        margin: 12px 0;
                        line-height: 1.4;
                    }
                    .highlight { 
                        background-color: #FFE45C; 
                        padding: 2px 4px;
                        border-radius: 3px;
                    }
                    ul {
                        margin: 16px 0;
                        padding-left: 24px;
                    }
                    li {
                        margin: 8px 0;
                        color: #555;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🚀 WebCore Engine Demo</h1>
                    <p>Welcome to the WebCore rendering engine! This page demonstrates:</p>
                    <ul>
                        <li>HTML5 parsing and DOM construction</li>
                        <li>CSS3 styling with colors and layout</li>
                        <li>Text rendering with <span class="highlight">highlighted content</span></li>
                        <li>Box model with margins, padding, and borders</li>
                    </ul>
                    <p>Built with WebKit-inspired architecture for modern web standards.</p>
                </div>
            </body>
            </html>
            """
            
            engine.setViewport(CGSize(width: 800, height: 600))
            engine.loadHTML(testHTML)
            
            // Wait for rendering
            for _ in 0..<50 {
                if !engine.isLoading { break }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            await MainActor.run {
                renderedImage = engine.renderToSwiftUIImage()
                isLoading = false
            }
        }
    }
    
    private func renderFlexboxTest() {
        isLoading = true
        
        Task {
            await WebCoreTest.testFlexboxLayout()
            
            await MainActor.run {
                isLoading = false
                // For this test, we'll just indicate completion
                // In a real implementation, you'd capture the result
            }
        }
    }
}

#Preview {
    WebCoreTestView()
        .frame(width: 900, height: 800)
}
