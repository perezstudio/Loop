//
//  SelectorEngine.swift
//  Loop - WebKit-Inspired CSS Selector Engine
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation

// MARK: - Selector Engine

class SelectorEngine {
    
    // MARK: - Selector Matching
    
    func matches(_ element: WebCoreElement, selector: CSSSelector) -> Bool {
        return matches(element, selectorString: selector.raw)
    }
    
    private func matches(_ element: WebCoreElement, selectorString: String) -> Bool {
        let trimmedSelector = selectorString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle multiple selectors (comma-separated)
        if trimmedSelector.contains(",") {
            let selectors = trimmedSelector.components(separatedBy: ",")
            return selectors.contains { selector in
                matches(element, selectorString: selector.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        
        // Handle descendant selectors (space-separated)
        if trimmedSelector.contains(" ") {
            return matchesDescendantSelector(element, selector: trimmedSelector)
        }
        
        // Handle child selectors (>)
        if trimmedSelector.contains(">") {
            return matchesChildSelector(element, selector: trimmedSelector)
        }
        
        // Handle adjacent sibling selectors (+)
        if trimmedSelector.contains("+") {
            return matchesAdjacentSiblingSelector(element, selector: trimmedSelector)
        }
        
        // Handle general sibling selectors (~)
        if trimmedSelector.contains("~") {
            return matchesGeneralSiblingSelector(element, selector: trimmedSelector)
        }
        
        // Simple selector
        return matchesSimpleSelector(element, selector: trimmedSelector)
    }
    
    // MARK: - Simple Selector Matching
    
    private func matchesSimpleSelector(_ element: WebCoreElement, selector: String) -> Bool {
        var remainingSelector = selector
        var matched = true
        
        // Parse compound selector (e.g., "div.class#id[attr]")
        while !remainingSelector.isEmpty && matched {
            if remainingSelector.hasPrefix("#") {
                // ID selector
                let (idSelector, remaining) = extractIDSelector(from: remainingSelector)
                matched = matchesIDSelector(element, id: idSelector)
                remainingSelector = remaining
            } else if remainingSelector.hasPrefix(".") {
                // Class selector
                let (classSelector, remaining) = extractClassSelector(from: remainingSelector)
                matched = matchesClassSelector(element, className: classSelector)
                remainingSelector = remaining
            } else if remainingSelector.hasPrefix("[") {
                // Attribute selector
                let (attributeSelector, remaining) = extractAttributeSelector(from: remainingSelector)
                matched = matchesAttributeSelector(element, attributeSelector: attributeSelector)
                remainingSelector = remaining
            } else if remainingSelector.hasPrefix(":") {
                // Pseudo-class selector
                let (pseudoSelector, remaining) = extractPseudoSelector(from: remainingSelector)
                matched = matchesPseudoSelector(element, pseudo: pseudoSelector)
                remainingSelector = remaining
            } else if remainingSelector == "*" {
                // Universal selector
                matched = true
                remainingSelector = ""
            } else {
                // Type selector
                let (typeSelector, remaining) = extractTypeSelector(from: remainingSelector)
                matched = matchesTypeSelector(element, type: typeSelector)
                remainingSelector = remaining
            }
        }
        
        return matched
    }
    
    // MARK: - Combinator Matching
    
    private func matchesDescendantSelector(_ element: WebCoreElement, selector: String) -> Bool {
        let parts = selector.components(separatedBy: " ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count >= 2 else { return false }
        
        let targetSelector = parts.last!
        let ancestorSelectors = Array(parts.dropLast())
        
        // Target must match
        guard matchesSimpleSelector(element, selector: targetSelector) else { return false }
        
        // Find matching ancestors
        return hasMatchingAncestors(element, selectors: ancestorSelectors)
    }
    
    private func matchesChildSelector(_ element: WebCoreElement, selector: String) -> Bool {
        let parts = selector.components(separatedBy: ">").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2 else { return false }
        
        let parentSelector = parts[0]
        let childSelector = parts[1]
        
        // Child must match
        guard matchesSimpleSelector(element, selector: childSelector) else { return false }
        
        // Parent must match
        guard let parent = element.parentNode as? WebCoreElement else { return false }
        return matchesSimpleSelector(parent, selector: parentSelector)
    }
    
    private func matchesAdjacentSiblingSelector(_ element: WebCoreElement, selector: String) -> Bool {
        let parts = selector.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2 else { return false }
        
        let firstSelector = parts[0]
        let secondSelector = parts[1]
        
        // Second element must match
        guard matchesSimpleSelector(element, selector: secondSelector) else { return false }
        
        // Previous sibling must match
        guard let previousSibling = element.previousElementSibling else { return false }
        return matchesSimpleSelector(previousSibling, selector: firstSelector)
    }
    
    private func matchesGeneralSiblingSelector(_ element: WebCoreElement, selector: String) -> Bool {
        let parts = selector.components(separatedBy: "~").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2 else { return false }
        
        let firstSelector = parts[0]
        let secondSelector = parts[1]
        
        // Second element must match
        guard matchesSimpleSelector(element, selector: secondSelector) else { return false }
        
        // Find previous siblings that match
        var sibling = element.previousElementSibling
        while let currentSibling = sibling {
            if matchesSimpleSelector(currentSibling, selector: firstSelector) {
                return true
            }
            sibling = currentSibling.previousElementSibling
        }
        
        return false
    }
    
    // MARK: - Individual Selector Type Matching
    
    private func matchesTypeSelector(_ element: WebCoreElement, type: String) -> Bool {
        return element.tagName.lowercased() == type.lowercased()
    }
    
    private func matchesIDSelector(_ element: WebCoreElement, id: String) -> Bool {
        return element.getAttribute("id") == id
    }
    
    private func matchesClassSelector(_ element: WebCoreElement, className: String) -> Bool {
        guard let classAttr = element.getAttribute("class") else { return false }
        let classes = Set(classAttr.components(separatedBy: .whitespaces))
        return classes.contains(className)
    }
    
    private func matchesAttributeSelector(_ element: WebCoreElement, attributeSelector: String) -> Bool {
        // Parse attribute selector [attr] or [attr=value] or [attr~=value] etc.
        if attributeSelector == "" { return true }
        
        // Remove brackets
        var selector = attributeSelector
        if selector.hasPrefix("[") && selector.hasSuffix("]") {
            selector = String(selector.dropFirst().dropLast())
        }
        
        // Simple attribute existence check
        if !selector.contains("=") {
            return element.hasAttribute(selector)
        }
        
        // Attribute value matching
        if selector.contains("=") {
            let parts = selector.components(separatedBy: "=")
            guard parts.count == 2 else { return false }
            
            let attributeName = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let expectedValue = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            
            // Handle different attribute operators
            if attributeName.hasSuffix("~") {
                // Word match [attr~=value]
                let attrName = String(attributeName.dropLast())
                guard let attrValue = element.getAttribute(attrName) else { return false }
                let words = Set(attrValue.components(separatedBy: .whitespaces))
                return words.contains(expectedValue)
            } else if attributeName.hasSuffix("|") {
                // Language match [attr|=value]
                let attrName = String(attributeName.dropLast())
                guard let attrValue = element.getAttribute(attrName) else { return false }
                return attrValue == expectedValue || attrValue.hasPrefix(expectedValue + "-")
            } else if attributeName.hasSuffix("^") {
                // Prefix match [attr^=value]
                let attrName = String(attributeName.dropLast())
                guard let attrValue = element.getAttribute(attrName) else { return false }
                return attrValue.hasPrefix(expectedValue)
            } else if attributeName.hasSuffix("$") {
                // Suffix match [attr$=value]
                let attrName = String(attributeName.dropLast())
                guard let attrValue = element.getAttribute(attrName) else { return false }
                return attrValue.hasSuffix(expectedValue)
            } else if attributeName.hasSuffix("*") {
                // Substring match [attr*=value]
                let attrName = String(attributeName.dropLast())
                guard let attrValue = element.getAttribute(attrName) else { return false }
                return attrValue.contains(expectedValue)
            } else {
                // Exact match [attr=value]
                return element.getAttribute(attributeName) == expectedValue
            }
        }
        
        return false
    }
    
    private func matchesPseudoSelector(_ element: WebCoreElement, pseudo: String) -> Bool {
        switch pseudo.lowercased() {
        case "first-child":
            return element.previousElementSibling == nil
        case "last-child":
            return element.nextElementSibling == nil
        case "first-of-type":
            return isFirstOfType(element)
        case "last-of-type":
            return isLastOfType(element)
        case "only-child":
            return element.previousElementSibling == nil && element.nextElementSibling == nil
        case "only-of-type":
            return isFirstOfType(element) && isLastOfType(element)
        case "empty":
            return element.childNodes.isEmpty
        case "root":
            return element.parentNode?.nodeType == .document
        default:
            // Handle nth-child, nth-of-type, etc.
            if pseudo.hasPrefix("nth-child(") {
                return matchesNthChild(element, formula: extractNthFormula(from: pseudo))
            } else if pseudo.hasPrefix("nth-of-type(") {
                return matchesNthOfType(element, formula: extractNthFormula(from: pseudo))
            }
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func hasMatchingAncestors(_ element: WebCoreElement, selectors: [String]) -> Bool {
        guard !selectors.isEmpty else { return true }
        
        var remainingSelectors = Array(selectors.reversed())
        var currentElement: WebCoreElement? = element.parentNode as? WebCoreElement
        
        while let element = currentElement, !remainingSelectors.isEmpty {
            if matchesSimpleSelector(element, selector: remainingSelectors.first!) {
                remainingSelectors.removeFirst()
            }
            currentElement = element.parentNode as? WebCoreElement
        }
        
        return remainingSelectors.isEmpty
    }
    
    private func isFirstOfType(_ element: WebCoreElement) -> Bool {
        let tagName = element.tagName
        var sibling = element.previousElementSibling
        
        while let currentSibling = sibling {
            if currentSibling.tagName == tagName {
                return false
            }
            sibling = currentSibling.previousElementSibling
        }
        
        return true
    }
    
    private func isLastOfType(_ element: WebCoreElement) -> Bool {
        let tagName = element.tagName
        var sibling = element.nextElementSibling
        
        while let currentSibling = sibling {
            if currentSibling.tagName == tagName {
                return false
            }
            sibling = currentSibling.nextElementSibling
        }
        
        return true
    }
    
    private func matchesNthChild(_ element: WebCoreElement, formula: NthFormula) -> Bool {
        guard let parent = element.parentNode as? WebCoreElement else { return false }
        
        let siblings = parent.children
        guard let index = siblings.firstIndex(where: { $0.id == element.id }) else { return false }
        
        let position = index + 1 // 1-based indexing
        return formula.matches(position)
    }
    
    private func matchesNthOfType(_ element: WebCoreElement, formula: NthFormula) -> Bool {
        guard let parent = element.parentNode as? WebCoreElement else { return false }
        
        let siblingsOfSameType = parent.children.filter { $0.tagName == element.tagName }
        guard let index = siblingsOfSameType.firstIndex(where: { $0.id == element.id }) else { return false }
        
        let position = index + 1 // 1-based indexing
        return formula.matches(position)
    }
    
    // MARK: - Selector Parsing Helpers
    
    private func extractIDSelector(from selector: String) -> (String, String) {
        guard selector.hasPrefix("#") else { return ("", selector) }
        
        let remaining = String(selector.dropFirst())
        let endIndex = remaining.firstIndex { char in
            return ".#[:".contains(char)
        } ?? remaining.endIndex
        
        let id = String(remaining[..<endIndex])
        let remainingSelector = String(remaining[endIndex...])
        
        return (id, remainingSelector)
    }
    
    private func extractClassSelector(from selector: String) -> (String, String) {
        guard selector.hasPrefix(".") else { return ("", selector) }
        
        let remaining = String(selector.dropFirst())
        let endIndex = remaining.firstIndex { char in
            return ".#[:".contains(char)
        } ?? remaining.endIndex
        
        let className = String(remaining[..<endIndex])
        let remainingSelector = String(remaining[endIndex...])
        
        return (className, remainingSelector)
    }
    
    private func extractAttributeSelector(from selector: String) -> (String, String) {
        guard selector.hasPrefix("[") else { return ("", selector) }
        
        guard let endBracket = selector.firstIndex(of: "]") else { return ("", selector) }
        
        let attributeSelector = String(selector[...endBracket])
        let remainingSelector = String(selector[selector.index(after: endBracket)...])
        
        return (attributeSelector, remainingSelector)
    }
    
    private func extractPseudoSelector(from selector: String) -> (String, String) {
        guard selector.hasPrefix(":") else { return ("", selector) }
        
        let remaining = String(selector.dropFirst())
        
        // Handle pseudo-classes with parentheses
        if let parenIndex = remaining.firstIndex(of: "(") {
            if let closeParen = remaining.firstIndex(of: ")") {
                let pseudo = String(remaining[..<remaining.index(after: closeParen)])
                let remainingSelector = String(remaining[remaining.index(after: closeParen)...])
                return (pseudo, remainingSelector)
            }
        }
        
        // Simple pseudo-class
        let endIndex = remaining.firstIndex { char in
            return ".#[:".contains(char)
        } ?? remaining.endIndex
        
        let pseudo = String(remaining[..<endIndex])
        let remainingSelector = String(remaining[endIndex...])
        
        return (pseudo, remainingSelector)
    }
    
    private func extractTypeSelector(from selector: String) -> (String, String) {
        let endIndex = selector.firstIndex { char in
            return ".#[:".contains(char)
        } ?? selector.endIndex
        
        let type = String(selector[..<endIndex])
        let remainingSelector = String(selector[endIndex...])
        
        return (type, remainingSelector)
    }
    
    private func extractNthFormula(from pseudo: String) -> NthFormula {
        // Extract content between parentheses
        guard let startParen = pseudo.firstIndex(of: "("),
              let endParen = pseudo.lastIndex(of: ")") else {
            return NthFormula(a: 0, b: 1) // Default to first element
        }
        
        let formula = String(pseudo[pseudo.index(after: startParen)..<endParen])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return NthFormula.parse(formula)
    }
    
    // MARK: - Specificity Calculation
    
    func calculateSpecificity(_ selector: CSSSelector) -> SelectorSpecificity {
        return calculateSpecificity(selector.raw)
    }
    
    private func calculateSpecificity(_ selectorString: String) -> SelectorSpecificity {
        var specificity = SelectorSpecificity()
        
        // Handle multiple selectors (take highest specificity)
        if selectorString.contains(",") {
            let selectors = selectorString.components(separatedBy: ",")
            return selectors.map { calculateSpecificity($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                          .max() ?? specificity
        }
        
        // Split by combinators and calculate for each part
        let parts = selectorString.components(separatedBy: CharacterSet(charactersIn: " >+~"))
        
        for part in parts {
            let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPart.isEmpty else { continue }
            
            specificity = specificity + calculateSimpleSelectorSpecificity(trimmedPart)
        }
        
        return specificity
    }
    
    private func calculateSimpleSelectorSpecificity(_ selector: String) -> SelectorSpecificity {
        var specificity = SelectorSpecificity()
        var remaining = selector
        
        while !remaining.isEmpty {
            if remaining.hasPrefix("#") {
                specificity.ids += 1
                let (_, newRemaining) = extractIDSelector(from: remaining)
                remaining = newRemaining
            } else if remaining.hasPrefix(".") {
                specificity.classes += 1
                let (_, newRemaining) = extractClassSelector(from: remaining)
                remaining = newRemaining
            } else if remaining.hasPrefix("[") {
                specificity.classes += 1
                let (_, newRemaining) = extractAttributeSelector(from: remaining)
                remaining = newRemaining
            } else if remaining.hasPrefix(":") {
                specificity.classes += 1
                let (_, newRemaining) = extractPseudoSelector(from: remaining)
                remaining = newRemaining
            } else if remaining == "*" {
                // Universal selector adds no specificity
                remaining = ""
            } else {
                // Type selector
                specificity.elements += 1
                let (_, newRemaining) = extractTypeSelector(from: remaining)
                remaining = newRemaining
            }
        }
        
        return specificity
    }
}

// MARK: - Selector Specificity

struct SelectorSpecificity: Comparable {
    var ids: Int = 0
    var classes: Int = 0
    var elements: Int = 0
    
    static func < (lhs: SelectorSpecificity, rhs: SelectorSpecificity) -> Bool {
        if lhs.ids != rhs.ids {
            return lhs.ids < rhs.ids
        }
        if lhs.classes != rhs.classes {
            return lhs.classes < rhs.classes
        }
        return lhs.elements < rhs.elements
    }
    
    static func + (lhs: SelectorSpecificity, rhs: SelectorSpecificity) -> SelectorSpecificity {
        return SelectorSpecificity(
            ids: lhs.ids + rhs.ids,
            classes: lhs.classes + rhs.classes,
            elements: lhs.elements + rhs.elements
        )
    }
}

// MARK: - Nth Formula

struct NthFormula {
    let a: Int
    let b: Int
    
    func matches(_ n: Int) -> Bool {
        if a == 0 {
            return n == b
        } else {
            let diff = n - b
            return diff >= 0 && diff % a == 0
        }
    }
    
    static func parse(_ formula: String) -> NthFormula {
        let cleaned = formula.lowercased().replacingOccurrences(of: " ", with: "")
        
        // Handle keywords
        switch cleaned {
        case "odd":
            return NthFormula(a: 2, b: 1)
        case "even":
            return NthFormula(a: 2, b: 0)
        default:
            break
        }
        
        // Parse an+b formula
        if cleaned.contains("n") {
            let parts = cleaned.components(separatedBy: "n")
            let aPart = parts[0]
            let bPart = parts.count > 1 ? parts[1] : ""
            
            let a: Int
            if aPart.isEmpty || aPart == "+" {
                a = 1
            } else if aPart == "-" {
                a = -1
            } else {
                a = Int(aPart) ?? 0
            }
            
            let b: Int
            if bPart.isEmpty {
                b = 0
            } else if bPart.hasPrefix("+") {
                b = Int(String(bPart.dropFirst())) ?? 0
            } else if bPart.hasPrefix("-") {
                b = Int(bPart) ?? 0
            } else {
                b = Int(bPart) ?? 0
            }
            
            return NthFormula(a: a, b: b)
        } else {
            // Just a number
            let b = Int(cleaned) ?? 1
            return NthFormula(a: 0, b: b)
        }
    }
}
