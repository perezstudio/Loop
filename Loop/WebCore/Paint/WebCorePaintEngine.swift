//
//  WebCorePaintEngine.swift
//  Loop - WebKit-Inspired Paint Engine
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import CoreText
import AppKit

// MARK: - Paint Engine Delegate

protocol WebCorePaintEngineDelegate: AnyObject {
    func paintEngineDidInvalidate(_ engine: WebCorePaintEngine, rect: CGRect)
}

// MARK: - Paint Context

struct PaintContext {
    let cgContext: CGContext
    let viewport: CGRect
    let scaleFactor: CGFloat
    let enableDebugOverlays: Bool
    
    init(cgContext: CGContext, viewport: CGRect, scaleFactor: CGFloat = 1.0, enableDebugOverlays: Bool = false) {
        self.cgContext = cgContext
        self.viewport = viewport
        self.scaleFactor = scaleFactor
        self.enableDebugOverlays = enableDebugOverlays
    }
}

// MARK: - WebCore Paint Engine

class WebCorePaintEngine {
    
    // MARK: - Properties
    
    private let configuration: WebCore.Configuration
    private let backgroundPainter: BackgroundPainter
    private let textPainter: TextPainter
    private let borderPainter: BorderPainter
    private let imagePainter: ImagePainter
    
    weak var delegate: WebCorePaintEngineDelegate?
    
    // MARK: - Initialization
    
    init(configuration: WebCore.Configuration) {
        self.configuration = configuration
        self.backgroundPainter = BackgroundPainter()
        self.textPainter = TextPainter()
        self.borderPainter = BorderPainter()
        self.imagePainter = ImagePainter()
        
        print("🎨 WebCore Paint Engine initialized")
    }
    
    // MARK: - Main Paint Method
    
    func paint(_ renderObject: RenderObject, context: PaintContext) -> Bool {
        guard !renderObject.frame.isEmpty else {
            if configuration.enablePaintDebugging {
                print("🚫 Skipping paint - empty frame for: \(renderObject.debugDescription)")
            }
            return true
        }
        
        if configuration.enablePaintDebugging {
            print("🎨 Painting: \(renderObject.debugDescription)")
        }
        
        let cgContext = context.cgContext
        
        // Save graphics state
        cgContext.saveGState()
        
        // Apply clipping
        cgContext.clip(to: renderObject.frame)
        
        // Apply transform if any
        if renderObject.transform != .identity {
            cgContext.concatenate(renderObject.transform)
        }
        
        // Apply opacity
        if renderObject.opacity < 1.0 {
            cgContext.setAlpha(renderObject.opacity)
        }
        
        // Paint in rendering order
        do {
            // 1. Background
            try paintBackground(renderObject, context: context)
            
            // 2. Content
            try paintContent(renderObject, context: context)
            
            // 3. Children
            try paintChildren(renderObject, context: context)
            
            // 4. Borders and outlines
            try paintDecorations(renderObject, context: context)
            
            // 5. Debug overlays
            if context.enableDebugOverlays {
                paintDebugOverlay(renderObject, context: context)
            }
            
        } catch {
            print("❌ Paint error for \(renderObject.debugDescription): \(error)")
            cgContext.restoreGState()
            return false
        }
        
        // Restore graphics state
        cgContext.restoreGState()
        
        // Mark as painted
        renderObject.needsRepaint = false
        
        return true
    }
    
    // MARK: - Background Painting
    
    private func paintBackground(_ renderObject: RenderObject, context: PaintContext) throws {
        guard let style = renderObject.computedStyle else { return }
        
        let backgroundColor = style.backgroundColor
        
        // Add a default background for HTML root element to make it visible
        let effectiveBackgroundColor: WebCore.Color
        if backgroundColor == WebCore.Color.transparent, 
           let element = renderObject.element, 
           element.tagName.lowercased() == "html" {
            effectiveBackgroundColor = .named("white")  // Default white background for HTML
        } else {
            effectiveBackgroundColor = backgroundColor
        }
        
        if effectiveBackgroundColor != WebCore.Color.transparent {
            try backgroundPainter.paintBackground(
                backgroundColor: effectiveBackgroundColor,
                frame: renderObject.frame,
                context: context
            )
        }
    }
    
    // MARK: - Content Painting
    
    private func paintContent(_ renderObject: RenderObject, context: PaintContext) throws {
        if renderObject.isTextNode {
            try paintTextContent(renderObject, context: context)
        } else if let element = renderObject.element {
            try paintElementContent(element, renderObject: renderObject, context: context)
        }
    }
    
    private func paintTextContent(_ renderObject: RenderObject, context: PaintContext) throws {
        guard let textContent = renderObject.textContent,
              !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let style = renderObject.computedStyle else { return }
        
        if configuration.enablePaintDebugging {
            print("📝 Painting text: '\(textContent.prefix(50))'")
        }
        
        try textPainter.paintText(
            text: textContent,
            style: style,
            frame: renderObject.frame,
            context: context
        )
    }
    
