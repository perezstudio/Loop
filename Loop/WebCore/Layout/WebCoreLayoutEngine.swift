//
//  WebCoreLayoutEngine.swift
//  Loop - WebKit-Inspired Layout Engine
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics

// MARK: - Layout Engine Delegate

protocol WebCoreLayoutEngineDelegate: AnyObject {
    func layoutEngineDidCompleteLayout(_ engine: WebCoreLayoutEngine)
    func layoutEngineDidInvalidate(_ engine: WebCoreLayoutEngine, rect: CGRect)
}

// MARK: - WebCore Layout Engine

class WebCoreLayoutEngine {
    
    // MARK: - Properties
    
    private let configuration: WebCore.Configuration
    private let blockFormatter: BlockFormattingContext
    private let inlineFormatter: InlineFormattingContext
    private let flexFormatter: FlexFormattingContext
    
    weak var delegate: WebCoreLayoutEngineDelegate?
    
    // MARK: - Initialization
    
    init(configuration: WebCore.Configuration) {
        self.configuration = configuration
        self.blockFormatter = BlockFormattingContext()
        self.inlineFormatter = InlineFormattingContext()
        self.flexFormatter = FlexFormattingContext()
        
        print("📐 WebCore Layout Engine initialized")
    }
    
    // MARK: - Layout Management
    
    func layout(_ renderObject: RenderObject, context: WebCore.LayoutContext) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        if context.enableDebugging {
            print("📐 Starting layout for render tree...")
        }
        
        // Perform layout based on the root's display type
        try await layoutRenderObject(renderObject, in: context.viewport, context: context)
        
        let layoutTime = CFAbsoluteTimeGetCurrent() - startTime
        
        if context.enableDebugging {
            print("📐 Layout completed in \(String(format: "%.2f", layoutTime * 1000))ms")
        }
        
