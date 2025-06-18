//
//  DOMNode.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI
import Combine

// MARK: - Layout Types

enum LayoutType {
    case block
    case inline
    case inlineBlock
    case flex
    case table
    case tableRow
    case tableCell
    case none
}

extension LayoutType: CustomStringConvertible {
    var description: String {
        switch self {
        case .block: return "block"
        case .inline: return "inline"
        case .inlineBlock: return "inlineBlock"
        case .flex: return "flex"
        case .table: return "table"
        case .tableRow: return "tableRow"
        case .tableCell: return "tableCell"
        case .none: return "none"
        }
    }
}

// MARK: - Box Model

struct BoxModel {
    var content: CGSize = .zero
    var padding: EdgeInsets = EdgeInsets()
    var border: EdgeInsets = EdgeInsets()
    var margin: EdgeInsets = EdgeInsets()
    
    var totalWidth: CGFloat {
        content.width + padding.leading + padding.trailing + 
        border.leading + border.trailing + margin.leading + margin.trailing
    }
    
    var totalHeight: CGFloat {
        content.height + padding.top + padding.bottom + 
        border.top + border.bottom + margin.top + margin.bottom
    }
    
    var contentRect: CGRect {
        let x = margin.leading + border.leading + padding.leading
        let y = margin.top + border.top + padding.top
        return CGRect(x: x, y: y, width: content.width, height: content.height)
    }
}

// MARK: - Enhanced DOM Node

class DOMNode: Identifiable {
    let id = UUID()
    
    // Core properties
    var tagName: String?
    var textContent: String?
    var attributes: [String: String] = [:]
    var children: [DOMNode] = []
    weak var parent: DOMNode?
    
    // Styling
    var inlineStyle: CSSStyle = CSSStyle()
    var computedStyle: CSSStyle = CSSStyle()
    
    // Layout
    var boxModel: BoxModel = BoxModel()
    var layoutType: LayoutType = .block
    var frame: CGRect = .zero
    var intrinsicSize: CGSize = .zero
    
    // State
    var isHidden: Bool = false
    var needsLayout: Bool = true
    
    init(tagName: String? = nil, textContent: String? = nil, attributes: [String: String] = [:]) {
        self.tagName = tagName
        self.textContent = textContent
        self.attributes = attributes
        self.layoutType = determineLayoutType()
    }
    
    // MARK: - DOM Manipulation
    
    func appendChild(_ child: DOMNode) {
        child.parent = self
        children.append(child)
        markNeedsLayout()
    }
    
    func removeChild(_ child: DOMNode) {
        if let index = children.firstIndex(where: { $0.id == child.id }) {
            children[index].parent = nil
            children.remove(at: index)
            markNeedsLayout()
        }
    }
    
    func insertChild(_ child: DOMNode, at index: Int) {
        child.parent = self
        children.insert(child, at: min(index, children.count))
        markNeedsLayout()
    }
    
    // MARK: - Style and Layout
    
    func markNeedsLayout() {
        needsLayout = true
        parent?.markNeedsLayout()
    }
    
    private func determineLayoutType() -> LayoutType {
        guard let tag = tagName?.lowercased() else {
            return textContent != nil ? .inline : .block
        }
        
        switch tag {
        // Block elements
        case "div", "p", "h1", "h2", "h3", "h4", "h5", "h6", "section", "article", 
             "header", "footer", "nav", "aside", "main", "blockquote", "pre",
             "ul", "ol", "li", "dl", "dt", "dd", "form", "fieldset",
             "thead", "tbody", "tfoot", "canvas", "video", "audio":
            return .block
            
        // Inline elements
        case "span", "a", "strong", "em", "b", "i", "u", "small", "sub", "sup",
             "mark", "del", "ins", "q", "cite", "abbr", "dfn", "time", "code",
             "var", "samp", "kbd", "label":
            return .inline
            
        // Inline-block elements
        case "img", "input", "button", "select", "textarea":
            return .inlineBlock
            
        // Table elements
        case "table":
            return .table
        case "tr":
            return .tableRow
        case "td", "th":
            return .tableCell
            
        // Special cases
        case "br":
            return .inline
        case "script", "style", "meta", "link", "title":
            return .none
            
        default:
            // Check for display style override
            if let display = computedStyle.display {
                switch display {
                case .block: return .block
                case .inline: return .inline
                case .inlineBlock: return .inlineBlock
                case .flex: return .flex
                case .none: return .none
                }
            }
            return .block
        }
    }
    
