//
//  PaintSupport.swift
//  Loop - WebKit-Inspired Paint Support Classes
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO

// MARK: - Background Painter

class BackgroundPainter {
    
    func paintBackground(backgroundColor: CSSColor, frame: CGRect, context: PaintContext) throws {
        let cgContext = context.cgContext
        let cgColor = backgroundColor.cgColor
        
        cgContext.setFillColor(cgColor)
        cgContext.fill(frame)
    }
}

// MARK: - Text Painter

class TextPainter {
    
    enum TextAlignment {
        case left, center, right
    }
    
    func paintText(text: String, style: ComputedStyle, frame: CGRect, context: PaintContext) throws {
        let fontSize = style.resolvedFontSize()
        let fontWeight = style.fontWeight
        let textColor = style.color.cgColor
        
        // Create attributed string
        let font = createCTFont(size: fontSize, weight: fontWeight)
        let attributedString = createAttributedString(text: text, font: font, color: textColor)
        
        // Create frame and draw
        try drawAttributedString(attributedString, in: frame, style: style, context: context)
    }
    
    func paintSimpleText(text: String, fontSize: CGFloat, color: CGColor, frame: CGRect, alignment: TextAlignment, context: PaintContext) throws {
        let font = createCTFont(size: fontSize, weight: .normal)
        let attributedString = createAttributedString(text: text, font: font, color: color)
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        
        // Calculate position based on alignment
        let textX: CGFloat
        switch alignment {
        case .left:
            textX = frame.minX
        case .center:
            textX = frame.midX - textBounds.width / 2
        case .right:
            textX = frame.maxX - textBounds.width
        }
        
        let textY = frame.midY - textBounds.height / 2
        
        // Draw text
        let cgContext = context.cgContext
        cgContext.saveGState()
        
        // Flip coordinate system for text
        cgContext.translateBy(x: 0, y: frame.height)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        
        cgContext.textPosition = CGPoint(x: textX, y: frame.height - textY - textBounds.height)
        CTLineDraw(line, cgContext)
        
        cgContext.restoreGState()
    }
    
    private func drawAttributedString(_ attributedString: CFAttributedString, in frame: CGRect, style: ComputedStyle, context: PaintContext) throws {
        let cgContext = context.cgContext
        
        // Create text frame
        let path = CGPath(rect: frame, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        
        // Save graphics state
        cgContext.saveGState()
        
        // Flip coordinate system for text rendering
        cgContext.translateBy(x: 0, y: frame.maxY)
        cgContext.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the text
        CTFrameDraw(textFrame, cgContext)
        
        // Restore graphics state
        cgContext.restoreGState()
    }
    
    private func createCTFont(size: CGFloat, weight: FontWeightValue) -> CTFont {
        let fontName: String
        
        switch weight {
        case .bold, .bolder:
            fontName = "Helvetica-Bold"
        case .lighter:
            fontName = "Helvetica-Light"
        case .numeric(let value):
            if value >= 700 {
                fontName = "Helvetica-Bold"
            } else if value <= 300 {
                fontName = "Helvetica-Light"
            } else {
                fontName = "Helvetica"
            }
        default:
            fontName = "Helvetica"
        }
        
        return CTFontCreateWithName(fontName as CFString, size, nil)
    }
    
    private func createAttributedString(text: String, font: CTFont, color: CGColor) -> CFAttributedString {
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color
        ]
        
        return CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
    }
}

// MARK: - Border Painter

class BorderPainter {
    