        delegate?.layoutEngineDidCompleteLayout(self)
    }
    
    private func layoutRenderObject(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        guard let computedStyle = renderObject.computedStyle else {
            throw LayoutError.missingComputedStyle
        }
        
        // Determine layout method based on display type
        switch computedStyle.display {
        case .block:
            try await layoutBlock(renderObject, in: containingBlock, context: context)
        case .inline:
            try await layoutInline(renderObject, in: containingBlock, context: context)
        case .inlineBlock:
            try await layoutInlineBlock(renderObject, in: containingBlock, context: context)
        case .flex:
            try await layoutFlex(renderObject, in: containingBlock, context: context)
        case .grid:
            try await layoutGrid(renderObject, in: containingBlock, context: context)
        case .table:
            try await layoutTable(renderObject, in: containingBlock, context: context)
        case .tableRow:
            try await layoutTableRow(renderObject, in: containingBlock, context: context)
        case .tableCell:
            try await layoutTableCell(renderObject, in: containingBlock, context: context)
        case .none:
            // Hidden elements don't participate in layout
            renderObject.frame = .zero
            return
        }
        
        // Mark as laid out
        renderObject.needsLayout = false
    }
    
    // MARK: - Block Layout
    
    private func layoutBlock(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        let style = renderObject.computedStyle!
        
        // Calculate margins and padding
        let margins = resolveEdgeInsets(
            top: style.marginTop,
            right: style.marginRight,
            bottom: style.marginBottom,
            left: style.marginLeft,
            relativeTo: containingBlock.width,
            fontSize: style.resolvedFontSize()
        )
        
        let padding = resolveEdgeInsets(
            top: style.paddingTop,
            right: style.paddingRight,
            bottom: style.paddingBottom,
            left: style.paddingLeft,
            relativeTo: containingBlock.width,
            fontSize: style.resolvedFontSize()
        )
        
        // Calculate width
        let availableWidth = containingBlock.width - margins.left - margins.right
        let width = resolveWidth(style.width, availableWidth: availableWidth, fontSize: style.resolvedFontSize()) ?? availableWidth
        
        // Calculate content area
        let contentWidth = width - padding.left - padding.right
        let contentRect = CGRect(
            x: containingBlock.minX + margins.left + padding.left,
            y: containingBlock.minY + margins.top + padding.top,
            width: contentWidth,
            height: 0 // Will be calculated based on children
        )
        
        // Layout children using block formatting context
        let childrenHeight = try await blockFormatter.layoutChildren(
            renderObject.children,
            in: contentRect,
            context: context
        )
        
        // Calculate final height
        let contentHeight = resolveHeight(style.height, availableHeight: containingBlock.height, fontSize: style.resolvedFontSize()) ?? childrenHeight
        
        // Set final frame
        renderObject.frame = CGRect(
            x: containingBlock.minX + margins.left,
            y: containingBlock.minY + margins.top,
            width: width,
            height: contentHeight + padding.top + padding.bottom
        )
        
        renderObject.contentRect = CGRect(
            x: padding.left,
            y: padding.top,
            width: contentWidth,
            height: contentHeight
        )
        
        if context.enableDebugging {
            print("📐 Block layout: \(renderObject.debugDescription) -> \(renderObject.frame)")
        }
    }
    
    // MARK: - Inline Layout
    
    private func layoutInline(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        // Inline elements are laid out by their parent's inline formatting context
        // This method handles the case where an inline element is the root
        try await inlineFormatter.layoutInlineElement(renderObject, in: containingBlock, context: context)
    }
    
    // MARK: - Inline-Block Layout
    
    private func layoutInlineBlock(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        // Inline-block elements are treated as blocks internally but participate in inline layout externally
        try await layoutBlock(renderObject, in: containingBlock, context: context)
    }
    
    // MARK: - Flex Layout
    
    private func layoutFlex(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        try await flexFormatter.layoutFlexContainer(renderObject, in: containingBlock, context: context)
    }
    
    // MARK: - Grid Layout (Placeholder)
    
    private func layoutGrid(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        // Grid layout not yet implemented - fall back to block
        try await layoutBlock(renderObject, in: containingBlock, context: context)
    }
    
    // MARK: - Table Layout (Placeholder)
    
    private func layoutTable(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        // Table layout not yet implemented - fall back to block
        try await layoutBlock(renderObject, in: containingBlock, context: context)
    }
    
    private func layoutTableRow(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        // Table row layout not yet implemented - fall back to block
        try await layoutBlock(renderObject, in: containingBlock, context: context)
    }
    
    private func layoutTableCell(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        // Table cell layout not yet implemented - fall back to block
        try await layoutBlock(renderObject, in: containingBlock, context: context)
    }
    
    // MARK: - Helper Methods
    
    private func resolveEdgeInsets(
        top: LengthValue,
        right: LengthValue,
        bottom: LengthValue,
        left: LengthValue,
        relativeTo containerSize: CGFloat,
        fontSize: CGFloat
    ) -> NSEdgeInsets {
        return NSEdgeInsets(
            top: top.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
            left: left.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
            bottom: bottom.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
            right: right.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0
        )
    }
    
    private func resolveWidth(_ width: LengthValue, availableWidth: CGFloat, fontSize: CGFloat) -> CGFloat? {
        return width.resolveLength(relativeTo: availableWidth, fontSize: fontSize)
    }
    
    private func resolveHeight(_ height: LengthValue, availableHeight: CGFloat, fontSize: CGFloat) -> CGFloat? {
        return height.resolveLength(relativeTo: availableHeight, fontSize: fontSize)
    }
}

// MARK: - Block Formatting Context

class BlockFormattingContext {
    
    func layoutChildren(_ children: [RenderObject], in contentRect: CGRect, context: WebCore.LayoutContext) async throws -> CGFloat {
        var currentY = contentRect.minY
        let availableWidth = contentRect.width
        
        for child in children {
            guard let childStyle = child.computedStyle else { continue }
            
            // Skip elements that don't participate in normal flow
            if childStyle.display == .none || childStyle.position == .absolute || childStyle.position == .fixed {
                continue
            }
            
            // Calculate child's containing block
            let childContainingBlock = CGRect(
                x: contentRect.minX,
                y: currentY,
                width: availableWidth,
                height: contentRect.maxY - currentY
            )
            
            // Layout the child
            try await layoutChild(child, in: childContainingBlock, context: context)
            
            // Advance Y position for next child
            if childStyle.display == .block || childStyle.display == .flex || childStyle.display == .table {
                currentY = child.frame.maxY
                
                // Add bottom margin
                if let bottomMargin = childStyle.marginBottom.resolveLength(relativeTo: availableWidth, fontSize: childStyle.resolvedFontSize()) {
                    currentY += bottomMargin
                }
            }
        }
        
        return currentY - contentRect.minY
    }
    
