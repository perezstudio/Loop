//
//  Element.swift
//  LoopEngine
//
//  DOM Element implementation with attribute management and styling
//

import Foundation

/// HTML Element implementation
public class Element: Node {
    
    // MARK: - Properties
    
    /// Element tag name (uppercase)
    public let tagName: String
    
    /// Element attributes
    private var attributes: [String: String] = [:]
    
    /// Class list for efficient class management
    private var classList: Set<String> = []
    
    /// Element ID
    public var id: String? {
        get { return getAttribute("id") }
        set { 
            if let value = newValue {
                setAttribute("id", value)
            } else {
                removeAttribute("id")
            }
        }
    }
    
    /// Element classes
    public var className: String {
        get { return classList.sorted().joined(separator: " ") }
        set { 
            classList.removeAll()
            let classes = newValue.split(separator: " ").map(String.init)
            for cls in classes {
                if !cls.isEmpty {
                    classList.insert(cls)
                }
            }
            markForStyleRecalc()
        }
    }
    
    // MARK: - Initialization
    
    public init(tagName: String, document: Document) {
        self.tagName = tagName.uppercased()
        super.init(nodeType: .element, document: document)
        
        // Set HTML element flag
        if HTMLElements.isHTMLElement(tagName) {
            flags.insert(.isHTMLElement)
        }
    }
    
    // MARK: - Node Overrides
    
    public override var nodeName: String {
        return tagName
    }
    
    // MARK: - Attribute Management
    
    /// Get attribute value
    public func getAttribute(_ name: String) -> String? {
        return attributes[name.lowercased()]
    }
    
    /// Set attribute value
    public func setAttribute(_ name: String, _ value: String) {
        let lowercaseName = name.lowercased()
        let oldValue = attributes[lowercaseName]
        attributes[lowercaseName] = value
        
        // Handle special attributes
        switch lowercaseName {
        case "class":
            parseClassAttribute(value)
        case "id":
            markForStyleRecalc()
        default:
            break
        }
        
        // Mark for style recalc if attribute changed
        if oldValue != value {
            markForStyleRecalc()
        }
    }
    
    /// Remove attribute
    public func removeAttribute(_ name: String) {
        let lowercaseName = name.lowercased()
        let hadAttribute = attributes.removeValue(forKey: lowercaseName) != nil
        
        // Handle special attributes
        switch lowercaseName {
        case "class":
            classList.removeAll()
        default:
            break
        }
        
        if hadAttribute {
            markForStyleRecalc()
        }
    }
    
    /// Check if attribute exists
    public func hasAttribute(_ name: String) -> Bool {
        return attributes[name.lowercased()] != nil
    }
    
    /// Get all attribute names
    public var attributeNames: [String] {
        return Array(attributes.keys)
    }
    
    /// Get all attributes
    public var attributeMap: [String: String] {
        return attributes
    }
    
    // MARK: - Class Management
    
    /// Parse class attribute string
    private func parseClassAttribute(_ value: String) {
        classList.removeAll()
        let classes = value.split(separator: " ").map(String.init)
        for cls in classes {
            if !cls.isEmpty {
                classList.insert(cls)
            }
        }
    }
    
    /// Add CSS class
    public func addClass(_ className: String) {
        if !className.isEmpty && !classList.contains(className) {
            classList.insert(className)
            updateClassAttribute()
            markForStyleRecalc()
        }
    }
    
    /// Remove CSS class
    public func removeClass(_ className: String) {
        if classList.remove(className) != nil {
            updateClassAttribute()
            markForStyleRecalc()
        }
    }
    
    /// Toggle CSS class
    public func toggleClass(_ className: String) -> Bool {
        if classList.contains(className) {
            removeClass(className)
            return false
        } else {
            addClass(className)
            return true
        }
    }
    
    /// Check if element has CSS class
    public func hasClass(_ className: String) -> Bool {
        return classList.contains(className)
    }
    
    /// Update class attribute from class set
    private func updateClassAttribute() {
        if classList.isEmpty {
            attributes.removeValue(forKey: "class")
        } else {
            attributes["class"] = classList.sorted().joined(separator: " ")
        }
    }
    
    // MARK: - Element Queries
    
    /// Get elements by tag name
    public func getElementsByTagName(_ tagName: String) -> [Element] {
        var result: [Element] = []
        let upperTagName = tagName.uppercased()
        
        traverseDescendants { node in
            if let element = node as? Element, element.tagName == upperTagName {
                result.append(element)
            }
            return true
        }
        
        return result
    }
    
    /// Get elements by class name
    public func getElementsByClassName(_ className: String) -> [Element] {
        var result: [Element] = []
        
        traverseDescendants { node in
            if let element = node as? Element, element.hasClass(className) {
                result.append(element)
            }
            return true
        }
        
        return result
    }
    
