//
//  CSSLegacySupport.swift
//  Loop - Legacy CSS Support for Existing Code
//
//  Created by Assistant on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Legacy CSS Style for DOMNode compatibility

struct DOMCSSStyle {
    var fontSize: CGFloat?
    var fontWeight: Font.Weight?
    var color: SwiftUI.Color?
    var backgroundColor: SwiftUI.Color?
    var margin: WebCoreEdgeInsets?
    var padding: WebCoreEdgeInsets?
    var textAlign: TextAlignment?
    var display: DisplayType?
    
    enum DisplayType {
        case block, inline, inlineBlock, flex, none
    }
    
    static func makeDefault() -> DOMCSSStyle {
        return DOMCSSStyle()
    }
}

// MARK: - Legacy CSS Parser for existing code

struct DOMCSSParser {
    func parseInlineStyle(_ styleString: String) -> DOMCSSStyle {
        var style = DOMCSSStyle()
        
        let declarations = styleString.components(separatedBy: ";")
        
        for declaration in declarations {
            let parts = declaration.components(separatedBy: ":")
            guard parts.count == 2 else { continue }
            
            let property = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            applyProperty(property, value: value, to: &style)
        }
        
        return style
    }
    
    private func applyProperty(_ property: String, value: String, to style: inout DOMCSSStyle) {
        switch property {
        case "font-size":
            style.fontSize = parseFontSize(value)
        case "color":
            style.color = parseColor(value)
        case "background-color":
            style.backgroundColor = parseColor(value)
        case "display":
            style.display = parseDisplay(value)
        default:
            break
        }
    }
    
    private func parseFontSize(_ value: String) -> CGFloat? {
        if value.hasSuffix("px") {
            let numberString = String(value.dropLast(2))
            return Double(numberString).map { CGFloat($0) }
        } else if value.hasSuffix("em") {
            let numberString = String(value.dropLast(2))
            return Double(numberString).map { CGFloat($0 * 16) }
        }
        return nil
    }
    
    private func parseColor(_ value: String) -> SwiftUI.Color? {
        switch value.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "black": return .black
        case "white": return .white
        default: return nil
        }
    }
    
    private func parseDisplay(_ value: String) -> DOMCSSStyle.DisplayType? {
        switch value.lowercased() {
        case "block": return .block
        case "inline": return .inline
        case "inline-block": return .inlineBlock
        case "flex": return .flex
        case "none": return .none
        default: return nil
        }
    }
    
    static func makeDefault() -> DOMCSSParser {
        return DOMCSSParser()
    }
}

// MARK: - Type aliases for backward compatibility with existing DOMNode.swift
// Note: These are moved to CSSParser.swift to avoid conflicts