    private func layoutChild(_ child: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        // This would delegate to the main layout engine
        // For now, simplified implementation
        child.frame = containingBlock
    }
}

// MARK: - Inline Formatting Context

class InlineFormattingContext {
    
    func layoutInlineElement(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        // Simplified inline layout - this would be much more complex in a real implementation
        if let textContent = renderObject.element?.textContent {
            let fontSize = renderObject.computedStyle?.resolvedFontSize() ?? 16
            let estimatedWidth = CGFloat(textContent.count) * fontSize * 0.6
            let estimatedHeight = fontSize * 1.2
            
            renderObject.frame = CGRect(
                x: containingBlock.minX,
                y: containingBlock.minY,
                width: min(estimatedWidth, containingBlock.width),
                height: estimatedHeight
            )
        } else {
            renderObject.frame = CGRect(
                x: containingBlock.minX,
                y: containingBlock.minY,
                width: 0,
                height: 0
            )
        }
    }
}

// MARK: - Flex Formatting Context

class FlexFormattingContext {
    
    func layoutFlexContainer(_ renderObject: RenderObject, in containingBlock: CGRect, context: WebCore.LayoutContext) async throws {
        guard let style = renderObject.computedStyle else { return }
        
        // Calculate margins and padding
        let margins = resolveEdgeInsets(style, relativeTo: containingBlock.width)
        let padding = resolveEdgeInsets(style, relativeTo: containingBlock.width, isPadding: true)
        
        // Calculate container size
        let availableWidth = containingBlock.width - margins.left - margins.right
        let containerWidth = style.width.resolveLength(relativeTo: availableWidth, fontSize: style.resolvedFontSize()) ?? availableWidth
        let contentWidth = containerWidth - padding.left - padding.right
        
        // Create flex line
        let flexLine = FlexLine(
            direction: style.flexDirection,
            justifyContent: style.justifyContent,
            alignItems: style.alignItems,
            availableSpace: CGSize(width: contentWidth, height: containingBlock.height)
        )
        
        // Add flex items
        for child in renderObject.children {
            guard let childStyle = child.computedStyle,
                  childStyle.display != .none else { continue }
            
            let flexItem = FlexItem(renderObject: child, style: childStyle)
            flexLine.addItem(flexItem)
        }
        
        // Resolve flex item sizes and layout
        try await flexLine.layout(context: context)
        
        // Set container frame
        let contentHeight = flexLine.crossSize
        renderObject.frame = CGRect(
            x: containingBlock.minX + margins.left,
            y: containingBlock.minY + margins.top,
            width: containerWidth,
            height: contentHeight + padding.top + padding.bottom
        )
        
        renderObject.contentRect = CGRect(
            x: padding.left,
            y: padding.top,
            width: contentWidth,
            height: contentHeight
        )
    }
    
    private func resolveEdgeInsets(_ style: ComputedStyle, relativeTo containerSize: CGFloat, isPadding: Bool = false) -> NSEdgeInsets {
        let fontSize = style.resolvedFontSize()
        
        if isPadding {
            return NSEdgeInsets(
                top: style.paddingTop.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
                left: style.paddingLeft.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
                bottom: style.paddingBottom.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
                right: style.paddingRight.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0
            )
        } else {
            return NSEdgeInsets(
                top: style.marginTop.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
                left: style.marginLeft.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
                bottom: style.marginBottom.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0,
                right: style.marginRight.resolveLength(relativeTo: containerSize, fontSize: fontSize) ?? 0
            )
        }
    }
}

