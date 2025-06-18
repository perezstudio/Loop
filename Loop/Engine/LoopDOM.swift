//
//  LoopDOM.swift
//  Loop
//
//  DOM implementation for the Loop engine
//

import Foundation

/// Node types in the DOM tree
public enum NodeType: UInt16 {
    case element = 1
    case text = 3
    case comment = 8
    case document = 9
    case documentFragment = 11
}

/// Base class for all DOM nodes
public class Node {
    
    // MARK: - Core Properties
    
    /// Node type
    public let nodeType: NodeType
    
    /// Parent node (weak reference to prevent cycles)
    public private(set) weak var parentNode: Node?
    
    /// First child node
    public private(set) var firstChild: Node?
    
    /// Next sibling
    public private(set) var nextSibling: Node?
    
    /// Owner document
    public private(set) weak var ownerDocument: Document?
    
    /// Unique node identifier
    public let nodeId: UInt64
    
    // MARK: - Static counter
    
    private static var nextNodeId: UInt64 = 1
    private static let nodeIdLock = NSLock()
    
    // MARK: - Initialization
    
    public init(nodeType: NodeType, document: Document? = nil) {
        // Generate unique node ID
        Node.nodeIdLock.lock()
        self.nodeId = Node.nextNodeId
        Node.nextNodeId += 1
        Node.nodeIdLock.unlock()
        
        self.nodeType = nodeType
        self.ownerDocument = document
    }
    
    // MARK: - Properties
    
    /// Node name (overridden by subclasses)
    open var nodeName: String {
        switch nodeType {
        case .element: return "ELEMENT"
        case .text: return "#text"
        case .comment: return "#comment"
        case .document: return "#document"
        case .documentFragment: return "#document-fragment"
        }
    }
    
    /// Node value (overridden by subclasses)
    open var nodeValue: String? {
        return nil
    }
    
    /// Text content of the node
    open var textContent: String? {
        get {
            switch nodeType {
            case .text, .comment:
                return nodeValue
            case .element, .documentFragment:
                var result = ""
                var current = firstChild
                while let child = current {
                    if let text = child.textContent {
                        result += text
                    }
                    current = child.nextSibling
                }
                return result.isEmpty ? nil : result
            default:
                return nil
            }
        }
        set {
            removeAllChildren()
            if let text = newValue, !text.isEmpty {
                if let document = ownerDocument {
                    let textNode = TextNode(data: text, document: document)
                    appendChild(textNode)
                }
            }
        }
    }
    
    /// Check if node has child nodes
    public var hasChildNodes: Bool {
        return firstChild != nil
    }
    
    // MARK: - Tree Modification
    
    /// Append a child node
    @discardableResult
    public func appendChild(_ newChild: Node) -> Node {
        // Remove from old location if needed
        newChild.remove()
        
        // Update parent reference
        newChild.parentNode = self
        newChild.ownerDocument = ownerDocument
        
        // Insert at end
        if let lastChild = getLastChild() {
            lastChild.nextSibling = newChild
        } else {
            firstChild = newChild
        }
        
        return newChild
    }
    
    /// Remove a child node
    @discardableResult
    public func removeChild(_ oldChild: Node) -> Node {
        guard oldChild.parentNode === self else {
            fatalError("Node is not a child of this node")
        }
        
        // Find previous sibling
        var previous: Node?
        var current = firstChild
        while current !== oldChild && current != nil {
            previous = current
            current = current?.nextSibling
        }
        
        // Update links
        if let prev = previous {
            prev.nextSibling = oldChild.nextSibling
        } else {
            firstChild = oldChild.nextSibling
        }
        
        // Clear parent reference
        oldChild.parentNode = nil
        oldChild.nextSibling = nil
        
        return oldChild
    }
    
    /// Remove this node from its parent
    public func remove() {
        parentNode?.removeChild(self)
    }
    
