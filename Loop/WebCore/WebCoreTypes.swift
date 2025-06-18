//
//  WebCoreTypes.swift
//  Loop - Consolidated WebCore Type Definitions
//
//  Created by Assistant on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - WebCore Namespace

enum WebCore {
    
    // MARK: - Configuration
    
    struct Configuration {
        var enableJavaScript: Bool = true
        var enableGPUAcceleration: Bool = true
        var enableResourceCaching: Bool = true
        var maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
        var viewport: CGSize = CGSize(width: 1024, height: 768)
        
        // Performance settings
        var enableIncrementalLayout: Bool = true
        var enableLayerOptimization: Bool = true
        var maxRenderTreeDepth: Int = 1000
        
        // Debug settings
        var enableLayoutDebugging: Bool = false
        var enablePaintDebugging: Bool = false
        var enableRenderTreeLogging: Bool = false
        
        var userAgentString: String = "Loop Browser 1.0 (WebKit Compatible)"
        
        static let `default` = Configuration()
    }
    
    // MARK: - Layout Context
    
    struct LayoutContext {
        let viewport: CGRect
        let enableIncrementalLayout: Bool
        let enableDebugging: Bool
        
        init(viewport: CGRect, enableIncrementalLayout: Bool = true, enableDebugging: Bool = false) {
            self.viewport = viewport
            self.enableIncrementalLayout = enableIncrementalLayout
            self.enableDebugging = enableDebugging
        }
    }
    
    // MARK: - CSS Types
    
    struct Rule {
        let selector: Selector
        let declarations: [Declaration]
        let origin: StyleOrigin
        let important: Bool
        
        init(selector: Selector, declarations: [Declaration], origin: StyleOrigin, important: Bool = false) {
            self.selector = selector
            self.declarations = declarations
            self.origin = origin
            self.important = important
        }
    }
    
    struct Selector {
        let raw: String
        let components: [SelectorComponent]
        
        init(raw: String, components: [SelectorComponent] = []) {
            self.raw = raw
            self.components = components
        }
        
        var description: String {
            return raw
        }
    }
    
    enum SelectorComponent {
        case universal
        case type(String)
        case id(String)
        case className(String)
        case attribute(String, operator: AttributeOperator?, value: String?)
        case pseudoClass(String)
        case pseudoElement(String)
        
        enum AttributeOperator {
            case equals, contains, dashMatch, prefixMatch, suffixMatch, substringMatch
        }
    }
    
    struct Declaration {
        let property: String
        let value: Value
        let important: Bool
        
        init(property: String, value: Value, important: Bool = false) {
            self.property = property
            self.value = value
            self.important = important
        }
    }
    
    enum Value {
        case keyword(String)
        case length(CGFloat, LengthUnit)
        case percentage(CGFloat)
        case color(Color)
        case number(CGFloat)
        case string(String)
        case url(URL)
        case function(String, [Value])
        case list([Value])
        
        enum LengthUnit: String, CaseIterable {
            case px, em, rem, pt, pc, inch, cm, mm, ex, ch, vw, vh, vmin, vmax
        }
    }
    
    enum Color: Equatable {
        case named(String)
        case hex(String)
        case rgb(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)
        case hsl(hue: CGFloat, saturation: CGFloat, lightness: CGFloat, alpha: CGFloat)
        case currentColor
        case transparent
        
        var cgColor: CGColor {
            switch self {
            case .named(let name):
                return namedColorToCGColor(name)
            case .hex(let hex):
                return hexToCGColor(hex)
            case .rgb(let r, let g, let b, let a):
                return CGColor(red: r, green: g, blue: b, alpha: a)
            case .hsl(let h, let s, let l, let a):
                return hslToCGColor(h: h, s: s, l: l, a: a)
            case .currentColor:
                return CGColor.black
            case .transparent:
                return CGColor(red: 0, green: 0, blue: 0, alpha: 0)
            }
        }
        
