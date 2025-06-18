//
//  CSSParser.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// Import shared types
// FontWeight enum is defined in NativeTypes.swift

// MARK: - CSS Structures

struct CSSStyle {
    var fontSize: CGFloat?
    var fontWeight: FontWeight?
    var color: Color?
    var backgroundColor: Color?
    var margin: EdgeInsets?
    var padding: EdgeInsets?
    var textAlign: TextAlignment?
    var display: DisplayType?
    
    enum DisplayType {
        case block, inline, inlineBlock, flex, none
    }
}

struct CSSRule {
    let selector: String
    let style: CSSStyle
}

// MARK: - CSS Parser

class CSSParser {
    
    func parseInlineStyle(_ styleString: String) -> CSSStyle {
        var style = CSSStyle()
        
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
    
    func parseStylesheet(_ css: String) -> [CSSRule] {
        var rules: [CSSRule] = []
        
        // Basic CSS parsing - this is simplified and doesn't handle all CSS syntax
        let rulePattern = #"([^{]+)\s*\{\s*([^}]+)\s*\}"#
        
        do {
            let regex = try NSRegularExpression(pattern: rulePattern, options: [])
            let matches = regex.matches(in: css, options: [], range: NSRange(location: 0, length: css.utf16.count))
            
            for match in matches {
                guard match.numberOfRanges >= 3,
                      let selectorRange = Range(match.range(at: 1), in: css),
                      let declarationsRange = Range(match.range(at: 2), in: css) else { continue }
                
                let selector = String(css[selectorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let declarations = String(css[declarationsRange])
                
                let style = parseInlineStyle(declarations)
                rules.append(CSSRule(selector: selector, style: style))
            }
        } catch {
            print("CSS parsing error: \(error)")
        }
        
        return rules
    }
    
    private func applyProperty(_ property: String, value: String, to style: inout CSSStyle) {
        switch property {
        case "font-size":
            style.fontSize = parseFontSize(value)
        case "font-weight":
            style.fontWeight = parseFontWeight(value)
        case "color":
            style.color = parseColor(value)
        case "background-color", "background":
            style.backgroundColor = parseColor(value)
        case "text-align":
            style.textAlign = parseTextAlign(value)
        case "display":
            style.display = parseDisplay(value)
        case "margin":
            style.margin = parseEdgeInsets(value)
        case "padding":
            style.padding = parseEdgeInsets(value)
        default:
            break
        }
    }
    
    private func parseFontSize(_ value: String) -> CGFloat? {
        let cleanValue = value.lowercased()
        
        // Handle common font size keywords
        switch cleanValue {
        case "xx-small": return 9
        case "x-small": return 10
        case "small": return 13
        case "medium": return 16
        case "large": return 18
        case "x-large": return 24
        case "xx-large": return 32
        default:
            break
        }
        
        // Handle numeric values
        if cleanValue.hasSuffix("px") {
            let numberString = String(cleanValue.dropLast(2))
            return Double(numberString).map { CGFloat($0) }
        } else if cleanValue.hasSuffix("em") {
            let numberString = String(cleanValue.dropLast(2))
            return Double(numberString).map { CGFloat($0 * 16) } // Assume base 16px
        } else if cleanValue.hasSuffix("rem") {
            let numberString = String(cleanValue.dropLast(3))
            return Double(numberString).map { CGFloat($0 * 16) } // Assume base 16px
        } else if let number = Double(cleanValue) {
            return CGFloat(number)
        }
        
        return nil
    }
    
    private func parseFontWeight(_ value: String) -> FontWeight? {
        let cleanValue = value.lowercased()
        
        switch cleanValue {
        case "normal", "400": return .regular
        case "bold", "700": return .bold
        case "bolder", "800", "900": return .heavy
        case "lighter", "100", "200", "300": return .light
        case "500": return .medium
        case "600": return .semibold
        default: return nil
        }
    }
    
    private func parseColor(_ value: String) -> Color? {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Handle named colors
        switch cleanValue {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "black": return .black
        case "white": return .white
        case "gray", "grey": return .gray
        case "brown": return .brown
        case "cyan": return .cyan
        case "mint": return .mint
        case "indigo": return .indigo
        case "teal": return .teal
        default:
            break
        }
        
        // Handle hex colors
        if cleanValue.hasPrefix("#") {
            return parseHexColor(cleanValue)
        }
        
        // Handle rgb colors
        if cleanValue.hasPrefix("rgb(") {
            return parseRGBColor(cleanValue)
        }
        
        return nil
    }
    
    private func parseHexColor(_ hex: String) -> Color? {
        var hexString = hex
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        
        // Handle 3-digit hex
        if hexString.count == 3 {
            hexString = String(hexString.flatMap { [$0, $0] })
        }
        
        guard hexString.count == 6,
              let hexValue = UInt32(hexString, radix: 16) else {
            return nil
        }
        
        let red = Double((hexValue & 0xFF0000) >> 16) / 255.0
        let green = Double((hexValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(hexValue & 0x0000FF) / 255.0
        
        return Color(red: red, green: green, blue: blue)
    }
    
    private func parseRGBColor(_ rgb: String) -> Color? {
        let pattern = #"rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: rgb, options: [], range: NSRange(location: 0, length: rgb.utf16.count))
            
            guard let match = matches.first,
                  match.numberOfRanges >= 4,
                  let redRange = Range(match.range(at: 1), in: rgb),
                  let greenRange = Range(match.range(at: 2), in: rgb),
                  let blueRange = Range(match.range(at: 3), in: rgb),
                  let red = Int(rgb[redRange]),
                  let green = Int(rgb[greenRange]),
                  let blue = Int(rgb[blueRange]) else {
                return nil
            }
            
            return Color(red: Double(red) / 255.0, green: Double(green) / 255.0, blue: Double(blue) / 255.0)
        } catch {
            return nil
        }
    }
    
    private func parseTextAlign(_ value: String) -> TextAlignment? {
        switch value.lowercased() {
        case "left": return .leading
        case "center": return .center
        case "right": return .trailing
        default: return nil
        }
    }
    
    private func parseDisplay(_ value: String) -> CSSStyle.DisplayType? {
        switch value.lowercased() {
        case "block": return .block
        case "inline": return .inline
        case "inline-block": return .inlineBlock
        case "flex": return .flex
        case "none": return CSSStyle.DisplayType.none
        default: return nil
        }
    }
    
    private func parseEdgeInsets(_ value: String) -> EdgeInsets? {
        let components = value.components(separatedBy: .whitespaces).compactMap { component in
            parseFontSize(component) // Reuse font size parsing for dimensions
        }
        
        switch components.count {
        case 1:
            let all = components[0]
            return EdgeInsets(top: all, leading: all, bottom: all, trailing: all)
        case 2:
            let vertical = components[0]
            let horizontal = components[1]
            return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
        case 4:
            return EdgeInsets(top: components[0], leading: components[3], bottom: components[2], trailing: components[1])
        default:
            return nil
        }
    }
}

// MARK: - SwiftUI Extensions

extension View {
    func applyCSS(_ style: CSSStyle) -> some View {
        self.modifier(CSSStyleModifier(style: style))
    }
}

struct CSSStyleModifier: ViewModifier {
    let style: CSSStyle
    
    func body(content: Content) -> some View {
        var modifiedContent = AnyView(content)
        
        // Apply font modifications
        if let fontSize = style.fontSize {
            let weight = style.fontWeight?.toSwiftUIWeight() ?? .regular
            modifiedContent = AnyView(modifiedContent.font(.system(size: fontSize, weight: weight)))
        } else if let fontWeight = style.fontWeight {
            // Apply font weight separately if no fontSize is specified
            modifiedContent = AnyView(modifiedContent.fontWeight(fontWeight.toSwiftUIWeight()))
        }
        
        // Apply color
        if let color = style.color {
            modifiedContent = AnyView(modifiedContent.foregroundColor(color))
        }
        
        // Apply padding
        if let padding = style.padding {
            modifiedContent = AnyView(modifiedContent.padding(.init(top: padding.top, leading: padding.leading, bottom: padding.bottom, trailing: padding.trailing)))
        }
        
        // Apply background color
        if let backgroundColor = style.backgroundColor {
            modifiedContent = AnyView(modifiedContent.background(backgroundColor))
        }
        
        return modifiedContent
    }
}
