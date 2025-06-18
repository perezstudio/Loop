//
//  ComputedStyle.swift
//  Loop - WebKit-Inspired Computed Style System
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Computed Style

struct ComputedStyle {
    
    // MARK: - Font Properties
    
    var fontSize: FontSizeValue = .absolute(16)
    var fontWeight: FontWeightValue = .normal
    var fontStyle: FontStyleValue = .normal
    var fontFamily: FontFamilyValue = .generic(.sansSerif)
    var lineHeight: LineHeightValue = .normal
    
    // MARK: - Color Properties
    
    var color: CSSColor = .named("black")
    var backgroundColor: CSSColor = .transparent
    var borderColor: CSSColor = .named("black")
    
    // MARK: - Box Model Properties
    
    var display: DisplayValue = .block
    var position: PositionValue = .static
    var width: LengthValue = .auto
    var height: LengthValue = .auto
    var minWidth: LengthValue = .length(0, .px)
    var minHeight: LengthValue = .length(0, .px)
    var maxWidth: LengthValue = .none
    var maxHeight: LengthValue = .none
    
    // MARK: - Margin Properties
    
    var marginTop: LengthValue = .length(0, .px)
    var marginRight: LengthValue = .length(0, .px)
    var marginBottom: LengthValue = .length(0, .px)
    var marginLeft: LengthValue = .length(0, .px)
    
    // MARK: - Padding Properties
    
    var paddingTop: LengthValue = .length(0, .px)
    var paddingRight: LengthValue = .length(0, .px)
    var paddingBottom: LengthValue = .length(0, .px)
    var paddingLeft: LengthValue = .length(0, .px)
    
    // MARK: - Border Properties
    
    var borderTopWidth: LengthValue = .length(0, .px)
    var borderRightWidth: LengthValue = .length(0, .px)
    var borderBottomWidth: LengthValue = .length(0, .px)
    var borderLeftWidth: LengthValue = .length(0, .px)
    
    var borderTopStyle: BorderStyleValue = .none
    var borderRightStyle: BorderStyleValue = .none
    var borderBottomStyle: BorderStyleValue = .none
    var borderLeftStyle: BorderStyleValue = .none
    
    // MARK: - Text Properties
    
    var textAlign: TextAlignValue = .start
    var textDecoration: TextDecorationValue = .none
    var textTransform: TextTransformValue = .none
    var whiteSpace: WhiteSpaceValue = .normal
    var overflow: OverflowValue = .visible
    
    // MARK: - Layout Properties
    
    var flexDirection: FlexDirectionValue = .row
    var justifyContent: JustifyContentValue = .flexStart
    var alignItems: AlignItemsValue = .stretch
    var flexWrap: FlexWrapValue = .nowrap
    
    // MARK: - Inheritance
    
    mutating func inherit(from parent: ComputedStyle) {
        // Font properties are inherited
        self.fontSize = parent.fontSize
        self.fontWeight = parent.fontWeight
        self.fontStyle = parent.fontStyle
        self.fontFamily = parent.fontFamily
        self.lineHeight = parent.lineHeight
        
        // Color properties are inherited
        self.color = parent.color
        
        // Text properties are inherited
        self.textAlign = parent.textAlign
        self.textTransform = parent.textTransform
        self.whiteSpace = parent.whiteSpace
    }
    
    // MARK: - Computed Values
    
    func resolvedFontSize() -> CGFloat {
        switch fontSize {
        case .absolute(let value):
            return value
        case .relative(let value, let unit):
            // This should be resolved by the style engine
            return value * 16 // Fallback
        case .keyword(let keyword):
            return keywordToFontSize(keyword)
        }
    }
    
    func resolvedColor() -> CGColor {
        return color.cgColor
    }
    
    func resolvedBackgroundColor() -> CGColor {
        return backgroundColor.cgColor
    }
    
