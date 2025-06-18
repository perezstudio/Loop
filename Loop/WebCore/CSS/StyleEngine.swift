//
//  StyleEngine.swift
//  Loop - WebKit-Inspired CSS Style Engine
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Style Engine Delegate

protocol StyleEngineDelegate: AnyObject {
    func styleEngineDidUpdateStyles(_ engine: StyleEngine)
}

// MARK: - Style Engine

class StyleEngine {
    
    // MARK: - Properties
    
    private let configuration: WebCore.Configuration
    private let cssParser: WebCoreCSS3Parser
    private let selectorEngine: SelectorEngine
    private let cascade: WebCoreCascadeResolver
    
    // Style data
    private var stylesheets: [WebCore.Stylesheet] = []
    private var computedStyleCache: [NodeID: ComputedStyle] = [:]
    private var selectorMatches: [NodeID: [WebCore.Rule]] = [:]
    
    weak var delegate: StyleEngineDelegate?
    
    // MARK: - Initialization
    
    init(configuration: WebCore.Configuration) {
        self.configuration = configuration
        self.cssParser = WebCoreCSS3Parser()
        self.selectorEngine = SelectorEngine()
        self.cascade = WebCoreCascadeResolver()
        
        // Add default user agent stylesheet
        addUserAgentStylesheet()
        
        print("🎨 Style Engine initialized")
    }
    
    // MARK: - Stylesheet Management
    
    private func addUserAgentStylesheet() {
        let userAgentCSS = """
        html, body, div, span, h1, h2, h3, h4, h5, h6, p, a, img, ul, ol, li, table, tr, td, th {
            margin: 0;
            padding: 0;
            border: 0;
            font-size: 100%;
            font: inherit;
            vertical-align: baseline;
        }
        
        body {
            line-height: 1;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 16px;
            color: black;
        }
        
        h1 { font-size: 2em; font-weight: bold; margin: 0.67em 0; }
        h2 { font-size: 1.5em; font-weight: bold; margin: 0.75em 0; }
        h3 { font-size: 1.17em; font-weight: bold; margin: 0.83em 0; }
        h4 { font-size: 1em; font-weight: bold; margin: 1.12em 0; }
        h5 { font-size: 0.83em; font-weight: bold; margin: 1.5em 0; }
        h6 { font-size: 0.75em; font-weight: bold; margin: 1.67em 0; }
        
        p { margin: 1em 0; }
        a { color: blue; text-decoration: underline; }
        strong, b { font-weight: bold; }
        em, i { font-style: italic; }
        
        ul, ol { margin: 1em 0; padding-left: 2em; }
        li { margin: 0.5em 0; }
        
        table { border-collapse: collapse; }
        td, th { padding: 4px; border: 1px solid #ccc; }
        th { font-weight: bold; background-color: #f0f0f0; }
        
        img { display: inline-block; }
        input, button, select, textarea { font-family: inherit; font-size: inherit; }
        """
        
        do {
            let stylesheet = try cssParser.parseStylesheet(userAgentCSS, origin: .userAgent)
            stylesheets.append(stylesheet)
        } catch {
            print("❌ Failed to parse user agent stylesheet: \(error)")
        }
    }
    
    func addStylesheet(_ css: String, origin: WebCore.StyleOrigin = .author) throws {
        let stylesheet = try cssParser.parseStylesheet(css, origin: origin)
        stylesheets.append(stylesheet)
        invalidateStyles()
    }
    
    // MARK: - Style Processing
    
    func processStyles(document: WebCoreDocument) async {
        print("🎨 Processing styles for document...")
        
        // Clear caches
        computedStyleCache.removeAll()
        selectorMatches.removeAll()
        
        // Extract and parse document styles
        if let cssContent = document.documentElement?.getAttribute("__internal_css"), !cssContent.isEmpty {
            do {
                try addStylesheet(cssContent, origin: .author)
            } catch {
                print("❌ Failed to parse document styles: \(error)")
            }
        }
        
        // Process all elements
        if let documentElement = document.documentElement {
            await processElementStyles(documentElement)
        }
        
        delegate?.styleEngineDidUpdateStyles(self)
        print("✅ Style processing completed")
    }
    
    private func processElementStyles(_ element: WebCoreElement) async {
        // Match selectors for this element
        let matchingRules = matchSelectors(for: element)
        selectorMatches[element.id] = matchingRules
        
        // Compute styles
        let computedStyle = computeStyle(for: element, matchingRules: matchingRules)
        computedStyleCache[element.id] = computedStyle
        
        // Process children
        for child in element.children {
            await processElementStyles(child)
        }
    }
    
    private func matchSelectors(for element: WebCoreElement) -> [WebCore.Rule] {
        var matchingRules: [WebCore.Rule] = []
        
        for stylesheet in stylesheets {
            for rule in stylesheet.rules {
                if selectorEngine.matches(element, selector: rule.selector) {
                    matchingRules.append(rule)
                }
            }
        }
        
        // Sort by specificity
        matchingRules.sort { rule1, rule2 in
            let spec1 = selectorEngine.calculateSpecificity(rule1.selector)
            let spec2 = selectorEngine.calculateSpecificity(rule2.selector)
            return spec1 < spec2
        }
        
        return matchingRules
    }
    
