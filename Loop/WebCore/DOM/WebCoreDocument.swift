//
//  WebCoreDocument.swift
//  Loop - WebKit-Inspired DOM Implementation
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import SwiftUI
import Combine

// MARK: - Document Events

protocol WebCoreDocumentDelegate: AnyObject {
    func documentDidChange(_ document: WebCoreDocument)
    func documentDidFinishLoading(_ document: WebCoreDocument)
}

// MARK: - Node Identification

typealias NodeID = UUID

// MARK: - WebCore Document

class WebCoreDocument: ObservableObject {
    
    // MARK: - Properties
    
    private(set) var documentElement: WebCoreElement?
    private(set) var baseURL: URL?
    private var nodeMap: [NodeID: WeakRef<WebCoreNode>] = [:]
    private var nextNodeOrder: Int = 0
    
    // Parser and processors
    private let htmlParser: HTML5Parser
    private let cssExtractor: CSSExtractor
    
    // State
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var readyState: DocumentReadyState = .loading
    
    weak var delegate: WebCoreDocumentDelegate?
    
    // MARK: - Document Ready States
    
    enum DocumentReadyState {
        case loading
        case interactive
        case complete
    }
    
    // MARK: - Initialization
    
    init() {
        self.htmlParser = HTML5Parser()
        self.cssExtractor = CSSExtractor()
        
        print("📄 WebCore Document initialized")
    }
    
    // MARK: - Document Loading
    
    func loadHTML(_ html: String, baseURL: URL? = nil) async throws {
        await MainActor.run {
            isLoading = true
            readyState = .loading
        }
        
        self.baseURL = baseURL
        
        print("📄 Parsing HTML document...")
        
        // Parse HTML into DOM tree
        let parseResult = try await htmlParser.parse(html)
        
        // Extract CSS from the document
        let cssContent = cssExtractor.extractCSS(from: parseResult.rootElement)
        
        // Build the document tree
        await MainActor.run {
            self.documentElement = parseResult.rootElement
            self.buildNodeMap(from: parseResult.rootElement)
            self.readyState = .interactive
        }
        
        // Store CSS for later processing
        if !cssContent.isEmpty {
            documentElement?.setAttribute("__internal_css", value: cssContent)
        }
        
        await MainActor.run {
            self.readyState = .complete
            self.isLoading = false
        }
        
        delegate?.documentDidFinishLoading(self)
        delegate?.documentDidChange(self)
        
        print("✅ Document loaded successfully with \(getNodeCount()) nodes")
    }
    
    // MARK: - Node Management
    
    private func buildNodeMap(from element: WebCoreElement) {
        registerNode(element)
        
        for child in element.children {
            if let childElement = child as? WebCoreElement {
                buildNodeMap(from: childElement)
            } else {
                registerNode(child)
            }
        }
    }
    
    private func registerNode(_ node: WebCoreNode) {
        node.documentOrder = nextNodeOrder
        nextNodeOrder += 1
        nodeMap[node.id] = WeakRef(node)
    }
    
    func getNode(by id: NodeID) -> WebCoreNode? {
        return nodeMap[id]?.value
    }
    
    func getNodeCount() -> Int {
        return nodeMap.count
    }
    
    // MARK: - DOM Queries
    
    func getElementById(_ id: String) -> WebCoreElement? {
        return documentElement?.querySelector("[id='\(id)']")
    }
    
    func getElementsByTagName(_ tagName: String) -> [WebCoreElement] {
        return documentElement?.querySelectorAll(tagName) ?? []
    }
    
    func getElementsByClassName(_ className: String) -> [WebCoreElement] {
        return documentElement?.querySelectorAll(".\(className)") ?? []
    }
    
    func querySelector(_ selector: String) -> WebCoreElement? {
        return documentElement?.querySelector(selector)
    }
    
    func querySelectorAll(_ selector: String) -> [WebCoreElement] {
        return documentElement?.querySelectorAll(selector) ?? []
    }
    
    // MARK: - Document Modification
    
    func createElement(_ tagName: String) -> WebCoreElement {
        let element = WebCoreElement(tagName: tagName, document: self)
        registerNode(element)
        return element
    }
    
