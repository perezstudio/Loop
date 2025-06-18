//
//  LayoutEngine.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - Layout Engine

class LayoutEngine {
    private let cssParser = CSSParser()
    
    func layout(node: DOMNode, in bounds: CGRect, stylesheet: [CSSRule] = []) {
        // Compute styles first
        computeStyles(for: node, stylesheet: stylesheet)
        
        // Perform layout
        performLayout(node: node, in: bounds)
    }
    
    // MARK: - Style Computation
    
    private func computeStyles(for node: DOMNode, stylesheet: [CSSRule], parentStyle: CSSStyle? = nil) {
        // Start with default styles for the element
        var computedStyle = getDefaultStyle(for: node)
        
        // Apply stylesheet rules
        for rule in stylesheet {
            if matchesSelector(node: node, selector: rule.selector) {
                computedStyle = mergeStyles(computedStyle, rule.style)
            }
        }
        
        // Apply inline styles (highest priority)
        computedStyle = mergeStyles(computedStyle, node.inlineStyle)
        
        // Apply inheritance from parent
        if let parentStyle = parentStyle {
            computedStyle = applyInheritance(computedStyle, from: parentStyle)
        }
        
        node.computedStyle = computedStyle
        
        // Update layout type based on computed styles
        if let display = computedStyle.display {
            switch display {
            case .block: node.layoutType = .block
            case .inline: node.layoutType = .inline
            case .inlineBlock: node.layoutType = .inlineBlock
            case .flex: node.layoutType = .flex
            case .none: node.layoutType = .none
            }
        }
        
        // Recursively compute styles for children
        for child in node.children {
            computeStyles(for: child, stylesheet: stylesheet, parentStyle: computedStyle)
        }
    }
    
