//
//  PaintEngine.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import CoreText
import AppKit
import SwiftUI

// Import shared types
// FontWeight and Color extensions are defined in NativeTypes.swift

// MARK: - Paint Engine

class PaintEngine {
    
    func paint(_ renderNode: RenderNode, context: RenderContext) {
        // Skip invisible elements
        guard !renderNode.frame.isEmpty else { 
            print("🚫 Skipping paint - empty frame for node: \(renderNode.domNode.tagName ?? "text")")
            return 
        }
        
        print("🎨 Painting node: \(renderNode.domNode.tagName ?? "text"), frame: \(renderNode.frame)")
        
        let cgContext = context.cgContext
        
        // Save graphics state
        cgContext.saveGState()
        
        // Set clipping rect
        cgContext.clip(to: renderNode.frame)
        
        // Paint background
        paintBackground(renderNode, context: context)
        
        // Paint content based on node type
        if renderNode.domNode.isTextNode {
            print("📝 Painting text node: '\(renderNode.domNode.textContent ?? "")'")
            paintText(renderNode, context: context)
        } else {
            print("📍 Painting element: \(renderNode.domNode.tagName ?? "unknown")")
            paintElement(renderNode, context: context)
        }
        
        // Paint children
        for child in renderNode.children {
            paint(child, context: context)
        }
        
        // Paint borders and decorations
        paintDecorations(renderNode, context: context)
        
        // Restore graphics state
        cgContext.restoreGState()
    }
    
    // MARK: - Background Painting
    
    private func paintBackground(_ node: RenderNode, context: RenderContext) {
        let style = node.computedStyle
        
        if let backgroundColor = style.backgroundColor {
            let bgColor = backgroundColor.nativeCGColor
            context.cgContext.setFillColor(bgColor)
            context.cgContext.fill(node.frame)
            print("🎨 Painted background for \(node.domNode.tagName ?? "text")")
        }
    }
    
    // MARK: - Text Painting
    
