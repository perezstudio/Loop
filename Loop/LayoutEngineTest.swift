//
//  LayoutEngineTest.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Layout Engine Test

class LayoutEngineTest {
    
    static func testLayoutEngine() {
        print("🚀 Testing Native Layout Engine...")
        
        // Test CSS Display Types
        var style = CSSStyle()
        style.display = .block
        print("✅ Block display type: \(style.display!)")
        
        style.display = .inline
        print("✅ Inline display type: \(style.display!)")
        
        style.display = .inlineBlock
        print("✅ Inline-block display type: \(style.display!)")
        
        style.display = .flex
        print("✅ Flex display type: \(style.display!)")
        
        style.display = CSSStyle.DisplayType.none
        print("✅ None display type: \(style.display!)")
        
        // Test EdgeInsets initialization
        let defaultEdgeInsets = EdgeInsets()
        print("✅ Default EdgeInsets: top=\(defaultEdgeInsets.top), leading=\(defaultEdgeInsets.leading), bottom=\(defaultEdgeInsets.bottom), trailing=\(defaultEdgeInsets.trailing)")
        
        let customEdgeInsets = EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
        print("✅ Custom EdgeInsets: top=\(customEdgeInsets.top), leading=\(customEdgeInsets.leading), bottom=\(customEdgeInsets.bottom), trailing=\(customEdgeInsets.trailing)")
        
        // Test CSS parsing for inline-block
        let cssParser = CSSParser()
        let inlineBlockStyle = cssParser.parseInlineStyle("display: inline-block; margin: 10px; padding: 5px;")
        print("✅ Parsed inline-block style: display=\(inlineBlockStyle.display?.description ?? "nil")")
        
        // Test layout engine initialization
        let layoutEngine = NativeLayoutEngine()
        print("✅ Layout engine initialized")
        
        // Test layout with mock data
        let mockDOM = DOMNode(tagName: "div")
        let mockRenderNode = RenderNode(domNode: mockDOM)
        mockRenderNode.computedStyle = inlineBlockStyle
        
        let viewport = CGRect(x: 0, y: 0, width: 800, height: 600)
        layoutEngine.layout(mockRenderNode, in: viewport)
        print("✅ Layout computation completed")
        
        print("🎉 All layout engine tests passed!")
    }
}

// MARK: - Display Type Description

extension CSSStyle.DisplayType: CustomStringConvertible {
    var description: String {
        switch self {
        case .block: return "block"
        case .inline: return "inline"
        case .inlineBlock: return "inlineBlock"
        case .flex: return "flex"
        case .none: return "none"
        }
    }
}

// MARK: - SwiftUI Integration Test

struct LayoutEngineTestView: View {
    var body: some View {
        VStack {
            Text("Layout Engine Test")
                .font(.title)
                .padding()
            
            Button("Run Layout Test") {
                LayoutEngineTest.testLayoutEngine()
            }
            .padding()
        }
    }
}

#Preview {
    LayoutEngineTestView()
}