    // MARK: - Computed Properties
    
    var isTextNode: Bool {
        return tagName == nil && textContent != nil
    }
    
    var isElement: Bool {
        return tagName != nil
    }
    
    var isBlock: Bool {
        return layoutType == .block || layoutType == .flex || layoutType == .table
    }
    
    var isInline: Bool {
        return layoutType == .inline || layoutType == .inlineBlock
    }
    
    var hasChildren: Bool {
        return !children.isEmpty
    }
    
    // MARK: - Attribute Helpers
    
    func getAttribute(_ name: String) -> String? {
        return attributes[name.lowercased()]
    }
    
    func setAttribute(_ name: String, value: String) {
        attributes[name.lowercased()] = value
        
        // Handle special attributes that affect layout
        if name.lowercased() == "style" {
            inlineStyle = CSSParser().parseInlineStyle(value)
            markNeedsLayout()
        }
    }
    
    func hasAttribute(_ name: String) -> Bool {
        return attributes[name.lowercased()] != nil
    }
    
    // MARK: - Tree Traversal
    
    func findChildrenWithTag(_ tagName: String) -> [DOMNode] {
        return children.filter { $0.tagName?.lowercased() == tagName.lowercased() }
    }
    
    func findDescendantsWithTag(_ tagName: String) -> [DOMNode] {
        var result: [DOMNode] = []
        
        func traverse(_ node: DOMNode) {
            if node.tagName?.lowercased() == tagName.lowercased() {
                result.append(node)
            }
            for child in node.children {
                traverse(child)
            }
        }
        
        traverse(self)
        return result
    }
    
    func findById(_ id: String) -> DOMNode? {
        if getAttribute("id") == id {
            return self
        }
        
        for child in children {
            if let found = child.findById(id) {
                return found
            }
        }
        
        return nil
    }
    
    func findByClass(_ className: String) -> [DOMNode] {
        var result: [DOMNode] = []
        
        func traverse(_ node: DOMNode) {
            if let classAttr = node.getAttribute("class") {
                let classes = classAttr.components(separatedBy: .whitespaces)
                if classes.contains(className) {
                    result.append(node)
                }
            }
            for child in node.children {
                traverse(child)
            }
        }
        
        traverse(self)
        return result
    }
    
    // MARK: - Debug Description
    
    var debugDescription: String {
        if let tag = tagName {
            let attrString = attributes.isEmpty ? "" : " " + attributes.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: " ")
            return "<\(tag)\(attrString)>"
        } else if let text = textContent {
            return "TEXT: \"\(text.prefix(50))\""
        } else {
            return "UNKNOWN NODE"
        }
    }
    
    func printTree(indent: Int = 0) {
        let indentation = String(repeating: "  ", count: indent)
        print("\(indentation)\(debugDescription)")
        for child in children {
            child.printTree(indent: indent + 1)
        }
    }
}

// MARK: - DOM Builder Helper

class DOMBuilder {
    static func createTextNode(_ text: String) -> DOMNode {
        return DOMNode(textContent: text)
    }
    
    static func createElement(_ tagName: String, attributes: [String: String] = [:]) -> DOMNode {
        return DOMNode(tagName: tagName, attributes: attributes)
    }
    
    static func createDocumentFragment() -> DOMNode {
        return DOMNode(tagName: "fragment")
    }
}


