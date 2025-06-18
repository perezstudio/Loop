//
//  Node.swift
//  LoopEngine
//
//  Core DOM Node implementation inspired by WebKit's Node class
//

import Foundation

/// Node types in the DOM tree
public enum NodeType: UInt16 {
    case element = 1
    case attribute = 2  
    case text = 3
    case cdataSection = 4
    case entityReference = 5  // Legacy
    case entity = 6  // Legacy
    case processingInstruction = 7
    case comment = 8
    case document = 9
    case documentType = 10
    case documentFragment = 11
    case notation = 12  // Legacy
}

/// Flags for node state and optimizations
public struct NodeFlags: OptionSet {
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public static let isConnected = NodeFlags(rawValue: 1 << 0)
    public static let hasChildNodes = NodeFlags(rawValue: 1 << 1)
    public static let needsStyleRecalc = NodeFlags(rawValue: 1 << 2)
    public static let needsLayoutUpdate = NodeFlags(rawValue: 1 << 3)
    public static let inDocument = NodeFlags(rawValue: 1 << 4)
    public static let isRootEditableElement = NodeFlags(rawValue: 1 << 5)
    public static let isLink = NodeFlags(rawValue: 1 << 6)
    public static let isActive = NodeFlags(rawValue: 1 << 7)
    public static let isHovered = NodeFlags(rawValue: 1 << 8)
    public static let isFocused = NodeFlags(rawValue: 1 << 9)
    public static let hasEventListeners = NodeFlags(rawValue: 1 << 10)
    public static let isUserSelectNone = NodeFlags(rawValue: 1 << 11)
    public static let isSVGElement = NodeFlags(rawValue: 1 << 12)
    public static let isHTMLElement = NodeFlags(rawValue: 1 << 13)
    public static let isCustomElement = NodeFlags(rawValue: 1 << 14)
    public static let hasDirtyRenderer = NodeFlags(rawValue: 1 << 15)
}

/// Base class for all DOM nodes
/// Implements a high-performance DOM tree with WebKit-inspired optimizations
public class Node: RefCounted {
    
    // MARK: - Core Properties
    
    /// Node type
    public let nodeType: NodeType
    
    /// Node flags for quick state checks
    public var flags: NodeFlags = []
    
    /// Parent node (weak reference to prevent cycles)
    public private(set) weak var parentNode: Node?
    
    /// First child node
    public private(set) var firstChild: Node?
    
    /// Last child node  
    public private(set) var lastChild: Node?
    
    /// Previous sibling
    public private(set) weak var previousSibling: Node?
    
    /// Next sibling
    public private(set) var nextSibling: Node?
    
    /// Owner document
    public private(set) weak var ownerDocument: Document?
    
    /// Unique node identifier for debugging
    public let nodeId: UInt64
    
    // MARK: - Static counters
    
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
        