    func paintBorders(style: ComputedStyle, frame: CGRect, context: PaintContext) throws {
        let cgContext = context.cgContext
        
        // Get border properties
        let topWidth = style.borderTopWidth.resolveLength(relativeTo: frame.width, fontSize: style.resolvedFontSize()) ?? 0
        let rightWidth = style.borderRightWidth.resolveLength(relativeTo: frame.width, fontSize: style.resolvedFontSize()) ?? 0
        let bottomWidth = style.borderBottomWidth.resolveLength(relativeTo: frame.width, fontSize: style.resolvedFontSize()) ?? 0
        let leftWidth = style.borderLeftWidth.resolveLength(relativeTo: frame.width, fontSize: style.resolvedFontSize()) ?? 0
        
        let borderColor = style.borderColor.cgColor
        
        // Paint each border side
        if topWidth > 0 && style.borderTopStyle != .none {
            paintBorderSide(.top, width: topWidth, style: style.borderTopStyle, color: borderColor, frame: frame, context: context)
        }
        
        if rightWidth > 0 && style.borderRightStyle != .none {
            paintBorderSide(.right, width: rightWidth, style: style.borderRightStyle, color: borderColor, frame: frame, context: context)
        }
        
        if bottomWidth > 0 && style.borderBottomStyle != .none {
            paintBorderSide(.bottom, width: bottomWidth, style: style.borderBottomStyle, color: borderColor, frame: frame, context: context)
        }
        
        if leftWidth > 0 && style.borderLeftStyle != .none {
            paintBorderSide(.left, width: leftWidth, style: style.borderLeftStyle, color: borderColor, frame: frame, context: context)
        }
    }
    
    private enum BorderSide {
        case top, right, bottom, left
    }
    
    private func paintBorderSide(_ side: BorderSide, width: CGFloat, style: BorderStyleValue, color: CGColor, frame: CGRect, context: PaintContext) {
        let cgContext = context.cgContext
        
        cgContext.setStrokeColor(color)
        cgContext.setLineWidth(width)
        
        // Set line style based on border style
        switch style {
        case .solid:
            cgContext.setLineDash(phase: 0, lengths: [])
        case .dashed:
            cgContext.setLineDash(phase: 0, lengths: [width * 3, width * 2])
        case .dotted:
            cgContext.setLineDash(phase: 0, lengths: [width, width])
        case .double:
            // Draw two lines for double border
            paintDoubleBorder(side, width: width, color: color, frame: frame, context: context)
            return
        default:
            cgContext.setLineDash(phase: 0, lengths: [])
        }
        
        // Draw the border line
        switch side {
        case .top:
            let y = frame.minY + width / 2
            cgContext.move(to: CGPoint(x: frame.minX, y: y))
            cgContext.addLine(to: CGPoint(x: frame.maxX, y: y))
        case .right:
            let x = frame.maxX - width / 2
            cgContext.move(to: CGPoint(x: x, y: frame.minY))
            cgContext.addLine(to: CGPoint(x: x, y: frame.maxY))
        case .bottom:
            let y = frame.maxY - width / 2
            cgContext.move(to: CGPoint(x: frame.minX, y: y))
            cgContext.addLine(to: CGPoint(x: frame.maxX, y: y))
        case .left:
            let x = frame.minX + width / 2
            cgContext.move(to: CGPoint(x: x, y: frame.minY))
            cgContext.addLine(to: CGPoint(x: x, y: frame.maxY))
        }
        
        cgContext.strokePath()
    }
    
    private func paintDoubleBorder(_ side: BorderSide, width: CGFloat, color: CGColor, frame: CGRect, context: PaintContext) {
        let cgContext = context.cgContext
        let lineWidth = width / 3
        let gap = lineWidth
        
        cgContext.setStrokeColor(color)
        cgContext.setLineWidth(lineWidth)
        cgContext.setLineDash(phase: 0, lengths: [])
        
        switch side {
        case .top:
            let y1 = frame.minY + lineWidth / 2
            let y2 = frame.minY + lineWidth + gap + lineWidth / 2
            
            cgContext.move(to: CGPoint(x: frame.minX, y: y1))
            cgContext.addLine(to: CGPoint(x: frame.maxX, y: y1))
            cgContext.move(to: CGPoint(x: frame.minX, y: y2))
            cgContext.addLine(to: CGPoint(x: frame.maxX, y: y2))
            
        case .right:
            let x1 = frame.maxX - lineWidth / 2
            let x2 = frame.maxX - lineWidth - gap - lineWidth / 2
            
            cgContext.move(to: CGPoint(x: x1, y: frame.minY))
            cgContext.addLine(to: CGPoint(x: x1, y: frame.maxY))
            cgContext.move(to: CGPoint(x: x2, y: frame.minY))
            cgContext.addLine(to: CGPoint(x: x2, y: frame.maxY))
            
        case .bottom:
            let y1 = frame.maxY - lineWidth / 2
            let y2 = frame.maxY - lineWidth - gap - lineWidth / 2
            
            cgContext.move(to: CGPoint(x: frame.minX, y: y1))
            cgContext.addLine(to: CGPoint(x: frame.maxX, y: y1))
            cgContext.move(to: CGPoint(x: frame.minX, y: y2))
            cgContext.addLine(to: CGPoint(x: frame.maxX, y: y2))
            
        case .left:
            let x1 = frame.minX + lineWidth / 2
            let x2 = frame.minX + lineWidth + gap + lineWidth / 2
            
            cgContext.move(to: CGPoint(x: x1, y: frame.minY))
            cgContext.addLine(to: CGPoint(x: x1, y: frame.maxY))
            cgContext.move(to: CGPoint(x: x2, y: frame.minY))
            cgContext.addLine(to: CGPoint(x: x2, y: frame.maxY))
        }
        
        cgContext.strokePath()
    }
}