    private func paintElementContent(_ element: WebCoreElement, renderObject: RenderObject, context: PaintContext) throws {
        let tagName = element.tagName.lowercased()
        
        switch tagName {
        case "img":
            try paintImage(element, renderObject: renderObject, context: context)
        case "hr":
            try paintHorizontalRule(renderObject, context: context)
        case "input":
            try paintInput(element, renderObject: renderObject, context: context)
        case "button":
            try paintButton(element, renderObject: renderObject, context: context)
        case "canvas":
            try paintCanvas(element, renderObject: renderObject, context: context)
        default:
            // Most elements are just containers
            break
        }
    }
    
    // MARK: - Children Painting
    
    private func paintChildren(_ renderObject: RenderObject, context: PaintContext) throws {
        for child in renderObject.children {
            // Skip children that have their own layers
            if child.layer == nil {
                _ = paint(child, context: context)
            }
        }
    }
    
    // MARK: - Decorations Painting
    
    private func paintDecorations(_ renderObject: RenderObject, context: PaintContext) throws {
        guard let style = renderObject.computedStyle else { return }
        
        // Paint borders
        try borderPainter.paintBorders(
            style: style,
            frame: renderObject.frame,
            context: context
        )
        
        // Paint text decorations
        if let element = renderObject.element, element.tagName.lowercased() == "a" {
            try paintTextDecoration(renderObject, context: context)
        }
    }
    
    // MARK: - Specific Element Painters
    
    private func paintImage(_ element: WebCoreElement, renderObject: RenderObject, context: PaintContext) throws {
        guard let src = element.getAttribute("src") else { return }
        
        try imagePainter.paintImage(
            src: src,
            frame: renderObject.frame,
            context: context
        )
    }
    
