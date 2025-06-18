//
//  TextEngine.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import CoreText
import AppKit

// Import shared types
// FontWeight enum is defined in NativeTypes.swift

// MARK: - Text Engine

class TextEngine {
    
    // MARK: - Text Measurement
    
    func measureText(_ text: String, font: CTFont, maxWidth: CGFloat) -> CGSize {
        let attributedString = createAttributedString(text: text, font: font, color: CGColor.black)
        return measureAttributedText(attributedString, maxWidth: maxWidth)
    }
    
    func measureAttributedText(_ attributedString: CFAttributedString, maxWidth: CGFloat) -> CGSize {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        let constraints = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            constraints,
            nil
        )
        
        return CGSize(
            width: min(suggestedSize.width, maxWidth),
            height: suggestedSize.height
        )
    }
    
    // MARK: - Text Layout
    
    func layoutText(_ text: String, font: CTFont, color: CGColor, in rect: CGRect) -> TextLayout {
        let attributedString = createAttributedString(text: text, font: font, color: color)
        return layoutAttributedText(attributedString, in: rect)
    }
    
    func layoutAttributedText(_ attributedString: CFAttributedString, in rect: CGRect) -> TextLayout {
        let path = CGPath(rect: rect, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var lineOrigins = Array<CGPoint>(repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), &lineOrigins)
        
        var textLines: [TextLine] = []
        
        for (index, line) in lines.enumerated() {
            let origin = lineOrigins[index]
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            
            let textLine = TextLine(
                line: line,
                origin: CGPoint(x: rect.minX + origin.x, y: rect.minY + origin.y),
                bounds: bounds
            )
            textLines.append(textLine)
        }
        
        return TextLayout(
            frame: frame,
            lines: textLines,
            bounds: rect
        )
    }
    
    // MARK: - Text Rendering
    
    func drawText(_ layout: TextLayout, in context: CGContext) {
        context.saveGState()
        
        // Set up coordinate system for text
        context.textMatrix = .identity
        context.setTextDrawingMode(.fill)
        
        // Draw each line
        for textLine in layout.lines {
            context.textPosition = textLine.origin
            CTLineDraw(textLine.line, context)
        }
        
        context.restoreGState()
    }
    
    // MARK: - Hit Testing
    
    func hitTest(_ layout: TextLayout, point: CGPoint) -> TextHitResult? {
        guard layout.bounds.contains(point) else { return nil }
        
        for (lineIndex, textLine) in layout.lines.enumerated() {
            let lineFrame = CGRect(
                origin: textLine.origin,
                size: textLine.bounds.size
            )
            
            if lineFrame.contains(point) {
                let relativePoint = CGPoint(
                    x: point.x - textLine.origin.x,
                    y: point.y - textLine.origin.y
                )
                
                let charIndex = CTLineGetStringIndexForPosition(textLine.line, relativePoint)
                let charOffset = CTLineGetOffsetForStringIndex(textLine.line, charIndex, nil)
                
                return TextHitResult(
                    lineIndex: lineIndex,
                    characterIndex: charIndex,
                    characterOffset: charOffset,
                    line: textLine
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Font Creation
    
    func createFont(family: String = "Helvetica", size: CGFloat, weight: FontWeight = .regular) -> CTFont {
        let fontName = getFontName(family: family, weight: weight)
        return CTFontCreateWithName(fontName as CFString, size, nil)
    }
    
    func createSystemFont(size: CGFloat, weight: FontWeight = .regular) -> CTFont {
        return createFont(family: "Helvetica", size: size, weight: weight)
    }
    
    // MARK: - Attributed String Creation
    
    func createAttributedString(text: String, font: CTFont, color: CGColor) -> CFAttributedString {
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color
        ]
        
        return CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
    }
    
    func createAttributedString(text: String, fontSize: CGFloat, weight: FontWeight, color: CGColor) -> CFAttributedString {
        let font = createSystemFont(size: fontSize, weight: weight)
        return createAttributedString(text: text, font: font, color: color)
    }
    
    // MARK: - Text Selection
    
    func getTextSelection(in layout: TextLayout, from startPoint: CGPoint, to endPoint: CGPoint) -> TextSelection? {
        guard let startHit = hitTest(layout, point: startPoint),
              let endHit = hitTest(layout, point: endPoint) else { return nil }
        
        let startIndex = min(startHit.characterIndex, endHit.characterIndex)
        let endIndex = max(startHit.characterIndex, endHit.characterIndex)
        
        return TextSelection(
            startIndex: startIndex,
            endIndex: endIndex,
            startLine: min(startHit.lineIndex, endHit.lineIndex),
            endLine: max(startHit.lineIndex, endHit.lineIndex)
        )
    }
    
    // MARK: - Helper Methods
    
    private func getFontName(family: String, weight: FontWeight) -> String {
        let baseFamily = family.lowercased()
        
        switch baseFamily {
        case "helvetica":
            switch weight {
            case .ultraLight: return "Helvetica-UltraLight"
            case .thin: return "Helvetica-Thin"
            case .light: return "Helvetica-Light"
            case .regular: return "Helvetica"
            case .medium: return "Helvetica-Medium"
            case .semibold: return "Helvetica-Semibold"
            case .bold: return "Helvetica-Bold"
            case .heavy: return "Helvetica-Heavy"
            case .black: return "Helvetica-Black"
            }
        case "times":
            switch weight {
            case .bold, .heavy, .black: return "Times-Bold"
            default: return "Times-Roman"
            }
        case "courier":
            switch weight {
            case .bold, .heavy, .black: return "Courier-Bold"
            default: return "Courier"
            }
        default:
            return "Helvetica" // Fallback
        }
    }
}

// MARK: - Text Layout Structures

struct TextLayout {
    let frame: CTFrame
    let lines: [TextLine]
    let bounds: CGRect
}

struct TextLine {
    let line: CTLine
    let origin: CGPoint
    let bounds: CGRect
}

struct TextHitResult {
    let lineIndex: Int
    let characterIndex: CFIndex
    let characterOffset: CGFloat
    let line: TextLine
}

struct TextSelection {
    let startIndex: CFIndex
    let endIndex: CFIndex
    let startLine: Int
    let endLine: Int
    
    var length: CFIndex {
        return endIndex - startIndex
    }
    
    var range: CFRange {
        return CFRangeMake(startIndex, length)
    }
}

// MARK: - Text Metrics

struct TextMetrics {
    let ascent: CGFloat
    let descent: CGFloat
    let leading: CGFloat
    let lineHeight: CGFloat
    let capHeight: CGFloat
    let xHeight: CGFloat
    
    init(font: CTFont) {
        self.ascent = CTFontGetAscent(font)
        self.descent = CTFontGetDescent(font)
        self.leading = CTFontGetLeading(font)
        self.lineHeight = ascent + descent + leading
        self.capHeight = CTFontGetCapHeight(font)
        self.xHeight = CTFontGetXHeight(font)
    }
}

// MARK: - Text Utilities

extension TextEngine {
    
    func getLineHeight(for font: CTFont) -> CGFloat {
        let metrics = TextMetrics(font: font)
        return metrics.lineHeight
    }
    
    func wordWrapText(_ text: String, font: CTFont, maxWidth: CGFloat) -> [String] {
        let words = text.components(separatedBy: .whitespaces)
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            let testSize = measureText(testLine, font: font, maxWidth: maxWidth)
            
            if testSize.width <= maxWidth {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
    
    func truncateText(_ text: String, font: CTFont, maxWidth: CGFloat, truncationMode: TruncationMode = .tail) -> String {
        let fullSize = measureText(text, font: font, maxWidth: CGFloat.greatestFiniteMagnitude)
        
        if fullSize.width <= maxWidth {
            return text
        }
        
        let ellipsis = "…"
        let ellipsisSize = measureText(ellipsis, font: font, maxWidth: CGFloat.greatestFiniteMagnitude)
        let availableWidth = maxWidth - ellipsisSize.width
        
        switch truncationMode {
        case .head:
            return truncateFromHead(text, font: font, availableWidth: availableWidth) + ellipsis
        case .middle:
            return truncateFromMiddle(text, font: font, availableWidth: availableWidth, ellipsis: ellipsis)
        case .tail:
            return truncateFromTail(text, font: font, availableWidth: availableWidth) + ellipsis
        }
    }
    
    private func truncateFromTail(_ text: String, font: CTFont, availableWidth: CGFloat) -> String {
        var truncated = text
        
        while !truncated.isEmpty {
            let size = measureText(truncated, font: font, maxWidth: CGFloat.greatestFiniteMagnitude)
            if size.width <= availableWidth {
                return truncated
            }
            truncated = String(truncated.dropLast())
        }
        
        return truncated
    }
    
    private func truncateFromHead(_ text: String, font: CTFont, availableWidth: CGFloat) -> String {
        var truncated = text
        
        while !truncated.isEmpty {
            let size = measureText(truncated, font: font, maxWidth: CGFloat.greatestFiniteMagnitude)
            if size.width <= availableWidth {
                return truncated
            }
            truncated = String(truncated.dropFirst())
        }
        
        return truncated
    }
    
    private func truncateFromMiddle(_ text: String, font: CTFont, availableWidth: CGFloat, ellipsis: String) -> String {
        if text.count <= 2 {
            return text
        }
        
        let midPoint = text.count / 2
        var startIndex = 0
        var endIndex = text.count
        
        while startIndex < midPoint && endIndex > midPoint {
            let startText = String(text.prefix(startIndex))
            let endText = String(text.suffix(text.count - endIndex))
            let testText = startText + ellipsis + endText
            
            let size = measureText(testText, font: font, maxWidth: CGFloat.greatestFiniteMagnitude)
            if size.width <= availableWidth {
                return testText
            }
            
            if startIndex < midPoint {
                endIndex -= 1
            } else {
                startIndex += 1
            }
        }
        
        return ellipsis
    }
}

enum TruncationMode {
    case head
    case middle
    case tail
}
