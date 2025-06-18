//
//  EnhancedHTMLParser.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - Enhanced HTML Parser

class EnhancedHTMLParser {
    private let cssParser = CSSParser()
    
    func parse(_ html: String) -> DOMNode {
        // Clean up the HTML first
        var cleanHTML = html
        
        // Remove DOCTYPE declaration
        if let doctypeRange = cleanHTML.range(of: "<!doctype[^>]*>", options: [.regularExpression, .caseInsensitive]) {
            cleanHTML.removeSubrange(doctypeRange)
        }
        
        // Extract and parse CSS
        let (htmlWithoutCSS, extractedCSS) = extractCSS(from: cleanHTML)
        cleanHTML = htmlWithoutCSS
        
        // Remove comments but preserve their positions for better error handling
        cleanHTML = removeComments(from: cleanHTML)
        
        // Parse the HTML into DOM nodes
        let rootNode = parseHTML(cleanHTML)
        
        // Apply CSS styles if we found any
        if !extractedCSS.isEmpty {
            _ = cssParser.parseStylesheet(extractedCSS)
            // Store CSS rules for later use in layout
            rootNode.setAttribute("__internal_css", value: extractedCSS)
        }
        
        return rootNode
    }
    
    // MARK: - CSS Extraction
    
    private func extractCSS(from html: String) -> (html: String, css: String) {
        var cleanHTML = html
        var allCSS = ""
        
        // Extract <style> tags
        let stylePattern = #"<style[^>]*>(.*?)</style>"#
        do {
            let regex = try NSRegularExpression(pattern: stylePattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
            
            // Process matches in reverse order to maintain string indices
            for match in matches.reversed() {
                if let fullRange = Range(match.range(at: 0), in: html),
                   let cssRange = Range(match.range(at: 1), in: html) {
                    allCSS += String(html[cssRange]) + "\n"
                    cleanHTML.removeSubrange(fullRange)
                }
            }
        } catch {
            print("Error extracting CSS: \(error)")
        }
        
        // Extract inline styles and convert to CSS rules
        // This is a simplified approach - in a full implementation you'd need more sophisticated handling
        
        return (cleanHTML, allCSS)
    }
    
    private func removeComments(from html: String) -> String {
        var cleanHTML = html
        
        while let commentStart = cleanHTML.range(of: "<!--") {
            if let commentEnd = cleanHTML.range(of: "-->", range: commentStart.upperBound..<cleanHTML.endIndex) {
                cleanHTML.removeSubrange(commentStart.lowerBound..<commentEnd.upperBound)
            } else {
                // Unclosed comment, remove to end
                cleanHTML.removeSubrange(commentStart.lowerBound..<cleanHTML.endIndex)
                break
            }
        }
        
        return cleanHTML
    }
    
    // MARK: - HTML Parsing
    
    private func parseHTML(_ html: String) -> DOMNode {
        var index = html.startIndex
        var stack: [DOMNode] = []
        let root = DOMNode(tagName: "root")
        stack.append(root)
        
        while index < html.endIndex {
            if html[index] == "<" {
                index = parseTag(html: html, index: index, stack: &stack)
            } else {
                index = parseText(html: html, index: index, stack: &stack)
            }
        }
        
        return root
    }
    
    private func parseTag(html: String, index: String.Index, stack: inout [DOMNode]) -> String.Index {
        guard let endTag = html[index...].firstIndex(of: ">") else {
            // Malformed tag, skip the '<'
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
                let node = DOMNode(tagName: tagName, attributes: attributes)
                
                // Parse inline styles
                if let styleAttr = attributes["style"] {
                    node.inlineStyle = cssParser.parseInlineStyle(styleAttr)
                }
                
                stack.last?.appendChild(node)
                
                if !isSelfClosing && !isSelfClosingByNature(tagName) {
                    stack.append(node)
                }
            }
        }
        
        return nextIndex
    }
    
