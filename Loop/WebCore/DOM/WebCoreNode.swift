//
//  WebCoreNode.swift
//  Loop - WebKit-Inspired DOM Nodes
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI
import Combine

// MARK: - Node Types

enum WebCoreNodeType: Int {
    case element = 1
    case text = 3
    case processingInstruction = 7
    case comment = 8
    case document = 9
    case documentType = 10
    case documentFragment = 11
}

// MARK: - Base WebCore Node

class WebCoreNode: Identifiable, ObservableObject {
    
    // MARK: - Core Properties
    
    let id = NodeID()
    let nodeType: WebCoreNodeType
    
    private(set) weak var parentNode: WebCoreNode?
    @Published private(set) var childNodes: [WebCoreNode] = []
    private(set) weak var document: WebCoreDocument?
    
    var documentOrder: Int = 0
    var isConnected: Bool { document != nil }
    
    // MARK: - Initialization
    
    init(nodeType: WebCoreNodeType, document: WebCoreDocument?) {
        self.nodeType = nodeType
        self.document = document
    }
    
    // MARK: - Tree Manipulation
    
    func appendChild(_ child: WebCoreNode) {
        guard child.parentNode !== self else { return }
        
        // Remove from current parent
        child.removeFromParent()
        
        // Add to this node
        child.parentNode = self
        childNodes.append(child)
        
        // Update document reference
        child.setDocument(self.document)
        
        // Notify document of change
        document?.notifyChange()
    }
    
    func insertBefore(_ newChild: WebCoreNode, before refChild: WebCoreNode?) {
        guard let refChild = refChild else {
            appendChild(newChild)
            return
        }
        
        guard let index = childNodes.firstIndex(where: { $0.id == refChild.id }) else {
            return // refChild is not a child of this node
        }
        
        // Remove from current parent
        newChild.removeFromParent()
        
        // Insert at the correct position
        newChild.parentNode = self
        childNodes.insert(newChild, at: index)
        
        // Update document reference
        newChild.setDocument(self.document)
        
        document?.notifyChange()
    }
    
    func removeChild(_ child: WebCoreNode) {
        guard let index = childNodes.firstIndex(where: { $0.id == child.id }) else {
            return
        }
        
        child.parentNode = nil
        childNodes.remove(at: index)
        child.setDocument(nil)
        
        document?.notifyChange()
    }
    
    func removeFromParent() {
        parentNode?.removeChild(self)
    }
    
    func replaceChild(_ newChild: WebCoreNode, oldChild: WebCoreNode) {
        guard let index = childNodes.firstIndex(where: { $0.id == oldChild.id }) else {
            return
        }
        
        // Remove old child
        oldChild.parentNode = nil
        oldChild.setDocument(nil)
        
        // Insert new child
        newChild.removeFromParent()
        newChild.parentNode = self
        childNodes[index] = newChild
        newChild.setDocument(self.document)
        
        document?.notifyChange()
    }
    
    private func setDocument(_ document: WebCoreDocument?) {
        self.document = document
        
        // Recursively update children
        for child in childNodes {
            child.setDocument(document)
        }
    }
    
    // MARK: - Tree Navigation
    
    var firstChild: WebCoreNode? {
        return childNodes.first
    }
    
    var lastChild: WebCoreNode? {
        return childNodes.last
    }
    
    var nextSibling: WebCoreNode? {
        guard let parent = parentNode,
              let index = parent.childNodes.firstIndex(where: { $0.id == self.id }),
              index + 1 < parent.childNodes.count else {
            return nil
        }
        return parent.childNodes[index + 1]
    }
    
    var previousSibling: WebCoreNode? {
        guard let parent = parentNode,
              let index = parent.childNodes.firstIndex(where: { $0.id == self.id }),
              index > 0 else {
            return nil
        }
        return parent.childNodes[index - 1]
    }
    
    // MARK: - Content Properties
    