// MARK: - Image Painter

class ImagePainter {
    
    private var imageCache: [String: CGImage] = [:]
    
    func paintImage(src: String, frame: CGRect, context: PaintContext) throws {
        let cgContext = context.cgContext
        
        // Try to load image from cache or file system
        if let image = loadImage(src: src) {
            // Draw the actual image
            cgContext.draw(image, in: frame)
        } else {
            // Draw placeholder
            try paintImagePlaceholder(src: src, frame: frame, context: context)
        }
    }
    
    private func loadImage(src: String) -> CGImage? {
        // Check cache first
        if let cachedImage = imageCache[src] {
            return cachedImage
        }
        
        // Try to load from file system or URL
        let image: CGImage?
        
        if src.hasPrefix("http://") || src.hasPrefix("https://") {
            // Network image - would need async loading in real implementation
            image = nil
        } else {
            // Local file
            if let url = URL(string: src),
               let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                image = cgImage
            } else {
                image = nil
            }
        }
        
        // Cache the result
        if let image = image {
            imageCache[src] = image
        }
        
        return image
    }
    
    private func paintImagePlaceholder(src: String, frame: CGRect, context: PaintContext) throws {
        let cgContext = context.cgContext
        
        // Draw placeholder background
        cgContext.setFillColor(CGColor(gray: 0.9, alpha: 1.0))
        cgContext.fill(frame)
        
        // Draw border
        cgContext.setStrokeColor(CGColor(gray: 0.7, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        cgContext.stroke(frame)
        
        // Draw broken image icon or text
        let placeholderText = "🖼️"
        
        if frame.width > 40 && frame.height > 40 {
            // Draw placeholder text
            let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: CGColor(gray: 0.5, alpha: 1.0)
            ]
            
            let attributedString = CFAttributedStringCreate(nil, placeholderText as CFString, attributes as CFDictionary)!
            let line = CTLineCreateWithAttributedString(attributedString)
            let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            
            let textX = frame.midX - textBounds.width / 2
            let textY = frame.midY - textBounds.height / 2
            
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: frame.height)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            cgContext.textPosition = CGPoint(x: textX, y: frame.height - textY - textBounds.height)
            CTLineDraw(line, cgContext)
            cgContext.restoreGState()
        }
        
        // Draw src text if there's space
        if frame.width > 100 && frame.height > 60 {
            let srcText = src.count > 20 ? String(src.prefix(17)) + "..." : src
            let font = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: CGColor(gray: 0.4, alpha: 1.0)
            ]
            
            let attributedString = CFAttributedStringCreate(nil, srcText as CFString, attributes as CFDictionary)!
            let line = CTLineCreateWithAttributedString(attributedString)
            let textBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            
            let textX = frame.midX - textBounds.width / 2
            let textY = frame.maxY - 15
            
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: frame.height)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            cgContext.textPosition = CGPoint(x: textX, y: frame.height - textY - textBounds.height)
            CTLineDraw(line, cgContext)
            cgContext.restoreGState()
        }
    }
    
    func clearCache() {
        imageCache.removeAll()
    }
}