    func createTextNode(_ text: String) -> WebCoreTextNode {
        let textNode = WebCoreTextNode(text: text, document: self)
        registerNode(textNode)
        return textNode
    }
    
    func createDocumentFragment() -> WebCoreDocumentFragment {
        let fragment = WebCoreDocumentFragment(document: self)
        registerNode(fragment)
        return fragment
    }
    
    // MARK: - Document Properties
    
    var title: String {
        get {
            return documentElement?.querySelector("title")?.textContent ?? ""
        }
        set {
            if let titleElement = documentElement?.querySelector("title") {
                titleElement.textContent = newValue
            } else if let head = documentElement?.querySelector("head") {
                let titleElement = createElement("title")
                titleElement.textContent = newValue
                head.appendChild(titleElement)
            }
            notifyChange()
        }
    }
    
    var head: WebCoreElement? {
        return documentElement?.querySelector("head")
    }
    
    var body: WebCoreElement? {
        return documentElement?.querySelector("body")
    }
    
    // MARK: - Document Events
    
    func notifyChange() {
        delegate?.documentDidChange(self)
    }
    
    // MARK: - Debug Information
    
    func printDocumentTree() {
        print("📄 Document Tree Structure:")
        documentElement?.printTree(indent: 0)
    }
    
    func getDocumentHTML() -> String {
        return documentElement?.outerHTML ?? ""
    }
}

// MARK: - Weak Reference Helper

class WeakRef<T: AnyObject> {
    weak var value: T?
    
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - HTML5 Parser

class HTML5Parser {
    
    struct ParseResult {
        let rootElement: WebCoreElement
        let parseErrors: [ParseError]
        let parseTime: TimeInterval
    }
    
    struct ParseError {
        let message: String
        let line: Int
        let column: Int
    }
    
    func parse(_ html: String) async throws -> ParseResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var parseErrors: [ParseError] = []
        
        // Clean up HTML
        let cleanHTML = preprocessHTML(html)
        
        // Create root element
        let document = WebCoreElement(tagName: "html", document: nil)
        
        // Parse the HTML
        do {
            try parseHTMLIntoElement(cleanHTML, into: document, errors: &parseErrors)
        } catch {
            throw WebCoreError.parseError("Failed to parse HTML: \(error.localizedDescription)")
        }
        
        let parseTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return ParseResult(
            rootElement: document,
            parseErrors: parseErrors,
            parseTime: parseTime
        )
    }
    
