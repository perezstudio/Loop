//
//  NativeRenderingEngine.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import CoreText
import AppKit
import SwiftUI

// MARK: - Rendering Context

struct RenderContext {
    let cgContext: CGContext
    let viewport: CGRect
    let scaleFactor: CGFloat
    let backgroundColor: CGColor
    
    init(cgContext: CGContext, viewport: CGRect, scaleFactor: CGFloat = 1.0, backgroundColor: CGColor = CGColor.white) {
        self.cgContext = cgContext
        self.viewport = viewport
        self.scaleFactor = scaleFactor
        self.backgroundColor = backgroundColor
    }
}

// MARK: - Render Tree Node

class RenderNode {
    let domNode: DOMNode
    var frame: CGRect = .zero
    var computedStyle: CSSStyle = CSSStyle()
    var children: [RenderNode] = []
    weak var parent: RenderNode?
    
    // Rendering properties
    var needsRepaint: Bool = true
    var cachedLayer: CGLayer?
    
    init(domNode: DOMNode) {
        self.domNode = domNode
    }
    
    func appendChild(_ child: RenderNode) {
        child.parent = self
        children.append(child)
    }
    
    func invalidate() {
        needsRepaint = true
        cachedLayer = nil
        parent?.invalidate()
    }
}

// MARK: - Native Rendering Engine

class NativeRenderingEngine {
    private let htmlParser: EnhancedHTMLParser
    private let cssEngine: CSSEngine
    private let layoutEngine: NativeLayoutEngine
    private let paintEngine: PaintEngine
    private let textEngine: TextEngine
    
    private var renderTree: RenderNode?
    private var viewport: CGRect = .zero
    
    init() {
        self.htmlParser = EnhancedHTMLParser()
        self.cssEngine = CSSEngine()
        self.layoutEngine = NativeLayoutEngine()
        self.paintEngine = PaintEngine()
        self.textEngine = TextEngine()
    }
    
    // MARK: - Main Rendering Pipeline
    
    func loadHTML(_ html: String, viewport: CGRect) {
        self.viewport = viewport
        
        // 1. Parse HTML to DOM
        let domRoot = htmlParser.parse(html)
        
        // 2. Extract CSS rules
        let cssRules = domRoot.extractStylesheets()
        
        // 3. Build render tree
        renderTree = buildRenderTree(from: domRoot, cssRules: cssRules)
        
        // 4. Layout
        if let renderTree = renderTree {
            layoutEngine.layout(renderTree, in: viewport)
        }
    }
    
    func render(to context: CGContext) -> Bool {
        guard let renderTree = renderTree else { return false }
        
        let renderContext = RenderContext(
            cgContext: context,
            viewport: viewport,
            scaleFactor: 1.0
        )
        
        // Clear background
        context.setFillColor(renderContext.backgroundColor)
        context.fill(viewport)
        
        // Paint render tree
        paintEngine.paint(renderTree, context: renderContext)
        
        return true
    }
    
    func createImage() -> CGImage? {
        guard renderTree != nil else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(viewport.width),
            height: Int(viewport.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        // Flip coordinate system for proper rendering
        context.translateBy(x: 0, y: viewport.height)
        context.scaleBy(x: 1, y: -1)
        
        _ = render(to: context)
        
        return context.makeImage()
    }
    
    // MARK: - Render Tree Building
    
    private func buildRenderTree(from domNode: DOMNode, cssRules: [CSSRule]) -> RenderNode? {
        guard shouldCreateRenderNode(for: domNode) else { return nil }
        
        let renderNode = RenderNode(domNode: domNode)
        
        // Compute styles
        renderNode.computedStyle = cssEngine.computeStyle(
            for: domNode,
            rules: cssRules,
            parent: nil
        )
        
        // Process children
        for childDOM in domNode.children {
            if let childRender = buildRenderTree(from: childDOM, cssRules: cssRules) {
                renderNode.appendChild(childRender)
            }
        }
        
        return renderNode
    }
    
    private func shouldCreateRenderNode(for domNode: DOMNode) -> Bool {
        // Skip invisible or irrelevant nodes
        guard let tagName = domNode.tagName?.lowercased() else {
            // Include text nodes
            return domNode.textContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        
        // Skip these elements
        let skipTags = ["head", "script", "style", "meta", "link", "title"]
        return !skipTags.contains(tagName)
    }
    
    // MARK: - Hit Testing & Interaction
    
    func hitTest(_ point: CGPoint) -> RenderNode? {
        guard let renderTree = renderTree else { return nil }
        return hitTestRecursive(renderTree, point: point)
    }
    
    private func hitTestRecursive(_ node: RenderNode, point: CGPoint) -> RenderNode? {
        guard node.frame.contains(point) else { return nil }
        
        // Check children first (front to back)
        for child in node.children.reversed() {
            if let hit = hitTestRecursive(child, point: point) {
                return hit
            }
        }
        
        return node
    }
}

// MARK: - CSS Engine

class CSSEngine {
    func computeStyle(for domNode: DOMNode, rules: [CSSRule], parent: RenderNode?) -> CSSStyle {
        var style = getDefaultStyle(for: domNode)
        
        // Apply CSS rules
        for rule in rules {
            if matchesSelector(domNode, selector: rule.selector) {
                style = mergeStyles(style, rule.style)
            }
        }
        
        // Apply inline styles
        style = mergeStyles(style, domNode.inlineStyle)
        
        // Apply inheritance
        if let parentStyle = parent?.computedStyle {
            style = applyInheritance(style, from: parentStyle)
        }
        
        return style
    }
    
    private func getDefaultStyle(for domNode: DOMNode) -> CSSStyle {
        var style = CSSStyle()
        style.fontSize = 16
        style.color = .black
        style.fontWeight = .regular
        
        guard let tagName = domNode.tagName?.lowercased() else { return style }
        
        switch tagName {
        case "h1":
            style.fontSize = 32
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 21, leading: 0, bottom: 21, trailing: 0)
        case "h2":
            style.fontSize = 24
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 19, leading: 0, bottom: 19, trailing: 0)
        case "h3":
            style.fontSize = 19
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        case "p":
            style.margin = EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        case "strong", "b":
            style.fontWeight = .bold
        case "a":
            style.color = .blue
        case "ul", "ol":
            style.margin = EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
            style.padding = EdgeInsets(top: 0, leading: 40, bottom: 0, trailing: 0)
        default:
            break
        }
        
        return style
    }
    