    var textContent: String {
        get {
            if nodeType == .text {
                return (self as? WebCoreTextNode)?.data ?? ""
            } else {
                return childNodes.map { $0.textContent }.joined()
            }
        }
        set {
            // Remove all children and add a single text node
            childNodes.removeAll()
            if !newValue.isEmpty {
                let textNode = WebCoreTextNode(text: newValue, document: document)
                appendChild(textNode)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func contains(_ other: WebCoreNode) -> Bool {
        var current: WebCoreNode? = other.parentNode
        while let node = current {
            if node.id == self.id {
                return true
            }
            current = node.parentNode
        }
        return false
    }
    
    func cloneNode(deep: Bool = false) -> WebCoreNode {
        fatalError("cloneNode must be implemented by subclasses")
    }
    
    // MARK: - Debug Support
    
    var nodeName: String {
        switch nodeType {
        case .element:
            return (self as? WebCoreElement)?.tagName.uppercased() ?? "ELEMENT"
        case .text:
            return "#text"
        case .document:
            return "#document"
        case .documentFragment:
            return "#document-fragment"
        default:
            return "#unknown"
        }
    }
    
    func printTree(indent: Int = 0) {
        let indentation = String(repeating: "  ", count: indent)
        let nodeInfo = "\(nodeName)"
        let extraInfo = getDebugInfo()
        print("\(indentation)\(nodeInfo)\(extraInfo)")
        
        for child in childNodes {
            child.printTree(indent: indent + 1)
        }
    }
    
    func getDebugInfo() -> String {
        return ""
    }
}

// MARK: - WebCore Element

class WebCoreElement: WebCoreNode {
    
    // MARK: - Element Properties
    
    let tagName: String
    private var attributes: [String: String] = [:]
    
    // MARK: - Initialization
    
    init(tagName: String, document: WebCoreDocument?) {
        self.tagName = tagName.lowercased()
        super.init(nodeType: .element, document: document)
    }
    
    // MARK: - Attribute Management
    
    func getAttribute(_ name: String) -> String? {
        return attributes[name.lowercased()]
    }
    
    func setAttribute(_ name: String, value: String) {
        let lowercaseName = name.lowercased()
        let oldValue = attributes[lowercaseName]
        attributes[lowercaseName] = value
        
        // Handle special attributes
        if lowercaseName == "id" || lowercaseName == "class" {
            document?.notifyChange()
        }
        
        attributeDidChange(name: lowercaseName, oldValue: oldValue, newValue: value)
    }
    
    func removeAttribute(_ name: String) {
        let lowercaseName = name.lowercased()
        let oldValue = attributes.removeValue(forKey: lowercaseName)
        
        if oldValue != nil {
            attributeDidChange(name: lowercaseName, oldValue: oldValue, newValue: nil)
            document?.notifyChange()
        }
    }
    
    func hasAttribute(_ name: String) -> Bool {
        return attributes[name.lowercased()] != nil
    }
    
    func getAttributeNames() -> [String] {
        return Array(attributes.keys)
    }
    
    private func attributeDidChange(name: String, oldValue: String?, newValue: String?) {
        // Hook for subclasses to handle attribute changes
    }
    
    // MARK: - Class Management
    
    var className: String {
        get { return getAttribute("class") ?? "" }
        set { setAttribute("class", value: newValue) }
    }
    
    func hasClass(_ className: String) -> Bool {
        let classes = Set(self.className.components(separatedBy: .whitespaces))
        return classes.contains(className)
    }
    
    func addClass(_ className: String) {
        var classes = Set(self.className.components(separatedBy: .whitespaces))
        classes.insert(className)
        self.className = classes.joined(separator: " ")
    }
    
    func removeClass(_ className: String) {
        var classes = Set(self.className.components(separatedBy: .whitespaces))
        classes.remove(className)
        self.className = classes.joined(separator: " ")
    }
    
    func toggleClass(_ className: String) -> Bool {
        if hasClass(className) {
            removeClass(className)
            return false
        } else {
            addClass(className)
            return true
        }
    }
    
    // MARK: - Element Queries
    
    var children: [WebCoreElement] {
        return childNodes.compactMap { $0 as? WebCoreElement }
    }
    
    var firstElementChild: WebCoreElement? {
        return children.first
    }
    
    var lastElementChild: WebCoreElement? {
        return children.last
    }
    
    var nextElementSibling: WebCoreElement? {
        var current = nextSibling
        while let node = current {
            if let element = node as? WebCoreElement {
                return element
            }
            current = node.nextSibling
        }
        return nil
    }
    
    var previousElementSibling: WebCoreElement? {
        var current = previousSibling
        while let node = current {
            if let element = node as? WebCoreElement {
                return element
            }
            current = node.previousSibling
        }
        return nil
    }
    
    // MARK: - Query Selectors (Simplified)
    
    func querySelector(_ selector: String) -> WebCoreElement? {
        return querySelector(selector, in: self)
    }
    
    func querySelectorAll(_ selector: String) -> [WebCoreElement] {
        var results: [WebCoreElement] = []
        querySelectorAll(selector, in: self, results: &results)
        return results
    }
    
    private func querySelector(_ selector: String, in element: WebCoreElement) -> WebCoreElement? {
        if matchesSelector(element, selector: selector) {
            return element
        }
        
        for child in element.children {
            if let found = querySelector(selector, in: child) {
                return found
            }
        }
        
        return nil
    }
    
    private func querySelectorAll(_ selector: String, in element: WebCoreElement, results: inout [WebCoreElement]) {
        if matchesSelector(element, selector: selector) {
            results.append(element)
        }
        
        for child in element.children {
            querySelectorAll(selector, in: child, results: &results)
        }
    }
    
    private func matchesSelector(_ element: WebCoreElement, selector: String) -> Bool {
        let trimmedSelector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Tag selector
        if trimmedSelector == element.tagName {
            return true
        }
        
        // Class selector
        if trimmedSelector.hasPrefix(".") {
            let className = String(trimmedSelector.dropFirst())
            return element.hasClass(className)
        }
        
        // ID selector
        if trimmedSelector.hasPrefix("#") {
            let idName = String(trimmedSelector.dropFirst())
            return element.getAttribute("id") == idName
        }
        
        // Attribute selector (simplified)
        if trimmedSelector.hasPrefix("[") && trimmedSelector.hasSuffix("]") {
            let attributePart = String(trimmedSelector.dropFirst().dropLast())
            if attributePart.contains("=") {
                let parts = attributePart.components(separatedBy: "=")
                if parts.count == 2 {
                    let attrName = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let attrValue = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                    return element.getAttribute(attrName) == attrValue
                }
            } else {
                return element.hasAttribute(attributePart)
            }
        }
        
        return false
    }
    
    // MARK: - HTML Serialization
    
    var innerHTML: String {
        get {
            return childNodes.map { nodeToHTML($0) }.joined()
        }
        set {
            // This would require parsing HTML - simplified for now
            textContent = newValue
        }
    }
    
    var outerHTML: String {
        return nodeToHTML(self)
    }
    
    private func nodeToHTML(_ node: WebCoreNode) -> String {
        if let element = node as? WebCoreElement {
            let attributesString = element.attributes.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: " ")
            let attributesPart = attributesString.isEmpty ? "" : " \(attributesString)"
            
            if element.childNodes.isEmpty && isSelfClosingTag(element.tagName) {
                return "<\(element.tagName)\(attributesPart) />"
            } else {
                let content = element.childNodes.map { nodeToHTML($0) }.joined()
                return "<\(element.tagName)\(attributesPart)>\(content)</\(element.tagName)>"
            }
        } else if let textNode = node as? WebCoreTextNode {
            return textNode.data
        } else {
            return ""
        }
    }
    
    private func isSelfClosingTag(_ tagName: String) -> Bool {
        let selfClosingTags = Set([
            "area", "base", "br", "col", "embed", "hr", "img", "input",
            "link", "meta", "param", "source", "track", "wbr"
        ])
        return selfClosingTags.contains(tagName.lowercased())
    }
    
    // MARK: - Node Overrides
    
    override func cloneNode(deep: Bool = false) -> WebCoreNode {
        let clone = WebCoreElement(tagName: tagName, document: nil)
        clone.attributes = self.attributes
        
        if deep {
            for child in childNodes {
                clone.appendChild(child.cloneNode(deep: true))
            }
        }
        
        return clone
    }
    
    override func getDebugInfo() -> String {
        let attrString = attributes.isEmpty ? "" : " " + attributes.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: " ")
        return attrString
    }
}

// MARK: - WebCore Text Node

class WebCoreTextNode: WebCoreNode {
    
    var data: String {
        didSet {
            if data != oldValue {
                document?.notifyChange()
            }
        }
    }
    
    init(text: String, document: WebCoreDocument?) {
        self.data = text
        super.init(nodeType: .text, document: document)
    }
    
    override var textContent: String {
        get { return data }
        set { data = newValue }
    }
    
    override func cloneNode(deep: Bool = false) -> WebCoreNode {
        return WebCoreTextNode(text: data, document: nil)
    }
    
    override func getDebugInfo() -> String {
        let truncatedText = data.count > 50 ? String(data.prefix(47)) + "..." : data
        return " \"\(truncatedText)\""
    }
}

// MARK: - WebCore Document Fragment

class WebCoreDocumentFragment: WebCoreNode {
    
    init(document: WebCoreDocument?) {
        super.init(nodeType: .documentFragment, document: document)
    }
    
    override func cloneNode(deep: Bool = false) -> WebCoreNode {
        let clone = WebCoreDocumentFragment(document: nil)
        
        if deep {
            for child in childNodes {
                clone.appendChild(child.cloneNode(deep: true))
            }
        }
        
        return clone
    }
}