    /// Get element by ID
    public func getElementById(_ id: String) -> Element? {
        var result: Element?
        
        traverseDescendants { node in
            if let element = node as? Element, element.id == id {
                result = element
                return false // Stop traversal
            }
            return true
        }
        
        return result
    }
    
    // MARK: - Content Management
    
    /// Inner HTML content (simplified)
    public var innerHTML: String {
        get {
            // This would be implemented with a proper HTML serializer
            return textContent ?? ""
        }
        set {
            // This would be implemented with HTML parsing
            textContent = newValue
        }
    }
    
    /// Outer HTML content (simplified)
    public var outerHTML: String {
        get {
            // This would be implemented with a proper HTML serializer
            var html = "<\(tagName.lowercased())"
            
            // Add attributes
            for (name, value) in attributes.sorted(by: { $0.key < $1.key }) {
                html += " \(name)=\"\(value)\""
            }
            
            if hasChildNodes {
                html += ">\(innerHTML)</\(tagName.lowercased())>"
            } else {
                html += " />"
            }
            
            return html
        }
        set {
            // This would replace the element with parsed HTML
            // For now, just update text content
            textContent = newValue
        }
    }
    
    // MARK: - Element Relationships
    
    /// Get parent element (skipping non-element nodes)
    public var parentElement: Element? {
        var current = parentNode
        while let node = current {
            if let element = node as? Element {
                return element
            }
            current = node.parentNode
        }
        return nil
    }
    
    /// Get child elements (excluding text nodes, etc.)
    public var childElements: [Element] {
        return children.compactMap { $0 as? Element }
    }
    
    /// Get first child element
    public var firstElementChild: Element? {
        for child in children {
            if let element = child as? Element {
                return element
            }
        }
        return nil
    }
    
    /// Get last child element
    public var lastElementChild: Element? {
        var result: Element?
        for child in children {
            if let element = child as? Element {
                result = element
            }
        }
        return result
    }
    
    /// Get next sibling element
    public var nextElementSibling: Element? {
        var current = nextSibling
        while let node = current {
            if let element = node as? Element {
                return element
            }
            current = node.nextSibling
        }
        return nil
    }
    
    /// Get previous sibling element
    public var previousElementSibling: Element? {
        var current = previousSibling
        while let node = current {
            if let element = node as? Element {
                return element
            }
            current = node.previousSibling
        }
        return nil
    }
    
    /// Get element child count
    public var childElementCount: Int {
        return childElements.count
    }
    
    // MARK: - Style and Layout Hints
    
    /// Mark element as needing style recalculation
    public override func markForStyleRecalc() {
        super.markForStyleRecalc()
        
        // Also mark for layout if this could affect positioning
        if isDisplayAffectingElement() {
            markForLayoutUpdate()
        }
    }
    
    /// Check if element could affect display/layout
    private func isDisplayAffectingElement() -> Bool {
        // Common elements that affect layout
        switch tagName {
        case "DIV", "SPAN", "P", "H1", "H2", "H3", "H4", "H5", "H6",
             "UL", "OL", "LI", "TABLE", "TR", "TD", "TH", "SECTION",
             "ARTICLE", "HEADER", "FOOTER", "NAV", "ASIDE", "MAIN":
            return true
        default:
            return false
        }
    }
}

// MARK: - HTML Element Registry

/// Registry of known HTML elements
public enum HTMLElements {
    
    /// Standard HTML element names
    public static let standardElements: Set<String> = [
        "A", "ABBR", "ADDRESS", "AREA", "ARTICLE", "ASIDE", "AUDIO",
        "B", "BASE", "BDI", "BDO", "BLOCKQUOTE", "BODY", "BR", "BUTTON",
        "CANVAS", "CAPTION", "CITE", "CODE", "COL", "COLGROUP",
        "DATA", "DATALIST", "DD", "DEL", "DETAILS", "DFN", "DIALOG", "DIV", "DL", "DT",
        "EM", "EMBED",
        "FIELDSET", "FIGCAPTION", "FIGURE", "FOOTER", "FORM",
        "H1", "H2", "H3", "H4", "H5", "H6", "HEAD", "HEADER", "HGROUP", "HR", "HTML",
        "I", "IFRAME", "IMG", "INPUT", "INS",
        "KBD",
        "LABEL", "LEGEND", "LI", "LINK",
        "MAIN", "MAP", "MARK", "META", "METER",
        "NAV", "NOSCRIPT",
        "OBJECT", "OL", "OPTGROUP", "OPTION", "OUTPUT",
        "P", "PARAM", "PICTURE", "PRE", "PROGRESS",
        "Q",
        "RP", "RT", "RUBY",
        "S", "SAMP", "SCRIPT", "SECTION", "SELECT", "SLOT", "SMALL", "SOURCE", "SPAN",
        "STRONG", "STYLE", "SUB", "SUMMARY", "SUP",
        "TABLE", "TBODY", "TD", "TEMPLATE", "TEXTAREA", "TFOOT", "TH", "THEAD", "TIME", "TITLE", "TR", "TRACK",
        "U", "UL",
        "VAR", "VIDEO",
        "WBR"
    ]
    