    /// Remove all child nodes
    public func removeAllChildren() {
        while let child = firstChild {
            removeChild(child)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getLastChild() -> Node? {
        var current = firstChild
        var last: Node?
        while let node = current {
            last = node
            current = node.nextSibling
        }
        return last
    }
}

// MARK: - Document Node

public class Document: Node {
    
    public init() {
        super.init(nodeType: .document, document: nil)
        // Document is its own owner document - we need to set this after init
        // We'll use a private setter or make this a special case
    }
    
    public override var nodeName: String {
        return "#document"
    }
    
    public override var ownerDocument: Document? {
        return self
    }
    
    /// Create a new element
    public func createElement(_ tagName: String) -> Element {
        return Element(tagName: tagName, document: self)
    }
    
    /// Create a new text node
    public func createTextNode(_ data: String) -> TextNode {
        return TextNode(data: data, document: self)
    }
    
    /// Create a new comment node
    public func createComment(_ data: String) -> CommentNode {
        return CommentNode(data: data, document: self)
    }
    
    // MARK: - Document-level queries
    
    /// Get element by ID (searches entire document)
    public func getElementById(_ id: String) -> Element? {
        // Search through all child elements
        var current = firstChild
        while let node = current {
            if let element = node as? Element {
                if element.id == id {
                    return element
                }
                if let found = element.getElementById(id) {
                    return found
                }
            }
            current = node.nextSibling
        }
        return nil
    }
    
    /// Get elements by class name (searches entire document)
    public func getElementsByClassName(_ className: String) -> [Element] {
        var result: [Element] = []
        
        var current = firstChild
        while let node = current {
            if let element = node as? Element {
                if element.hasClass(className) {
                    result.append(element)
                }
                result.append(contentsOf: element.getElementsByClassName(className))
            }
            current = node.nextSibling
        }
        
        return result
    }
    
    /// Get elements by tag name (searches entire document)
    public func getElementsByTagName(_ tagName: String) -> [Element] {
        var result: [Element] = []
        let upperTagName = tagName.uppercased()
        
        var current = firstChild
        while let node = current {
            if let element = node as? Element {
                if element.tagName == upperTagName {
                    result.append(element)
                }
                result.append(contentsOf: element.getElementsByTagName(tagName))
            }
            current = node.nextSibling
        }
        
        return result
    }
}

// MARK: - Element Node

public class Element: Node {
    
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
        }
    }
    
    public init(tagName: String, document: Document) {
        self.tagName = tagName.uppercased()
        super.init(nodeType: .element, document: document)
    }
    
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
        attributes[lowercaseName] = value
        
        // Handle special attributes
        if lowercaseName == "class" {
            parseClassAttribute(value)
        }
    }
    
    /// Remove attribute
    public func removeAttribute(_ name: String) {
        let lowercaseName = name.lowercased()
        attributes.removeValue(forKey: lowercaseName)
        
        if lowercaseName == "class" {
            classList.removeAll()
        }
    }
    
    /// Check if attribute exists
    public func hasAttribute(_ name: String) -> Bool {
        return attributes[name.lowercased()] != nil
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
        }
    }
    
    /// Remove CSS class
    public func removeClass(_ className: String) {
        if classList.remove(className) != nil {
            updateClassAttribute()
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
        
        var current = firstChild
        while let node = current {
            if let element = node as? Element {
                if element.tagName == upperTagName {
                    result.append(element)
                }
                // Recursively search in child elements
                result.append(contentsOf: element.getElementsByTagName(tagName))
            }
            current = node.nextSibling
        }
        
        return result
    }
    
    /// Get elements by class name
    public func getElementsByClassName(_ className: String) -> [Element] {
        var result: [Element] = []
        
        var current = firstChild
        while let node = current {
            if let element = node as? Element {
                if element.hasClass(className) {
                    result.append(element)
                }
                // Recursively search in child elements
                result.append(contentsOf: element.getElementsByClassName(className))
            }
            current = node.nextSibling
        }
        
        return result
    }
    
    /// Get element by ID
    public func getElementById(_ id: String) -> Element? {
        var current = firstChild
        while let node = current {
            if let element = node as? Element {
                if element.id == id {
                    return element
                }
                // Recursively search in child elements
                if let found = element.getElementById(id) {
                    return found
                }
            }
            current = node.nextSibling
        }
        return nil
    }
}

// MARK: - Text Node

public class TextNode: Node {
    public var data: String
    
    public init(data: String, document: Document) {
        self.data = data
        super.init(nodeType: .text, document: document)
    }
    
    public override var nodeName: String {
        return "#text"
    }
    
    public override var nodeValue: String? {
        get { return data }
        set { data = newValue ?? "" }
    }
    
    public override var textContent: String? {
        get { return data }
        set { data = newValue ?? "" }
    }
}

// MARK: - Comment Node

public class CommentNode: Node {
    public var data: String
    
    public init(data: String, document: Document) {
        self.data = data
        super.init(nodeType: .comment, document: document)
    }
    
    public override var nodeName: String {
        return "#comment"
    }
    
    public override var nodeValue: String? {
        get { return data }
        set { data = newValue ?? "" }
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