// MARK: - Flex Layout Support

class FlexLine {
    let direction: FlexDirectionValue
    let justifyContent: JustifyContentValue
    let alignItems: AlignItemsValue
    let availableSpace: CGSize
    
    private var items: [FlexItem] = []
    private(set) var crossSize: CGFloat = 0
    
    init(direction: FlexDirectionValue, justifyContent: JustifyContentValue, alignItems: AlignItemsValue, availableSpace: CGSize) {
        self.direction = direction
        self.justifyContent = justifyContent
        self.alignItems = alignItems
        self.availableSpace = availableSpace
    }
    
    func addItem(_ item: FlexItem) {
        items.append(item)
    }
    
    func layout(context: WebCore.LayoutContext) async throws {
        // Simplified flex layout implementation
        let isRow = direction == .row || direction == .rowReverse
        let mainAxisSize = isRow ? availableSpace.width : availableSpace.height
        
        // Calculate item sizes
        var totalMainSize: CGFloat = 0
        var maxCrossSize: CGFloat = 0
        
        for item in items {
            let itemMainSize = isRow ? (item.style.width.resolveLength(relativeTo: mainAxisSize, fontSize: item.style.resolvedFontSize()) ?? 100) : (item.style.height.resolveLength(relativeTo: mainAxisSize, fontSize: item.style.resolvedFontSize()) ?? 50)
            let itemCrossSize = isRow ? (item.style.height.resolveLength(relativeTo: availableSpace.height, fontSize: item.style.resolvedFontSize()) ?? 50) : (item.style.width.resolveLength(relativeTo: availableSpace.width, fontSize: item.style.resolvedFontSize()) ?? 100)
            
            item.mainSize = itemMainSize
            item.crossSize = itemCrossSize
            
            totalMainSize += itemMainSize
            maxCrossSize = max(maxCrossSize, itemCrossSize)
        }
        
        crossSize = maxCrossSize
        
        // Position items
        var currentMainPosition: CGFloat = 0
        
        // Handle justify-content
        let spacing: CGFloat
        switch justifyContent {
        case .center:
            currentMainPosition = (mainAxisSize - totalMainSize) / 2
            spacing = 0
        case .flexEnd:
            currentMainPosition = mainAxisSize - totalMainSize
            spacing = 0
        case .spaceBetween:
            spacing = items.count > 1 ? (mainAxisSize - totalMainSize) / CGFloat(items.count - 1) : 0
        case .spaceAround:
            spacing = items.count > 0 ? (mainAxisSize - totalMainSize) / CGFloat(items.count) : 0
            currentMainPosition = spacing / 2
        case .spaceEvenly:
            spacing = items.count > 0 ? (mainAxisSize - totalMainSize) / CGFloat(items.count + 1) : 0
            currentMainPosition = spacing
        default: // flex-start
            spacing = 0
        }
        
        for item in items {
            let crossPosition: CGFloat
            switch alignItems {
            case .center:
                crossPosition = (maxCrossSize - item.crossSize) / 2
            case .flexEnd:
                crossPosition = maxCrossSize - item.crossSize
            default: // stretch, flex-start, baseline
                crossPosition = 0
            }
            
            if isRow {
                item.renderObject.frame = CGRect(
                    x: currentMainPosition,
                    y: crossPosition,
                    width: item.mainSize,
                    height: item.crossSize
                )
            } else {
                item.renderObject.frame = CGRect(
                    x: crossPosition,
                    y: currentMainPosition,
                    width: item.crossSize,
                    height: item.mainSize
                )
            }
            
            currentMainPosition += item.mainSize + spacing
        }
    }
}

class FlexItem {
    let renderObject: RenderObject
    let style: ComputedStyle
    var mainSize: CGFloat = 0
    var crossSize: CGFloat = 0
    
    init(renderObject: RenderObject, style: ComputedStyle) {
        self.renderObject = renderObject
        self.style = style
    }
}

// MARK: - Layout Errors

enum LayoutError: Error {
    case missingComputedStyle
    case invalidContainingBlock
    case cyclicDependency
    case unsupportedLayoutMode
}