    private func computeStyle(for element: WebCoreElement, matchingRules: [WebCore.Rule]) -> ComputedStyle {
        var computedStyle = ComputedStyle()
        
        // Start with inherited values from parent
        if let parent = element.parentNode as? WebCoreElement,
           let parentStyle = getComputedStyle(for: parent) {
            computedStyle.inherit(from: parentStyle)
        }
        
        // Apply matching CSS rules in cascade order
        for rule in matchingRules {
            cascade.apply(rule.declarations, to: &computedStyle, origin: rule.origin)
        }
        
        // Apply inline styles (highest specificity)
        if let styleAttr = element.getAttribute("style") {
            do {
                let inlineDeclarations = try cssParser.parseInlineStyle(styleAttr)
                cascade.apply(inlineDeclarations, to: &computedStyle, origin: .author)
            } catch {
                print("❌ Failed to parse inline style: \(error)")
            }
        }
        
        // Resolve computed values
        resolveComputedValues(&computedStyle, element: element)
        
        return computedStyle
    }
    
    private func resolveComputedValues(_ style: inout ComputedStyle, element: WebCoreElement) {
        // Resolve font-size
        if case .relative(let value, let unit) = style.fontSize {
            switch unit {
            case .em:
                if let parent = element.parentNode as? WebCoreElement,
                   let parentStyle = getComputedStyle(for: parent),
                   case .absolute(let parentSize) = parentStyle.fontSize {
                    style.fontSize = .absolute(value * parentSize)
                } else {
                    style.fontSize = .absolute(value * 16) // Default base size
                }
            case .rem:
                style.fontSize = .absolute(value * 16) // Root em
            case .percent:
                if let parent = element.parentNode as? WebCoreElement,
                   let parentStyle = getComputedStyle(for: parent),
                   case .absolute(let parentSize) = parentStyle.fontSize {
                    style.fontSize = .absolute((value / 100) * parentSize)
                } else {
                    style.fontSize = .absolute((value / 100) * 16)
                }
            default:
                break
            }
        }
        
        // Resolve other relative values as needed
        resolveColors(&style)
        resolveDimensions(&style)
    }
    
    private func resolveColors(_ style: inout ComputedStyle) {
        // Resolve currentColor and other special color values
        if case .currentColor = style.borderColor {
            style.borderColor = style.color
        }
        
        if case .currentColor = style.backgroundColor {
            style.backgroundColor = style.color
        }
    }
    
    private func resolveDimensions(_ style: inout ComputedStyle) {
        // Resolve auto values and percentages
        // This would be expanded based on layout context
    }
    
    // MARK: - Public API
    
    func getComputedStyle(for element: WebCoreElement) -> ComputedStyle? {
        return computedStyleCache[element.id]
    }
    
    func getMatchingRules(for element: WebCoreElement) -> [WebCore.Rule] {
        return selectorMatches[element.id] ?? []
    }
    
    func invalidateStyles() {
        computedStyleCache.removeAll()
        selectorMatches.removeAll()
        delegate?.styleEngineDidUpdateStyles(self)
    }
    
    func invalidateElement(_ element: WebCoreElement) {
        computedStyleCache.removeValue(forKey: element.id)
        selectorMatches.removeValue(forKey: element.id)
        
        // Invalidate descendants that might inherit from this element
        invalidateDescendants(of: element)
    }
    
    private func invalidateDescendants(of element: WebCoreElement) {
        for child in element.children {
            computedStyleCache.removeValue(forKey: child.id)
            selectorMatches.removeValue(forKey: child.id)
            invalidateDescendants(of: child)
        }
    }
    
    // MARK: - Debug Support
    
    func getStyleDebugInfo(for element: WebCoreElement) -> [String: Any] {
        var info: [String: Any] = [:]
        
        info["tagName"] = element.tagName
        info["id"] = element.getAttribute("id") ?? "none"
        info["class"] = element.getAttribute("class") ?? "none"
        
        if let computedStyle = getComputedStyle(for: element) {
            info["computedStyle"] = computedStyle.debugDescription
        }
        
        let matchingRules = getMatchingRules(for: element)
        info["matchingRules"] = matchingRules.map { rule in
            [
                "selector": rule.selector.description,
                "specificity": selectorEngine.calculateSpecificity(rule.selector),
                "origin": rule.origin.rawValue
            ]
        }
        
        return info
    }
    
    func printStyleDebugInfo(for element: WebCoreElement) {
        let info = getStyleDebugInfo(for: element)
        print("🔍 Style Debug Info for \(element.tagName):")
        for (key, value) in info {
            print("  \(key): \(value)")
        }
    }
}