    private func getDefaultStyle(for node: DOMNode) -> CSSStyle {
        var style = CSSStyle()
        
        guard let tagName = node.tagName?.lowercased() else {
            // Text node defaults
            style.fontSize = 16
            style.color = .primary
            return style
        }
        
        switch tagName {
        case "h1":
            style.fontSize = 32
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        case "h2":
            style.fontSize = 24
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
        case "h3":
            style.fontSize = 20
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
        case "h4":
            style.fontSize = 18
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        case "h5":
            style.fontSize = 16
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        case "h6":
            style.fontSize = 14
            style.fontWeight = .bold
            style.margin = EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        case "p":
            style.fontSize = 16
            style.margin = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        case "div", "section", "article", "header", "footer", "nav", "aside", "main":
            style.fontSize = 16
        case "strong", "b":
            style.fontWeight = .bold
        case "em", "i":
            style.fontSize = 16 // Will be styled as italic in view
        case "a":
            style.color = .blue
        case "ul", "ol":
            style.margin = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
            style.padding = EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0)
        case "li":
            style.margin = EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
        case "blockquote":
            style.margin = EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)
            style.padding = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            style.backgroundColor = Color.gray.opacity(0.1)
        case "code":
            style.backgroundColor = Color.gray.opacity(0.2)
            style.padding = EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
        case "pre":
            style.backgroundColor = Color.gray.opacity(0.1)
            style.padding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            style.margin = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        default:
            style.fontSize = 16
        }
        
        style.color = style.color ?? .primary
        return style
    }
    
    private func matchesSelector(node: DOMNode, selector: String) -> Bool {
        let trimmedSelector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simple element selector
        if let tagName = node.tagName, trimmedSelector == tagName.lowercased() {
            return true
        }
        
        // Class selector
        if trimmedSelector.hasPrefix(".") {
            let className = String(trimmedSelector.dropFirst())
            if let classAttr = node.getAttribute("class") {
                let classes = classAttr.components(separatedBy: .whitespaces)
                return classes.contains(className)
            }
        }
        
        // ID selector
        if trimmedSelector.hasPrefix("#") {
            let idName = String(trimmedSelector.dropFirst())
            return node.getAttribute("id") == idName
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
        
        // Font properties are inherited
        if inherited.fontSize == nil, let parentFontSize = parentStyle.fontSize {
            inherited.fontSize = parentFontSize
        }
        if inherited.fontWeight == nil, let parentFontWeight = parentStyle.fontWeight {
            inherited.fontWeight = parentFontWeight
        }
        if inherited.color == nil, let parentColor = parentStyle.color {
            inherited.color = parentColor
        }
        
        return inherited
    }
    
    // MARK: - Layout Computation
    
    private func performLayout(node: DOMNode, in bounds: CGRect) {
        guard node.layoutType != .none else { return }
        
        // Skip layout if not needed and we have a valid frame
        if !node.needsLayout && node.frame != .zero {
            return
        }
        
        switch node.layoutType {
        case .block:
            layoutBlock(node: node, in: bounds)
        case .inline:
            layoutInline(node: node, in: bounds)
        case .inlineBlock:
            layoutInlineBlock(node: node, in: bounds)
        case .flex:
            layoutFlex(node: node, in: bounds)
        case .table:
            layoutTable(node: node, in: bounds)
        case .tableRow:
            layoutTableRow(node: node, in: bounds)
        case .tableCell:
            layoutTableCell(node: node, in: bounds)
        case .none:
            break
        }
        
        node.needsLayout = false
    }
    
    private func layoutBlock(node: DOMNode, in bounds: CGRect) {
        // Block elements stack vertically and take full width
        var currentY: CGFloat = bounds.minY
        let availableWidth = bounds.width
        
        // Apply margins and padding
        let style = node.computedStyle
        let margin = style.margin ?? EdgeInsets()
        let padding = style.padding ?? EdgeInsets()
        
        currentY += margin.top + padding.top
        let contentWidth = availableWidth - margin.leading - margin.trailing - padding.leading - padding.trailing
        
        for child in node.children {
            let childBounds = CGRect(
                x: bounds.minX + margin.leading + padding.leading,
                y: currentY,
                width: contentWidth,
                height: bounds.height - currentY + bounds.minY
            )
            
            performLayout(node: child, in: childBounds)
            
            if child.layoutType == .block || child.layoutType == .inlineBlock {
                currentY += child.frame.height
                if let childMargin = child.computedStyle.margin {
                    currentY += childMargin.bottom
                }
            }
        }
        
        let totalHeight = currentY - bounds.minY + margin.bottom + padding.bottom
        node.frame = CGRect(x: bounds.minX, y: bounds.minY, width: availableWidth, height: totalHeight)
        
        // Update box model
        node.boxModel.content = CGSize(width: contentWidth, height: totalHeight - margin.top - margin.bottom - padding.top - padding.bottom)
        node.boxModel.padding = padding
        node.boxModel.margin = margin
    }
    
    private func layoutInline(node: DOMNode, in bounds: CGRect) {
        // Inline elements flow horizontally
        if node.isTextNode {
            layoutText(node: node, in: bounds)
        } else {
            // For inline elements with children, layout children inline
            var currentX: CGFloat = bounds.minX
            let availableWidth = bounds.width
            let availableHeight = bounds.height
            
            for child in node.children {
                let remainingWidth = availableWidth - (currentX - bounds.minX)
                let childBounds = CGRect(
                    x: currentX,
                    y: bounds.minY,
                    width: remainingWidth,
                    height: availableHeight
                )
                
                performLayout(node: child, in: childBounds)
                currentX += child.frame.width
            }
            
            let totalWidth = currentX - bounds.minX
            node.frame = CGRect(x: bounds.minX, y: bounds.minY, width: totalWidth, height: bounds.height)
        }
    }
    
    private func layoutInlineBlock(node: DOMNode, in bounds: CGRect) {
        // Inline-block elements have internal block layout but flow inline
        layoutBlock(node: node, in: bounds)
    }
    
    private func layoutText(node: DOMNode, in bounds: CGRect) {
        guard let text = node.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            node.frame = CGRect(x: bounds.minX, y: bounds.minY, width: 0, height: 0)
            return
        }
        
        let style = node.computedStyle
        let fontSize = style.fontSize ?? 16
        // Note: Font.system is just for approximation, actual rendering uses CoreText
        
        // Calculate text size (simplified - in real implementation you'd use CoreText)
        let estimatedCharWidth = fontSize * 0.6 // Rough approximation
        let estimatedLineHeight = fontSize * 1.2
        
        let charactersPerLine = max(1, Int(bounds.width / estimatedCharWidth))
        let lines = stride(from: 0, to: text.count, by: charactersPerLine).map { i in
            let endIndex = min(i + charactersPerLine, text.count)
            return String(text[text.index(text.startIndex, offsetBy: i)..<text.index(text.startIndex, offsetBy: endIndex)])
        }
        
        let textWidth = min(bounds.width, CGFloat(text.count) * estimatedCharWidth)
        let textHeight = CGFloat(lines.count) * estimatedLineHeight
        
        node.frame = CGRect(x: bounds.minX, y: bounds.minY, width: textWidth, height: textHeight)
        node.intrinsicSize = CGSize(width: textWidth, height: textHeight)
    }
    
    private func layoutFlex(node: DOMNode, in bounds: CGRect) {
        // Simplified flexbox implementation
        layoutBlock(node: node, in: bounds) // Fallback to block for now
    }
    
    private func layoutTable(node: DOMNode, in bounds: CGRect) {
        // Simplified table layout
        layoutBlock(node: node, in: bounds) // Fallback to block for now
    }
    
    private func layoutTableRow(node: DOMNode, in bounds: CGRect) {
        // Layout table cells horizontally
        var currentX: CGFloat = bounds.minX
        let availableHeight = bounds.height
        let cellCount = node.children.count
        let cellWidth = cellCount > 0 ? bounds.width / CGFloat(cellCount) : bounds.width
        
        for child in node.children {
            let childBounds = CGRect(
                x: currentX,
                y: bounds.minY,
                width: cellWidth,
                height: availableHeight
            )
            
            performLayout(node: child, in: childBounds)
            currentX += cellWidth
        }
        
        node.frame = bounds
    }
    
    private func layoutTableCell(node: DOMNode, in bounds: CGRect) {
        // Table cells are like block elements but constrained by the table
        layoutBlock(node: node, in: bounds)
    }
}