    private func preprocessHTML(_ html: String) -> String {
        var cleanHTML = html
        
        // Remove DOCTYPE if present
        if let doctypeRange = cleanHTML.range(of: #"<!doctype[^>]*>"#, options: [.regularExpression, .caseInsensitive]) {
            cleanHTML.removeSubrange(doctypeRange)
        }
        
        // Remove HTML comments
        while let commentStart = cleanHTML.range(of: "<!--") {
            if let commentEnd = cleanHTML.range(of: "-->", range: commentStart.upperBound..<cleanHTML.endIndex) {
                cleanHTML.removeSubrange(commentStart.lowerBound..<commentEnd.upperBound)
            } else {
                cleanHTML.removeSubrange(commentStart.lowerBound..<cleanHTML.endIndex)
                break
            }
        }
        
        return cleanHTML.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseHTMLIntoElement(_ html: String, into parentElement: WebCoreElement, errors: inout [ParseError]) throws {
        var index = html.startIndex
        var elementStack: [WebCoreElement] = [parentElement]
        
        while index < html.endIndex {
            if html[index] == "<" {
                index = try parseTag(html: html, index: index, stack: &elementStack, errors: &errors)
            } else {
                index = parseText(html: html, index: index, stack: &elementStack)
            }
        }
    }
    
    private func parseTag(html: String, index: String.Index, stack: inout [WebCoreElement], errors: inout [ParseError]) throws -> String.Index {
        guard let endTag = html[index...].firstIndex(of: ">") else {
            errors.append(ParseError(message: "Unclosed tag", line: 0, column: 0))
            return html.index(after: index)
        }
        
        let tagContent = String(html[html.index(after: index)..<endTag])
        let nextIndex = html.index(after: endTag)
        
        if tagContent.hasPrefix("/") {
            // Closing tag
            let tagName = String(tagContent.dropFirst()).trimmingCharacters(in: .whitespaces).lowercased()
            closeTag(tagName: tagName, stack: &stack)
        } else if !tagContent.isEmpty {
            // Opening tag or self-closing tag
            let (tagName, attributes, isSelfClosing) = parseTagContent(tagContent)
            
            if !tagName.isEmpty {
                let element = WebCoreElement(tagName: tagName, document: nil)
                
                // Set attributes
                for (key, value) in attributes {
                    element.setAttribute(key, value: value)
                }
                
                // Add to parent
                stack.last?.appendChild(element)
                
                // Add to stack if not self-closing
                if !isSelfClosing && !isSelfClosingByNature(tagName) {
                    stack.append(element)
                }
            }
        }
        
        return nextIndex
    }
    
    private func parseText(html: String, index: String.Index, stack: inout [WebCoreElement]) -> String.Index {
        var textEnd = index
        while textEnd < html.endIndex && html[textEnd] != "<" {
            textEnd = html.index(after: textEnd)
        }
        
        let text = String(html[index..<textEnd])
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedText.isEmpty {
            let textNode = WebCoreTextNode(text: text, document: nil)
            stack.last?.appendChild(textNode)
        }
        
        return textEnd
    }
    
    private func parseTagContent(_ content: String) -> (tagName: String, attributes: [String: String], isSelfClosing: Bool) {
        var tagString = content.trimmingCharacters(in: .whitespaces)
        var isSelfClosing = false
        
        if tagString.hasSuffix("/") {
            isSelfClosing = true
            tagString = String(tagString.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        
        let parts = tagString.components(separatedBy: .whitespaces)
        guard let tagName = parts.first?.lowercased() else {
            return ("", [:], isSelfClosing)
        }
        
        var attributes: [String: String] = [:]
        
        // Parse attributes (simplified)
        let attributeString = parts.dropFirst().joined(separator: " ")
        if !attributeString.isEmpty {
            attributes = parseAttributes(attributeString)
        }
        
        return (tagName, attributes, isSelfClosing)
    }
    
    private func parseAttributes(_ attributeString: String) -> [String: String] {
        var attributes: [String: String] = [:]
        
        // Simple attribute parsing - can be enhanced
        let regex = try? NSRegularExpression(pattern: #"(\w+)(?:=["']([^"']*?)["'])?"#, options: [])
        let matches = regex?.matches(in: attributeString, options: [], range: NSRange(location: 0, length: attributeString.utf16.count)) ?? []
        
        for match in matches {
            if let nameRange = Range(match.range(at: 1), in: attributeString) {
                let name = String(attributeString[nameRange]).lowercased()
                
                if match.range(at: 2).location != NSNotFound,
                   let valueRange = Range(match.range(at: 2), in: attributeString) {
                    let value = String(attributeString[valueRange])
                    attributes[name] = value
                } else {
                    attributes[name] = ""
                }
            }
        }
        
        return attributes
    }
    
    private func closeTag(tagName: String, stack: inout [WebCoreElement]) {
        for i in (1..<stack.count).reversed() {
            if stack[i].tagName.lowercased() == tagName {
                stack.removeSubrange(i..<stack.count)
                break
            }
        }
    }
    
    private func isSelfClosingByNature(_ tagName: String) -> Bool {
        let selfClosingTags = Set([
            "area", "base", "br", "col", "embed", "hr", "img", "input",
            "link", "meta", "param", "source", "track", "wbr"
        ])
        return selfClosingTags.contains(tagName.lowercased())
    }
}

// MARK: - CSS Extractor

class CSSExtractor {
    
    func extractCSS(from element: WebCoreElement) -> String {
        var allCSS = ""
        
        // Extract from style elements
        let styleElements = element.querySelectorAll("style")
        for styleElement in styleElements {
            allCSS += styleElement.textContent + "\n"
        }
        
        return allCSS
    }
}

// MARK: - WebCore Errors

enum WebCoreError: Error {
    case parseError(String)
    case invalidDocument
    case nodeNotFound
    case invalidOperation
}