        super.init()
    }
    
    // MARK: - Computed Properties
    
    /// Node name (overridden by subclasses)
    open var nodeName: String {
        switch nodeType {
        case .element: return "ELEMENT"
        case .text: return "#text"
        case .comment: return "#comment"
        case .document: return "#document"
        case .documentFragment: return "#document-fragment"
        default: return "#unknown"
        }
    }
    
    /// Node value (overridden by subclasses)
    open var nodeValue: String? {
        return nil
    }
    
    /// Text content of the node and its descendants
    open var textContent: String? {
        get {
            switch nodeType {
            case .text, .comment:
                return nodeValue
            case .element, .documentFragment:
                var result = ""
                for child in children {
                    if let text = child.textContent {
                        result += text
                    }
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
    
    /// Child nodes array (computed for performance)
    public var childNodes: [Node] {
        return Array(children)
    }
    
    /// Check if node has child nodes
    public var hasChildNodes: Bool {
        return flags.contains(.hasChildNodes)
    }
    
    /// Check if node is connected to document
    public var isConnected: Bool {
        return flags.contains(.isConnected)
    }
    
    // MARK: - Tree Traversal
    
    /// Iterator for child nodes
    public var children: NodeChildIterator {
        return NodeChildIterator(startNode: firstChild)
    }
    
    /// Get all descendant nodes
    public var descendants: [Node] {
        var result: [Node] = []
        traverseDescendants { node in
            result.append(node)
            return true
        }
        return result
    }
    
    /// Traverse all descendant nodes
    public func traverseDescendants(_ visitor: (Node) -> Bool) {
        for child in children {
            if visitor(child) {
                child.traverseDescendants(visitor)
            }
        }
    }
    
    // MARK: - Tree Modification
    
    /// Insert a child node before reference node
    @discardableResult
    public func insertBefore(_ newChild: Node, _ referenceChild: Node?) -> Node {
        precondition(newChild.parentNode == nil, "Node already has a parent")
        
        // Remove from old location if needed
        newChild.remove()
        
        // Update parent reference
        newChild.parentNode = self
        newChild.ownerDocument = ownerDocument
        
        // Insert in the tree
        if let refChild = referenceChild {
            precondition(refChild.parentNode === self, "Reference child is not a child of this node")
            
            newChild.nextSibling = refChild
            newChild.previousSibling = refChild.previousSibling
            
            if let prevSibling = refChild.previousSibling {
                prevSibling.nextSibling = newChild
            } else {
                firstChild = newChild
            }
            
            refChild.previousSibling = newChild
        } else {
            // Insert at end
            newChild.previousSibling = lastChild
            if let lastChild = lastChild {
                lastChild.nextSibling = newChild
            } else {
                firstChild = newChild
            }
            lastChild = newChild
        }
        
        // Update flags
        flags.insert(.hasChildNodes)
        
        // Update connectivity
        updateConnectivity()
        
        // Mark for style recalc
        markForStyleRecalc()
        
        // Increment reference
        _ = newChild.ref()
        
        return newChild
    }
    
    /// Append a child node
    @discardableResult  
    public func appendChild(_ newChild: Node) -> Node {
        return insertBefore(newChild, nil)
    }
    
    /// Remove a child node
    @discardableResult
    public func removeChild(_ oldChild: Node) -> Node {
        precondition(oldChild.parentNode === self, "Node is not a child of this node")
        
        // Update sibling links
        if let prevSibling = oldChild.previousSibling {
            prevSibling.nextSibling = oldChild.nextSibling
        } else {
            firstChild = oldChild.nextSibling
        }
        
        if let nextSibling = oldChild.nextSibling {
            nextSibling.previousSibling = oldChild.previousSibling
        } else {
            lastChild = oldChild.previousSibling
        }
        
        // Clear parent reference
        oldChild.parentNode = nil
        oldChild.previousSibling = nil
        oldChild.nextSibling = nil
        
        // Update flags
        if firstChild == nil {
            flags.remove(.hasChildNodes)
        }
        
        // Update connectivity
        oldChild.updateConnectivity()
        
        // Mark for style recalc
        markForStyleRecalc()
        
        // Release reference
        oldChild.deref()
        
        return oldChild
    }
    
    /// Replace a child node
    @discardableResult
    public func replaceChild(_ newChild: Node, _ oldChild: Node) -> Node {
        insertBefore(newChild, oldChild)
        return removeChild(oldChild)
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
    
    // MARK: - State Management
    
    /// Update connectivity flags for this node and descendants
    private func updateConnectivity() {
        let connected = isInDocument()
        
        if connected {
            flags.insert(.isConnected)
            flags.insert(.inDocument)
        } else {
            flags.remove(.isConnected)
            flags.remove(.inDocument)
        }
        
        // Update children
        for child in children {
            child.updateConnectivity()
        }
    }
    
    /// Check if node is in document tree
    private func isInDocument() -> Bool {
        var current: Node? = self
        while let node = current {
            if node.nodeType == .document {
                return true
            }
            current = node.parentNode
        }
        return false
    }
    
    /// Mark node and ancestors for style recalculation
    public func markForStyleRecalc() {
        var current: Node? = self
        while let node = current {
            if node.flags.contains(.needsStyleRecalc) {
                break // Already marked
            }
            node.flags.insert(.needsStyleRecalc)
            current = node.parentNode
        }
    }
    
    /// Mark node for layout update
    public func markForLayoutUpdate() {
        flags.insert(.needsLayoutUpdate)
        markForStyleRecalc()
    }
    
    // MARK: - Cleanup
    
    public override func destroy() {
        removeAllChildren()
        remove()
        super.destroy()
    }
}

// MARK: - Node Iterator

public struct NodeChildIterator: IteratorProtocol, Sequence {
    private var currentNode: Node?
    
    init(startNode: Node?) {
        currentNode = startNode
    }
    
    public mutating func next() -> Node? {
        let node = currentNode
        currentNode = currentNode?.nextSibling
        return node
    }
}

// MARK: - Document Node

public class Document: Node {
    
    public override init() {
        super.init(nodeType: .document, document: nil)
        self.ownerDocument = self
        flags.insert(.isConnected)
        flags.insert(.inDocument)
    }
    
    public override var nodeName: String {
        return "#document"
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
    
    /// Create a document fragment
    public func createDocumentFragment() -> DocumentFragment {
        return DocumentFragment(document: self)
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
        set { 
            data = newValue ?? ""
            markForLayoutUpdate()
        }
    }
    
    public override var textContent: String? {
        get { return data }
        set { 
            data = newValue ?? ""
            markForLayoutUpdate()
        }
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
        set { 
            data = newValue ?? ""
        }
    }
}

// MARK: - Document Fragment

public class DocumentFragment: Node {
    
    public init(document: Document) {
        super.init(nodeType: .documentFragment, document: document)
    }
    
    public override var nodeName: String {
        return "#document-fragment"
    }
}