    private func keywordToFontSize(_ keyword: String) -> CGFloat {
        switch keyword.lowercased() {
        case "xx-small": return 9
        case "x-small": return 10
        case "small": return 13
        case "medium": return 16
        case "large": return 18
        case "x-large": return 24
        case "xx-large": return 32
        default: return 16
        }
    }
    
    // MARK: - Debug Description
    
    var debugDescription: String {
        return """
        ComputedStyle {
            fontSize: \(fontSize),
            fontWeight: \(fontWeight),
            color: \(color),
            backgroundColor: \(backgroundColor),
            display: \(display),
            width: \(width),
            height: \(height),
            margin: \(marginTop) \(marginRight) \(marginBottom) \(marginLeft),
            padding: \(paddingTop) \(paddingRight) \(paddingBottom) \(paddingLeft)
        }
        """
    }
}

// MARK: - CSS Value Types

enum FontSizeValue {
    case absolute(CGFloat)
    case relative(CGFloat, RelativeUnit)
    case keyword(String)
    
    enum RelativeUnit {
        case em, rem, percent
    }
}

enum FontWeightValue {
    case normal, bold, bolder, lighter
    case numeric(Int) // 100-900
    
    var weight: Font.Weight {
        switch self {
        case .normal: return .regular
        case .bold: return .bold
        case .bolder: return .heavy
        case .lighter: return .light
        case .numeric(let value):
            switch value {
            case 100: return .ultraLight
            case 200: return .thin
            case 300: return .light
            case 400: return .regular
            case 500: return .medium
            case 600: return .semibold
            case 700: return .bold
            case 800: return .heavy
            case 900: return .black
            default: return .regular
            }
        }
    }
}

enum FontStyleValue {
    case normal, italic, oblique
}

enum FontFamilyValue {
    case named([String])
    case generic(GenericFamily)
    
    enum GenericFamily {
        case serif, sansSerif, monospace, cursive, fantasy
    }
}

enum LineHeightValue {
    case normal
    case length(CGFloat, CSSValue.LengthUnit)
    case percentage(CGFloat)
    case number(CGFloat)
}

enum DisplayValue {
    case none, block, inline, inlineBlock, flex, grid, table, tableRow, tableCell
}

enum PositionValue {
    case `static`, relative, absolute, fixed, sticky
}

enum LengthValue {
    case auto
    case length(CGFloat, CSSValue.LengthUnit)
    case percentage(CGFloat)
    case none
    
    func resolveLength(relativeTo containerSize: CGFloat, fontSize: CGFloat = 16) -> CGFloat? {
        switch self {
        case .auto, .none:
            return nil
        case .length(let value, let unit):
            switch unit {
            case .px:
                return value
            case .em:
                return value * fontSize
            case .rem:
                return value * 16 // Root font size
            case .vw:
                return value * containerSize / 100
            case .vh:
                return value * containerSize / 100
            case .pt:
                return value * 4/3 // 1pt = 4/3px
            case .inch:
                return value * 96 // 1in = 96px
            default:
                return value // Fallback for other units
            }
        case .percentage(let value):
            return value * containerSize / 100
        }
    }
}

enum BorderStyleValue {
    case none, solid, dashed, dotted, double, groove, ridge, inset, outset
}

enum TextAlignValue {
    case start, end, left, right, center, justify
}

enum TextDecorationValue {
    case none, underline, overline, lineThrough
}

enum TextTransformValue {
    case none, uppercase, lowercase, capitalize
}

enum WhiteSpaceValue {
    case normal, nowrap, pre, preWrap, preLine
}

enum OverflowValue {
    case visible, hidden, scroll, auto
}

enum FlexDirectionValue {
    case row, rowReverse, column, columnReverse
}

enum JustifyContentValue {
    case flexStart, flexEnd, center, spaceBetween, spaceAround, spaceEvenly
}

enum AlignItemsValue {
    case stretch, flexStart, flexEnd, center, baseline
}

enum FlexWrapValue {
    case nowrap, wrap, wrapReverse
}
