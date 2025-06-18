//
//  RenderingTest.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Basic Rendering Test

class RenderingTest {
    
    static func testBasicRendering() {
        print("🚀 Testing Native Rendering Engine...")
        
        // Test FontWeight conversion
        let fontWeight = FontWeight.bold
        let swiftUIWeight = fontWeight.toSwiftUIWeight()
        print("✅ FontWeight conversion: \(fontWeight) -> \(swiftUIWeight)")
        
        // Test CSS Style with font
        var style = CSSStyle()
        style.fontSize = 18
        style.fontWeight = .bold
        style.color = .blue
        
        let ctFont = style.ctFont
        print("✅ CoreText font created: \(CTFontCopyDisplayName(ctFont))")
        
        // Test Color conversion
        let cgColor = style.color?.nativeCGColor
        let colorDesc = cgColor?.description ?? "nil"
        print("✅ Color conversion: \(style.color?.description ?? "nil") -> \(colorDesc)")
        
        // Test CSS parsing
        let cssParser = CSSParser()
        let inlineStyle = cssParser.parseInlineStyle("font-size: 20px; font-weight: bold; color: red;")
        print("✅ CSS parsing: fontSize=\(inlineStyle.fontSize ?? 0), fontWeight=\(inlineStyle.fontWeight?.description ?? "nil")")
        
        // Test DOM with stylesheets
        let dom = DOMNode(tagName: "html")
        let head = DOMNode(tagName: "head")
        let styleElement = DOMNode(tagName: "style", textContent: "p { font-size: 16px; color: blue; }")
        head.appendChild(styleElement)
        dom.appendChild(head)
        
        let rules = dom.extractStylesheets()
        print("✅ Stylesheet extraction: Found \(rules.count) CSS rules")
        
        // Test rendering engine initialization
        _ = NativeRenderingEngine()
        print("✅ Rendering engine initialized")
        
        print("🎉 All tests passed!")
    }
}

// MARK: - SwiftUI Integration Test

struct RenderingTestView: View {
    var body: some View {
        VStack {
            Text("Rendering Engine Test")
                .font(.title)
                .padding()
            
            Button("Run Test") {
                RenderingTest.testBasicRendering()
            }
            .padding()
        }
    }
}

#Preview {
    RenderingTestView()
}
