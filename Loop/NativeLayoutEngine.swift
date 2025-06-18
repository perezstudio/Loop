//
//  NativeLayoutEngine.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import CoreText
import SwiftUI

// Import shared types
// FontWeight enum is defined in NativeTypes.swift

// MARK: - Native Layout Engine

class NativeLayoutEngine {
    
    func layout(_ renderNode: RenderNode, in viewport: CGRect) {
        // Reset layout state
        renderNode.frame = .zero
        
        // Perform layout based on CSS display type
        performLayout(renderNode, in: viewport, parentContext: nil)
        
        print("Layout complete: \(renderNode.frame)")
    }
    
    // MARK: - Layout Computation
    
    private func performLayout(_ node: RenderNode, in bounds: CGRect, parentContext: LayoutContext?) {
        let layoutContext = createLayoutContext(for: node, in: bounds, parent: parentContext)
        
        switch getDisplayType(for: node) {
        case .block:
            layoutBlock(node, context: layoutContext)
        case .inline:
            layoutInline(node, context: layoutContext)
        case .inlineBlock:
            layoutInlineBlock(node, context: layoutContext)
        case .flex:
            layoutBlock(node, context: layoutContext) // For now, treat flex as block
        case .none:
            node.frame = .zero
            return
        }
        
        // Mark as needing repaint
        node.needsRepaint = true
    }
    
    // MARK: - Block Layout
    
    private func layoutBlock(_ node: RenderNode, context: LayoutContext) {
        let style = node.computedStyle
        let margin = style.margin ?? EdgeInsets()
        let padding = style.padding ?? EdgeInsets()
        
        // Calculate available content area
        let contentX = context.bounds.minX + margin.leading + padding.leading
        let contentY = context.bounds.minY + margin.top + padding.top
        let contentWidth = context.bounds.width - margin.leading - margin.trailing - padding.leading - padding.trailing
        
        var currentY = contentY
        var maxChildWidth: CGFloat = 0
        
        // Layout children vertically
        for child in node.children {
            let childBounds = CGRect(
                x: contentX,
                y: currentY,
                width: contentWidth,
                height: context.bounds.maxY - currentY
            )
            
            performLayout(child, in: childBounds, parentContext: context)
            
            if child.frame.width > 0 || child.frame.height > 0 {
                currentY += child.frame.height
                maxChildWidth = max(maxChildWidth, child.frame.width)
                
                // Add margin between block elements
                if let childMargin = child.computedStyle.margin {
                    currentY += childMargin.bottom
                }
            }
        }
        
        // Set final frame
        let totalHeight = currentY - contentY + margin.bottom + padding.bottom
        node.frame = CGRect(
            x: context.bounds.minX,
            y: context.bounds.minY,
            width: context.bounds.width,
            height: totalHeight
        )
    }
    
    // MARK: - Inline Layout
    
    private func layoutInline(_ node: RenderNode, context: LayoutContext) {
        if node.domNode.isTextNode {
            layoutText(node, context: context)
        } else {
            layoutInlineContainer(node, context: context)
        }
    }
    
    private func layoutInlineContainer(_ node: RenderNode, context: LayoutContext) {
        var currentX = context.bounds.minX
        var maxHeight: CGFloat = 0
        
        for child in node.children {
            let remainingWidth = context.bounds.maxX - currentX
            let childBounds = CGRect(
                x: currentX,
                y: context.bounds.minY,
                width: remainingWidth,
                height: context.bounds.height
            )
            
            performLayout(child, in: childBounds, parentContext: context)
            
            if child.frame.width > 0 {
                currentX += child.frame.width
                maxHeight = max(maxHeight, child.frame.height)
            }
        }
        
        node.frame = CGRect(
            x: context.bounds.minX,
            y: context.bounds.minY,
            width: currentX - context.bounds.minX,
            height: maxHeight
        )
    }
    
    // MARK: - Text Layout
    
    private func layoutText(_ node: RenderNode, context: LayoutContext) {
        guard let text = node.domNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            node.frame = .zero
            return
        }
        
        let style = node.computedStyle
        let fontSize = style.fontSize ?? 16
        let fontWeight = style.fontWeight ?? .regular
        
        // Use CoreText for accurate text measurement
        let attributedString = createAttributedString(
            text: text,
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: style.cgColor
        )
        
        let textSize = measureText(attributedString, maxWidth: context.bounds.width)
        
        node.frame = CGRect(
            x: context.bounds.minX,
            y: context.bounds.minY,
            width: textSize.width,
            height: textSize.height
        )
    }
    
    private func layoutInlineBlock(_ node: RenderNode, context: LayoutContext) {
        // Inline-block elements are laid out like blocks but participate in inline flow
        layoutBlock(node, context: context)
    }
    
    // MARK: - Helper Methods
    
    private func createLayoutContext(for node: RenderNode, in bounds: CGRect, parent: LayoutContext?) -> LayoutContext {
        return LayoutContext(
            bounds: bounds,
            parentContext: parent,
            node: node
        )
    }
    
    private func getDisplayType(for node: RenderNode) -> CSSStyle.DisplayType {
        if let display = node.computedStyle.display {
            return display
        }
        
        // Determine default display type based on tag
        guard let tagName = node.domNode.tagName?.lowercased() else {
            return .inline // Text nodes are inline
        }
        
        let blockTags = ["div", "p", "h1", "h2", "h3", "h4", "h5", "h6", "section", "article", 
                        "header", "footer", "nav", "aside", "main", "ul", "ol", "li", "blockquote"]
        
        return blockTags.contains(tagName) ? .block : .inline
    }
    
    // MARK: - CoreText Integration
    
    private func createAttributedString(text: String, fontSize: CGFloat, fontWeight: FontWeight, color: CGColor) -> CFAttributedString {
        let font = createCTFont(size: fontSize, weight: fontWeight)
        
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color
        ]
        
        return CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
    }
    
    private func createCTFont(size: CGFloat, weight: FontWeight) -> CTFont {
        let fontName: String
        
        switch weight {
        case .bold, .heavy, .black:
            fontName = "Helvetica-Bold"
        case .medium, .semibold:
            fontName = "Helvetica-Medium"
        case .light, .thin, .ultraLight:
            fontName = "Helvetica-Light"
        default:
            fontName = "Helvetica"
        }
        
        return CTFontCreateWithName(fontName as CFString, size, nil)
    }
    
    private func measureText(_ attributedString: CFAttributedString, maxWidth: CGFloat) -> CGSize {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
            nil
        )
        
        return CGSize(
            width: min(suggestedSize.width, maxWidth),
            height: suggestedSize.height
        )
    }
}

// MARK: - Layout Context

class LayoutContext {
    let bounds: CGRect
    weak var parentContext: LayoutContext?
    let node: RenderNode
    
    init(bounds: CGRect, parentContext: LayoutContext?, node: RenderNode) {
        self.bounds = bounds
        self.parentContext = parentContext
        self.node = node
    }
    
    var availableWidth: CGFloat {
        return bounds.width
    }
    
    var availableHeight: CGFloat {
        return bounds.height
    }
}

// MARK: - Font Weight Extension

extension FontWeight {
    var ctFontWeight: CGFloat {
        switch self {
        case .ultraLight: return -0.8
        case .thin: return -0.6
        case .light: return -0.4
        case .regular: return 0.0
        case .medium: return 0.23
        case .semibold: return 0.3
        case .bold: return 0.4
        case .heavy: return 0.56
        case .black: return 0.62
        }
    }
}