    private func paintHorizontalRule(_ renderObject: RenderObject, context: PaintContext) throws {
        let cgContext = context.cgContext
        
        cgContext.setStrokeColor(CGColor(gray: 0.5, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        
        let y = renderObject.frame.midY
        cgContext.move(to: CGPoint(x: renderObject.frame.minX, y: y))
        cgContext.addLine(to: CGPoint(x: renderObject.frame.maxX, y: y))
        cgContext.strokePath()
    }
    
    private func paintInput(_ element: WebCoreElement, renderObject: RenderObject, context: PaintContext) throws {
        let cgContext = context.cgContext
        
        // Paint input background
        cgContext.setFillColor(CGColor.white)
        cgContext.fill(renderObject.frame)
        
        // Paint border
        cgContext.setStrokeColor(CGColor(gray: 0.6, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        cgContext.stroke(renderObject.frame)
        
        // Paint value or placeholder
        let text = element.getAttribute("value") ?? element.getAttribute("placeholder") ?? ""
        if !text.isEmpty {
            let isPlaceholder = element.getAttribute("value") == nil
            try paintInputText(
                text: text,
                frame: renderObject.frame,
                isPlaceholder: isPlaceholder,
                context: context
            )
        }
    }
    
    private func paintButton(_ element: WebCoreElement, renderObject: RenderObject, context: PaintContext) throws {
        let cgContext = context.cgContext
        
        // Paint button background
        cgContext.setFillColor(CGColor(gray: 0.95, alpha: 1.0))
        cgContext.fill(renderObject.frame)
        
        // Paint border
        cgContext.setStrokeColor(CGColor(gray: 0.6, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        cgContext.stroke(renderObject.frame)
        
        // Paint button text
        let text = element.textContent.isEmpty ? 
                   (element.getAttribute("value") ?? "Button") : 
                   element.textContent
        
        if !text.isEmpty {
            try paintButtonText(
                text: text,
                frame: renderObject.frame,
                context: context
            )
        }
    }
    
    private func paintCanvas(_ element: WebCoreElement, renderObject: RenderObject, context: PaintContext) throws {
        // Canvas elements would require a JavaScript context to render
        // For now, just paint a placeholder
        let cgContext = context.cgContext
        
        cgContext.setFillColor(CGColor(gray: 0.9, alpha: 1.0))
        cgContext.fill(renderObject.frame)
        
        cgContext.setStrokeColor(CGColor(gray: 0.7, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        cgContext.stroke(renderObject.frame)
        
        // Draw "CANVAS" text
        let placeholderText = "CANVAS"
        try paintPlaceholderText(
            text: placeholderText,
            frame: renderObject.frame,
            context: context
        )
    }
    
    private func paintTextDecoration(_ renderObject: RenderObject, context: PaintContext) throws {
        guard let style = renderObject.computedStyle else { return }
        
        switch style.textDecoration {
        case .underline:
            try paintUnderline(renderObject, context: context)
        case .overline:
            try paintOverline(renderObject, context: context)
        case .lineThrough:
            try paintLineThrough(renderObject, context: context)
        case .none:
            break
        }
    }
    
    private func paintUnderline(_ renderObject: RenderObject, context: PaintContext) throws {
        guard let style = renderObject.computedStyle else { return }
        
        let cgContext = context.cgContext
        let textColor = style.color.cgColor
        
        cgContext.setStrokeColor(textColor)
        cgContext.setLineWidth(1.0)
        
        let y = renderObject.frame.maxY - 2
        cgContext.move(to: CGPoint(x: renderObject.frame.minX, y: y))
        cgContext.addLine(to: CGPoint(x: renderObject.frame.maxX, y: y))
        cgContext.strokePath()
    }
    
    private func paintOverline(_ renderObject: RenderObject, context: PaintContext) throws {
        guard let style = renderObject.computedStyle else { return }
        
        let cgContext = context.cgContext
        let textColor = style.color.cgColor
        
        cgContext.setStrokeColor(textColor)
        cgContext.setLineWidth(1.0)
        
        let y = renderObject.frame.minY + 2
        cgContext.move(to: CGPoint(x: renderObject.frame.minX, y: y))
        cgContext.addLine(to: CGPoint(x: renderObject.frame.maxX, y: y))
        cgContext.strokePath()
    }
    
    private func paintLineThrough(_ renderObject: RenderObject, context: PaintContext) throws {
        guard let style = renderObject.computedStyle else { return }
        
        let cgContext = context.cgContext
        let textColor = style.color.cgColor
        
        cgContext.setStrokeColor(textColor)
        cgContext.setLineWidth(1.0)
        
        let y = renderObject.frame.midY
        cgContext.move(to: CGPoint(x: renderObject.frame.minX, y: y))
        cgContext.addLine(to: CGPoint(x: renderObject.frame.maxX, y: y))
        cgContext.strokePath()
    }
    
    // MARK: - Helper Text Painters
    
    private func paintInputText(text: String, frame: CGRect, isPlaceholder: Bool, context: PaintContext) throws {
        let fontSize: CGFloat = 14
        let textColor = isPlaceholder ? CGColor(gray: 0.6, alpha: 1.0) : CGColor.black
        
        try textPainter.paintSimpleText(
            text: text,
            fontSize: fontSize,
            color: textColor,
            frame: frame.insetBy(dx: 8, dy: 0), // Add padding
            alignment: .left,
            context: context
        )
    }
    
    private func paintButtonText(text: String, frame: CGRect, context: PaintContext) throws {
        let fontSize: CGFloat = 14
        let textColor = CGColor.black
        
        try textPainter.paintSimpleText(
            text: text,
            fontSize: fontSize,
            color: textColor,
            frame: frame,
            alignment: .center,
            context: context
        )
    }
    
    private func paintPlaceholderText(text: String, frame: CGRect, context: PaintContext) throws {
        let fontSize: CGFloat = 12
        let textColor = CGColor(gray: 0.5, alpha: 1.0)
        
        try textPainter.paintSimpleText(
            text: text,
            fontSize: fontSize,
            color: textColor,
            frame: frame,
            alignment: .center,
            context: context
        )
    }
    
    // MARK: - Debug Overlay
    
    private func paintDebugOverlay(_ renderObject: RenderObject, context: PaintContext) {
        let cgContext = context.cgContext
        
        // Paint frame outline
        cgContext.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        cgContext.setLineWidth(1.0)
        cgContext.stroke(renderObject.frame)
        
        // Paint content rect if different
        if renderObject.contentRect != .zero && renderObject.contentRect != renderObject.frame {
            let contentFrameInParent = CGRect(
                x: renderObject.frame.minX + renderObject.contentRect.minX,
                y: renderObject.frame.minY + renderObject.contentRect.minY,
                width: renderObject.contentRect.width,
                height: renderObject.contentRect.height
            )
            
            cgContext.setStrokeColor(CGColor(red: 0, green: 1, blue: 0, alpha: 0.5))
            cgContext.stroke(contentFrameInParent)
        }
        
        // Paint debug info text
        if renderObject.frame.width > 100 && renderObject.frame.height > 20 {
            let debugText = renderObject.tagName
            
            do {
                try textPainter.paintSimpleText(
                    text: debugText,
                    fontSize: 10,
                    color: CGColor(red: 1, green: 0, blue: 0, alpha: 0.8),
                    frame: renderObject.frame.insetBy(dx: 2, dy: 2),
                    alignment: .left,
                    context: context
                )
            } catch {
                // Ignore debug text errors
            }
        }
    }
}

// MARK: - Paint Errors

enum PaintError: Error {
    case invalidContext
    case invalidFrame
    case textRenderingFailed
    case imageLoadFailed
    case unsupportedFeature(String)
}