        private func namedColorToCGColor(_ name: String) -> CGColor {
            switch name.lowercased() {
            case "black": return CGColor.black
            case "white": return CGColor.white
            case "red": return CGColor(red: 1, green: 0, blue: 0, alpha: 1)
            case "green": return CGColor(red: 0, green: 1, blue: 0, alpha: 1)
            case "blue": return CGColor(red: 0, green: 0, blue: 1, alpha: 1)
            default: return CGColor.black
            }
        }
        
        private func hexToCGColor(_ hex: String) -> CGColor {
            var hexString = hex
            if hexString.hasPrefix("#") {
                hexString.removeFirst()
            }
            
            if hexString.count == 3 {
                hexString = String(hexString.flatMap { [$0, $0] })
            }
            
            guard hexString.count == 6, let hexValue = UInt32(hexString, radix: 16) else {
                return CGColor.black
            }
            
            let red = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat(hexValue & 0x0000FF) / 255.0
            
            return CGColor(red: red, green: green, blue: blue, alpha: 1.0)
        }
        
        private func hslToCGColor(h: CGFloat, s: CGFloat, l: CGFloat, a: CGFloat) -> CGColor {
            let c = (1 - abs(2 * l - 1)) * s
            let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
            let m = l - c / 2
            
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            
            if h < 60 {
                r = c; g = x; b = 0
            } else if h < 120 {
                r = x; g = c; b = 0
            } else if h < 180 {
                r = 0; g = c; b = x
            } else if h < 240 {
                r = 0; g = x; b = c
            } else if h < 300 {
                r = x; g = 0; b = c
            } else {
                r = c; g = 0; b = x
            }
            
            return CGColor(red: r + m, green: g + m, blue: b + m, alpha: a)
        }
    }
    
    enum StyleOrigin: String, CaseIterable {
        case userAgent = "user-agent"
        case user = "user"
        case author = "author"
        
        var cascadePriority: Int {
            switch self {
            case .userAgent: return 0
            case .user: return 1
            case .author: return 2
            }
        }
    }
    
    struct Stylesheet {
        let rules: [Rule]
        let origin: StyleOrigin
        let href: URL?
        
        init(rules: [Rule], origin: StyleOrigin, href: URL? = nil) {
            self.rules = rules
            self.origin = origin
            self.href = href
        }
    }
}

// MARK: - Type Aliases for Compatibility

typealias WebCoreConfiguration = WebCore.Configuration
typealias CSSStylesheet = WebCore.Stylesheet
typealias WebCoreCSSRule = WebCore.Rule  // Use WebCoreCSSRule to distinguish from legacy CSSRule
typealias CSSSelector = WebCore.Selector
typealias CSSDeclaration = WebCore.Declaration
typealias CSSValue = WebCore.Value
typealias CSSColor = WebCore.Color
typealias StyleOrigin = WebCore.StyleOrigin
typealias SelectorComponent = WebCore.SelectorComponent

// CSS Engine type aliases
typealias CSS3Parser = WebCoreCSS3Parser
typealias CascadeResolver = WebCoreCascadeResolver

// MARK: - Legacy Support
// These maintain compatibility with existing DOMNode.swift and other legacy files

// Redefining EdgeInsets to avoid conflicts
#if canImport(AppKit)
import AppKit
typealias WebCoreEdgeInsets = NSEdgeInsets
#else
struct WebCoreEdgeInsets {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat
    
    init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}
#endif

// Legacy CSS Style for existing code compatibility
struct LegacyCSSStyle {
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
}

// Legacy CSS Parser
class LegacyCSSParser {
    func parseInlineStyle(_ styleString: String) -> LegacyCSSStyle {
        var style = LegacyCSSStyle()
        
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
    
    private func applyProperty(_ property: String, value: String, to style: inout LegacyCSSStyle) {
        switch property {
        case "font-size":
            style.fontSize = parseFontSize(value)
        case "color":
            style.color = parseColor(value)
        case "background-color":
            style.backgroundColor = parseColor(value)
        default:
            break
        }
    }
    
    private func parseFontSize(_ value: String) -> CGFloat? {
        if value.hasSuffix("px") {
            let numberString = String(value.dropLast(2))
            return Double(numberString).map { CGFloat($0) }
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
}