    private func parseText(html: String, index: String.Index, stack: inout [DOMNode]) -> String.Index {
        var textEnd = index
        while textEnd < html.endIndex, html[textEnd] != "<" {
            textEnd = html.index(after: textEnd)
        }
        
        let text = String(html[index..<textEnd])
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedText.isEmpty {
            let textNode = DOMNode(textContent: text)
            stack.last?.appendChild(textNode)
        }
        
        return textEnd
    }
    
    private func parseTagContent(_ content: String) -> (tagName: String, attributes: [String: String], isSelfClosing: Bool) {
        var tagString = content.trimmingCharacters(in: .whitespaces)
        var isSelfClosing = false
        
        // Check for self-closing tag syntax
        if tagString.hasSuffix("/") {
            isSelfClosing = true
            tagString = String(tagString.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        
        let scanner = Scanner(string: tagString)
        scanner.charactersToBeSkipped = CharacterSet.whitespaces
        
        guard let tagName = scanner.scanUpToCharacters(from: .whitespaces) ?? scanner.scanUpToString("") else {
            return ("", [:], isSelfClosing)
        }
        
        var attributes: [String: String] = [:]
        
        while !scanner.isAtEnd {
            _ = scanner.scanCharacters(from: .whitespaces)
            
            if let attributeName = scanAttributeName(scanner) {
                let attributeValue = scanAttributeValue(scanner)
                attributes[attributeName.lowercased()] = attributeValue
            } else {
                break
            }
        }
        
        return (tagName.lowercased(), attributes, isSelfClosing)
    }
    
    private func scanAttributeName(_ scanner: Scanner) -> String? {
        return scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "= \t\n\r"))
    }
    
    private func scanAttributeValue(_ scanner: Scanner) -> String {
        _ = scanner.scanCharacters(from: .whitespaces)
        
        if scanner.scanString("=") != nil {
            _ = scanner.scanCharacters(from: .whitespaces)
            
            // Try to scan quoted value first
            if let quotedValue = scanner.scanQuotedString() {
                return quotedValue
            }
            
            // Scan unquoted value
            return scanner.scanUpToCharacters(from: .whitespaces) ?? ""
        } else {
            // Boolean attribute (attribute name without value)
            return ""
        }
    }
    
    private func closeTag(tagName: String, stack: inout [DOMNode]) {
        // Find the matching opening tag in the stack
        for i in (1..<stack.count).reversed() {
            if stack[i].tagName?.lowercased() == tagName {
                // Remove all elements from this position to the end
                stack.removeSubrange(i..<stack.count)
                break
            }
        }
    }
    
    private func isSelfClosingByNature(_ tagName: String) -> Bool {
        let selfClosingTags = [
            "area", "base", "br", "col", "embed", "hr", "img", "input",
            "link", "meta", "param", "source", "track", "wbr",
            // Additional void elements
            "command", "keygen", "menuitem"
        ]
        return selfClosingTags.contains(tagName.lowercased())
    }
}

// MARK: - DOM Tree Utilities

extension DOMNode {
    func findBodyNode() -> DOMNode? {
        if tagName?.lowercased() == "body" {
            return self
        }
        
        for child in children {
            if let bodyNode = child.findBodyNode() {
                return bodyNode
            }
        }
        
        return nil
    }
    
    func extractStylesheets() -> [CSSRule] {
        let cssParser = CSSParser()
        var allRules: [CSSRule] = []
        
        // Check for internal CSS
        if let internalCSS = getAttribute("__internal_css") {
            allRules.append(contentsOf: cssParser.parseStylesheet(internalCSS))
        }
        
        return allRules
    }
    
    func getAllTextContent() -> String {
        if let text = textContent {
            return text
        }
        
        return children.map { $0.getAllTextContent() }.joined()
    }
    
    func countElements() -> Int {
        return 1 + children.reduce(0) { $0 + $1.countElements() }
    }
}