    private func paintText(_ node: RenderNode, context: RenderContext) {
        guard let text = node.domNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        
        let style = node.computedStyle
        let fontSize = style.fontSize ?? 16
        let fontWeight = style.fontWeight ?? .regular  // Keep as FontWeight, don't convert
        let textColor = style.color?.nativeCGColor ?? CGColor.black
        
        print("🔤 Painting text: '\(text)' at \(node.frame) with color: \(textColor)")
        
        // Create attributed string
        let attributedString = createAttributedString(
            text: text,
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: textColor
        )
        
        // Create text frame
        let path = CGPath(rect: node.frame, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        
        // Draw text
        context.cgContext.textMatrix = .identity
        context.cgContext.translateBy(x: 0, y: node.frame.height)
        context.cgContext.scaleBy(x: 1.0, y: -1.0)
        
        CTFrameDraw(frame, context.cgContext)
        
        // Reset transform
        context.cgContext.scaleBy(x: 1.0, y: -1.0)
        context.cgContext.translateBy(x: 0, y: -node.frame.height)
    }
    
    // MARK: - Element Painting
    
    private func paintElement(_ node: RenderNode, context: RenderContext) {
        guard let tagName = node.domNode.tagName?.lowercased() else { return }
        
        switch tagName {
        case "img":
            paintImage(node, context: context)
        case "hr":
            paintHorizontalRule(node, context: context)
        case "input":
            paintInput(node, context: context)
        case "button":
            paintButton(node, context: context)
        default:
            // Most elements are just containers - background already painted
            break
        }
    }
    
    // MARK: - Specific Element Painting
    
    private func paintImage(_ node: RenderNode, context: RenderContext) {
        guard node.domNode.getAttribute("src") != nil else { return }
        
        // For now, paint a placeholder
        let cgContext = context.cgContext
        
        // Draw placeholder background
        cgContext.setFillColor(CGColor(gray: 0.9, alpha: 1.0))
        cgContext.fill(node.frame)
        
        // Draw border
        cgContext.setStrokeColor(CGColor(gray: 0.7, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        cgContext.stroke(node.frame)
        
        // Draw "IMG" text
        let placeholderText = "IMG"
        let fontSize: CGFloat = 12
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(gray: 0.5, alpha: 1.0)
        ]
        
        let attributedString = CFAttributedStringCreate(nil, placeholderText as CFString, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributedString)
        
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let textX = node.frame.midX - textBounds.width / 2
        let textY = node.frame.midY - textBounds.height / 2
        
        cgContext.textPosition = CGPoint(x: textX, y: textY)
        CTLineDraw(line, cgContext)
    }
    
    private func paintHorizontalRule(_ node: RenderNode, context: RenderContext) {
        let cgContext = context.cgContext
        
        cgContext.setStrokeColor(CGColor(gray: 0.5, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        
        let y = node.frame.midY
        cgContext.move(to: CGPoint(x: node.frame.minX, y: y))
        cgContext.addLine(to: CGPoint(x: node.frame.maxX, y: y))
        cgContext.strokePath()
    }
    
    private func paintInput(_ node: RenderNode, context: RenderContext) {
        let cgContext = context.cgContext
        
        // Draw input background
        cgContext.setFillColor(CGColor.white)
        cgContext.fill(node.frame)
        
        // Draw border
        cgContext.setStrokeColor(CGColor(gray: 0.6, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        cgContext.stroke(node.frame)
        
        // Draw placeholder or value text
        let text = node.domNode.getAttribute("value") ?? node.domNode.getAttribute("placeholder") ?? ""
        if !text.isEmpty {
            paintInputText(text, in: node.frame, context: context, isPlaceholder: node.domNode.getAttribute("value") == nil)
        }
    }
    
    private func paintButton(_ node: RenderNode, context: RenderContext) {
        let cgContext = context.cgContext
        
        // Draw button background
        cgContext.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0))
        cgContext.fill(node.frame)
        
        // Draw border
        cgContext.setStrokeColor(CGColor(gray: 0.6, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        cgContext.stroke(node.frame)
        
        // Draw button text
        let text = node.domNode.getAllTextContent().isEmpty ? 
                   (node.domNode.getAttribute("value") ?? "Button") : 
                   node.domNode.getAllTextContent()
        
        if !text.isEmpty {
            paintButtonText(text, in: node.frame, context: context)
        }
    }
    
    // MARK: - Decorations
    
    private func paintDecorations(_ node: RenderNode, context: RenderContext) {
        // Paint borders, outlines, etc.
        paintBorders(node, context: context)
        
        // Paint text decorations (underline, etc.)
        if node.domNode.tagName?.lowercased() == "a" {
            paintUnderline(node, context: context)
        }
    }
    
    private func paintBorders(_ node: RenderNode, context: RenderContext) {
        // For now, just paint a simple border for certain elements
        guard let tagName = node.domNode.tagName?.lowercased() else { return }
        
        if ["table", "td", "th"].contains(tagName) {
            let cgContext = context.cgContext
            cgContext.setStrokeColor(CGColor(gray: 0.5, alpha: 1.0))
            cgContext.setLineWidth(1.0)
            cgContext.stroke(node.frame)
        }
    }
    
    private func paintUnderline(_ node: RenderNode, context: RenderContext) {
        let cgContext = context.cgContext
        
        let textColor = node.computedStyle.color?.nativeCGColor ?? CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        cgContext.setStrokeColor(textColor)
        cgContext.setLineWidth(1.0)
        
        let y = node.frame.maxY - 2
        cgContext.move(to: CGPoint(x: node.frame.minX, y: y))
        cgContext.addLine(to: CGPoint(x: node.frame.maxX, y: y))
        cgContext.strokePath()
    }
    
    // MARK: - Helper Methods
    
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
    
    private func paintInputText(_ text: String, in frame: CGRect, context: RenderContext, isPlaceholder: Bool) {
        let fontSize: CGFloat = 14
        let textColor = isPlaceholder ? CGColor(gray: 0.6, alpha: 1.0) : CGColor.black
        
        let attributedString = createAttributedString(
            text: text,
            fontSize: fontSize,
            fontWeight: FontWeight.regular,
            color: textColor
        )
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        
        let textX = frame.minX + 8 // Padding
        let textY = frame.midY - textBounds.height / 2
        
        context.cgContext.textPosition = CGPoint(x: textX, y: textY)
        CTLineDraw(line, context.cgContext)
    }
    
    private func paintButtonText(_ text: String, in frame: CGRect, context: RenderContext) {
        let fontSize: CGFloat = 14
        let textColor = CGColor.black
        
        let attributedString = createAttributedString(
            text: text,
            fontSize: fontSize,
            fontWeight: FontWeight.medium,
            color: textColor
        )
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        
        let textX = frame.midX - textBounds.width / 2
        let textY = frame.midY - textBounds.height / 2
        
        context.cgContext.textPosition = CGPoint(x: textX, y: textY)
        CTLineDraw(line, context.cgContext)
    }
}