    /// Check if tag name represents a standard HTML element
    public static func isHTMLElement(_ tagName: String) -> Bool {
        return standardElements.contains(tagName.uppercased())
    }
    
    /// Check if element is a void element (self-closing)
    public static func isVoidElement(_ tagName: String) -> Bool {
        let voidElements: Set<String> = [
            "AREA", "BASE", "BR", "COL", "EMBED", "HR", "IMG", "INPUT",
            "LINK", "META", "PARAM", "SOURCE", "TRACK", "WBR"
        ]
        return voidElements.contains(tagName.uppercased())
    }
    
    /// Check if element is a block-level element by default
    public static func isBlockElement(_ tagName: String) -> Bool {
        let blockElements: Set<String> = [
            "ADDRESS", "ARTICLE", "ASIDE", "BLOCKQUOTE", "DETAILS", "DIALOG", "DD", "DIV",
            "DL", "DT", "FIELDSET", "FIGCAPTION", "FIGURE", "FOOTER", "FORM", "H1", "H2",
            "H3", "H4", "H5", "H6", "HEADER", "HGROUP", "HR", "LI", "MAIN", "NAV", "OL",
            "P", "PRE", "SECTION", "TABLE", "UL"
        ]
        return blockElements.contains(tagName.uppercased())
    }
    
    /// Check if element is an inline element by default
    public static func isInlineElement(_ tagName: String) -> Bool {
        return isHTMLElement(tagName) && !isBlockElement(tagName) && !isVoidElement(tagName)
    }
}

// MARK: - Specialized Element Types

/// HTML Document element
public class HTMLElement: Element {
    
    public init(document: Document) {
        super.init(tagName: "HTML", document: document)
    }
}

/// Body element
public class BodyElement: Element {
    
    public init(document: Document) {
        super.init(tagName: "BODY", document: document)
    }
}

/// Head element
public class HeadElement: Element {
    
    public init(document: Document) {
        super.init(tagName: "HEAD", document: document)
    }
}

/// Title element
public class TitleElement: Element {
    
    public init(document: Document) {
        super.init(tagName: "TITLE", document: document)
    }
    
    /// Document title
    public var title: String {
        get { return textContent ?? "" }
        set { textContent = newValue }
    }
}

/// Script element
public class ScriptElement: Element {
    
    public init(document: Document) {
        super.init(tagName: "SCRIPT", document: document)
    }
    
    /// Script source URL
    public var src: String? {
        get { return getAttribute("src") }
        set {
            if let value = newValue {
                setAttribute("src", value)
            } else {
                removeAttribute("src")
            }
        }
    }
    
    /// Script type
    public var type: String? {
        get { return getAttribute("type") }
        set {
            if let value = newValue {
                setAttribute("type", value)
            } else {
                removeAttribute("type")
            }
        }
    }
    
    /// Async loading
    public var async: Bool {
        get { return hasAttribute("async") }
        set {
            if newValue {
                setAttribute("async", "")
            } else {
                removeAttribute("async")
            }
        }
    }
    
    /// Defer execution
    public var defer: Bool {
        get { return hasAttribute("defer") }
        set {
            if newValue {
                setAttribute("defer", "")
            } else {
                removeAttribute("defer")
            }
        }
    }
}

/// Link element (for stylesheets, etc.)
public class LinkElement: Element {
    
    public init(document: Document) {
        super.init(tagName: "LINK", document: document)
    }
    
    /// Link relationship
    public var rel: String? {
        get { return getAttribute("rel") }
        set {
            if let value = newValue {
                setAttribute("rel", value)
            } else {
                removeAttribute("rel")
            }
        }
    }
    
    /// Link href
    public var href: String? {
        get { return getAttribute("href") }
        set {
            if let value = newValue {
                setAttribute("href", value)
            } else {
                removeAttribute("href")
            }
        }
    }
    
    /// Link type
    public var type: String? {
        get { return getAttribute("type") }
        set {
            if let value = newValue {
                setAttribute("type", value)
            } else {
                removeAttribute("type")
            }
        }
    }
}

/// Style element
public class StyleElement: Element {
    
    public init(document: Document) {
        super.init(tagName: "STYLE", document: document)
    }
    
    /// Style type
    public var type: String? {
        get { return getAttribute("type") ?? "text/css" }
        set {
            if let value = newValue {
                setAttribute("type", value)
            } else {
                removeAttribute("type")
            }
        }
    }
    
    /// CSS content
    public var cssText: String {
        get { return textContent ?? "" }
        set { textContent = newValue }
    }
}