    private func matchesSelector(_ domNode: DOMNode, selector: String) -> Bool {
        let trimmedSelector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let tagName = domNode.tagName, trimmedSelector == tagName.lowercased() {
            return true
        }
        
        if trimmedSelector.hasPrefix(".") {
            let className = String(trimmedSelector.dropFirst())
            if let classAttr = domNode.getAttribute("class") {
                return classAttr.components(separatedBy: .whitespaces).contains(className)
            }
        }
        
        if trimmedSelector.hasPrefix("#") {
            let idName = String(trimmedSelector.dropFirst())
            return domNode.getAttribute("id") == idName
        }
        
        return false
    }
    
    private func mergeStyles(_ base: CSSStyle, _ override: CSSStyle) -> CSSStyle {
        var merged = base
        if let fontSize = override.fontSize { merged.fontSize = fontSize }
        if let fontWeight = override.fontWeight { merged.fontWeight = fontWeight }
        if let color = override.color { merged.color = color }
        if let backgroundColor = override.backgroundColor { merged.backgroundColor = backgroundColor }
        if let margin = override.margin { merged.margin = margin }
        if let padding = override.padding { merged.padding = padding }
        if let textAlign = override.textAlign { merged.textAlign = textAlign }
        if let display = override.display { merged.display = display }
        return merged
    }
    
    private func applyInheritance(_ style: CSSStyle, from parentStyle: CSSStyle) -> CSSStyle {
        var inherited = style
        if inherited.fontSize == nil { inherited.fontSize = parentStyle.fontSize }
        if inherited.fontWeight == nil { inherited.fontWeight = parentStyle.fontWeight }
        if inherited.color == nil { inherited.color = parentStyle.color }
        return inherited
    }
}

// MARK: - Extensions

extension CSSStyle {
    var cgColor: CGColor {
        if let color = self.color {
            return color.cgColor ?? CGColor.black
        }
        return CGColor.black
    }
    
    var ctFont: CTFont {
        let fontSize = self.fontSize ?? 16
        let fontName = "Helvetica" // Could be expanded to support font-family
        
        // Create base font (CTFontCreateWithName always succeeds with system fonts)
        let baseFont = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        // Apply font weight if specified
        if let fontWeight = self.fontWeight {
            let traits: CTFontSymbolicTraits
            switch fontWeight {
            case .bold, .heavy, .black:
                traits = .boldTrait
            default:
                traits = []
            }
            
            if !traits.isEmpty {
                if let boldFont = CTFontCreateCopyWithSymbolicTraits(baseFont, fontSize, nil, traits, traits) {
                    return boldFont
                }
            }
        }
        
        return baseFont
    }
}

extension Color {
    var cgColor: CGColor? {
        // This is a simplified conversion - in a real implementation,
        // you'd need a more robust color conversion system
        switch self {
        case .black: return CGColor.black
        case .white: return CGColor.white
        case .red: return CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        case .blue: return CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        case .green: return CGColor(red: 0, green: 1, blue: 0, alpha: 1)
        default: return CGColor.black
        }
    }
}
