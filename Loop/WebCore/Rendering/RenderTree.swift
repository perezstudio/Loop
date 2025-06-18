//
//  RenderTree.swift
//  Loop - WebKit-Inspired Render Tree
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics

// MARK: - Render Tree Delegate

protocol RenderTreeDelegate: AnyObject {
    func renderTreeDidChange(_ tree: RenderTree)
}

// MARK: - Render Tree

class RenderTree {
    
    // MARK: - Properties
    
    private(set) var rootObject: RenderObject?
    private var renderObjectMap: [NodeID: RenderObject] = [:]
    private var dirtyObjects: Set<RenderObject> = []
    
    weak var delegate: RenderTreeDelegate?
    
    // MARK: - Tree Building
    
    func build(from document: WebCoreDocument, styleEngine: StyleEngine) async {
        print("🌳 Building render tree from document...")
        
        // Clear existing tree
        clear()
        
        // Build from document root
        if let documentElement = document.documentElement {
            print("🌳 Document element found: \(documentElement.tagName)")
            rootObject = await buildRenderObject(from: documentElement, styleEngine: styleEngine)
            print("🌳 Root object created: \(rootObject != nil)")
        } else {
            print("⚠️ No document element found")
        }
        
        delegate?.renderTreeDidChange(self)
        print("✅ Render tree built with \(getObjectCount()) objects")
        
        // Debug: print the tree structure
        if let root = rootObject {
            print("🌳 Root object details: \(root.debugDescription)")
        }
    }
    
    private func buildRenderObject(from element: WebCoreElement, styleEngine: StyleEngine) async -> RenderObject? {
        // Get computed style for this element
        guard let computedStyle = styleEngine.getComputedStyle(for: element) else {
            print("⚠️ No computed style for element: \(element.tagName)")
            return nil
        }
        
        // Skip elements with display: none
        if computedStyle.display == .none {
            return nil
        }
        
        // Create render object
        let renderObject = RenderObject(element: element, computedStyle: computedStyle)
        registerRenderObject(renderObject)
        
        // Build children
        for child in element.children {
            if let childRenderObject = await buildRenderObject(from: child, styleEngine: styleEngine) {
                renderObject.appendChild(childRenderObject)
            }
        }
        
        // Handle text content
        if !element.textContent.isEmpty {
            let textRenderObject = RenderObject(textContent: element.textContent, computedStyle: computedStyle)
            registerRenderObject(textRenderObject)
            renderObject.appendChild(textRenderObject)
        }
        
        return renderObject
    }
    
    private func registerRenderObject(_ renderObject: RenderObject) {
        if let element = renderObject.element {
            renderObjectMap[element.id] = renderObject
        }
    }
    
    // MARK: - Tree Management
    
    func clear() {
        print("🌳 Clearing render tree (had \(getObjectCount()) objects)")
        rootObject = nil
        renderObjectMap.removeAll()
        dirtyObjects.removeAll()
    }
    
    func invalidate(_ renderObject: RenderObject) {
        renderObject.needsLayout = true
        renderObject.needsRepaint = true
        dirtyObjects.insert(renderObject)
        
        // Invalidate ancestors
        var current = renderObject.parent
        while let parent = current {
            parent.needsLayout = true
            parent.needsRepaint = true
            dirtyObjects.insert(parent)
            current = parent.parent
        }
        
        delegate?.renderTreeDidChange(self)
    }
    
    func markClean(_ renderObject: RenderObject) {
        renderObject.needsLayout = false
        renderObject.needsRepaint = false
        dirtyObjects.remove(renderObject)
    }
    
    // MARK: - Queries
    
    func getRenderObject(for element: WebCoreElement) -> RenderObject? {
        return renderObjectMap[element.id]
    }
    
    func getObjectCount() -> Int {
        return renderObjectMap.count
    }
    
    func getDirtyObjects() -> Set<RenderObject> {
        return dirtyObjects
    }
    
    // MARK: - Hit Testing
    
    func hitTest(_ rootObject: RenderObject, at point: CGPoint) -> RenderObject? {
        return hitTestRecursive(rootObject, point: point)
    }
    
    private func hitTestRecursive(_ renderObject: RenderObject, point: CGPoint) -> RenderObject? {
        // Check if point is within this object's frame
        guard renderObject.frame.contains(point) else {
            return nil
        }
        
        // Check children first (front to back)
        for child in renderObject.children.reversed() {
            if let hit = hitTestRecursive(child, point: point) {
                return hit
            }
        }
        
        // Return this object if no children were hit
        return renderObject
    }
    
    // MARK: - Tree Traversal
    
    func traverse(_ visitor: (RenderObject) -> Void) {
        guard let root = rootObject else { return }
        traverseRecursive(root, visitor: visitor)
    }
    
    private func traverseRecursive(_ renderObject: RenderObject, visitor: (RenderObject) -> Void) {
        visitor(renderObject)
        
        for child in renderObject.children {
            traverseRecursive(child, visitor: visitor)
        }
    }
    
    // MARK: - Debug Support
    
    func printTree() {
        print("🌳 Render Tree Structure:")
        guard let root = rootObject else {
            print("  (empty)")
            return
        }
        printRenderObject(root, indent: 0)
    }
    
    private func printRenderObject(_ renderObject: RenderObject, indent: Int) {
        let indentation = String(repeating: "  ", count: indent)
        print("\(indentation)\(renderObject.debugDescription)")
        
        for child in renderObject.children {
            printRenderObject(child, indent: indent + 1)
        }
    }
}

// MARK: - Render Object

class RenderObject: Identifiable, Hashable {
    
    // MARK: - Properties
    
    let id = UUID()
    
    // DOM relationship
    let element: WebCoreElement?
    let textContent: String?
    let computedStyle: ComputedStyle?
    
    // Tree structure
    private(set) weak var parent: RenderObject?
    private(set) var children: [RenderObject] = []
    
    // Layout properties
    var frame: CGRect = .zero
    var contentRect: CGRect = .zero
    var needsLayout: Bool = true
    var needsRepaint: Bool = true
    
    // Rendering properties
    var layer: RenderLayer?
    var opacity: CGFloat = 1.0
    var transform: CGAffineTransform = .identity
    
    // MARK: - Initialization
    
    init(element: WebCoreElement, computedStyle: ComputedStyle) {
        self.element = element
        self.textContent = nil
        self.computedStyle = computedStyle
    }
    
    init(textContent: String, computedStyle: ComputedStyle) {
        self.element = nil
        self.textContent = textContent
        self.computedStyle = computedStyle
    }
    
    // MARK: - Tree Manipulation
    
    func appendChild(_ child: RenderObject) {
        guard child.parent !== self else { return }
        
        child.removeFromParent()
        child.parent = self
        children.append(child)
        
        invalidateLayout()
    }
    
    func insertChild(_ child: RenderObject, at index: Int) {
        guard child.parent !== self else { return }
        
        child.removeFromParent()
        child.parent = self
        children.insert(child, at: min(index, children.count))
        
        invalidateLayout()
    }
    
    func removeChild(_ child: RenderObject) {
        guard let index = children.firstIndex(of: child) else { return }
        
        child.parent = nil
        children.remove(at: index)
        
        invalidateLayout()
    }
    
    func removeFromParent() {
        parent?.removeChild(self)
    }
    
    // MARK: - Layout Invalidation
    
    func invalidateLayout() {
        needsLayout = true
        needsRepaint = true
        
        // Invalidate children
        for child in children {
            child.invalidateLayout()
        }
    }
    
    func invalidateRepaint() {
        needsRepaint = true
        
        // Invalidate ancestors up to a layer boundary
        var current = parent
        while let renderObject = current {
            renderObject.needsRepaint = true
            
            if renderObject.layer != nil {
                break // Stop at layer boundary
            }
            
            current = renderObject.parent
        }
    }
    
    // MARK: - Layer Management
    
    func shouldCreateLayer() -> Bool {
        guard let style = computedStyle else { return false }
        
        // Create layer for positioned elements
        if style.position == .absolute || style.position == .fixed {
            return true
        }
        
        // Create layer for elements with opacity
        if opacity < 1.0 {
            return true
        }
        
        // Create layer for elements with transforms
        if transform != .identity {
            return true
        }
        
        // Create layer for flex containers (for GPU acceleration)
        if style.display == .flex {
            return true
        }
        
        return false
    }
    
    func createLayerIfNeeded() {
        if shouldCreateLayer() && layer == nil {
            layer = RenderLayer(renderObject: self)
        } else if !shouldCreateLayer() && layer != nil {
            layer = nil
        }
    }
    
    // MARK: - Computed Properties
    
    var isTextNode: Bool {
        return textContent != nil
    }
    
    var isElement: Bool {
        return element != nil
    }
    
    var tagName: String {
        return element?.tagName ?? "#text"
    }
    
    var effectiveOpacity: CGFloat {
        let parentOpacity = parent?.effectiveOpacity ?? 1.0
        return opacity * parentOpacity
    }
    
    var worldTransform: CGAffineTransform {
        let parentTransform = parent?.worldTransform ?? .identity
        return parentTransform.concatenating(transform)
    }
    
    // MARK: - Bounds Calculation
    
    func boundsInAncestor(_ ancestor: RenderObject?) -> CGRect {
        var bounds = frame
        var current = parent
        
        while let renderObject = current, renderObject !== ancestor {
            bounds = bounds.offsetBy(dx: renderObject.frame.minX, dy: renderObject.frame.minY)
            current = renderObject.parent
        }
        
        return bounds
    }
    
    var boundsInRoot: CGRect {
        return boundsInAncestor(nil)
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RenderObject, rhs: RenderObject) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Debug Description
    
    var debugDescription: String {
        var description = tagName
        
        if let element = element {
            if let id = element.getAttribute("id") {
                description += "#\(id)"
            }
            if let className = element.getAttribute("class") {
                description += ".\(className.replacingOccurrences(of: " ", with: "."))"
            }
        }
        
        description += " [\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))]"
        
        if needsLayout { description += " [needs-layout]" }
        if needsRepaint { description += " [needs-repaint]" }
        if layer != nil { description += " [layered]" }
        
        return description
    }
}

// MARK: - Render Layer

class RenderLayer {
    
    let renderObject: RenderObject
    var children: [RenderLayer] = []
    weak var parent: RenderLayer?
    
    // Layer properties
    var bounds: CGRect = .zero
    var position: CGPoint = .zero
    var opacity: CGFloat = 1.0
    var transform: CGAffineTransform = .identity
    var masksToBounds: Bool = false
    
    // Backing store
    var backingStore: CGContext?
    var needsDisplay: Bool = true
    
    init(renderObject: RenderObject) {
        self.renderObject = renderObject
        self.bounds = renderObject.frame
        self.opacity = renderObject.opacity
        self.transform = renderObject.transform
    }
    
    func appendChild(_ child: RenderLayer) {
        child.removeFromParent()
        child.parent = self
        children.append(child)
    }
    
    func removeFromParent() {
        parent?.children.removeAll { $0 === self }
        parent = nil
    }
    
    func invalidateDisplay() {
        needsDisplay = true
        renderObject.needsRepaint = true
    }
}

// MARK: - Render Object Extensions

extension RenderObject {
    
    /// Find the first ancestor with a layer
    var layerAncestor: RenderObject? {
        var current = parent
        while let renderObject = current {
            if renderObject.layer != nil {
                return renderObject
            }
            current = renderObject.parent
        }
        return nil
    }
    
    /// Get all descendant render objects
    var descendants: [RenderObject] {
        var result: [RenderObject] = []
        
        func collectDescendants(_ renderObject: RenderObject) {
            for child in renderObject.children {
                result.append(child)
                collectDescendants(child)
            }
        }
        
        collectDescendants(self)
        return result
    }
    
    /// Check if this render object contains another
    func contains(_ other: RenderObject) -> Bool {
        var current: RenderObject? = other.parent
        while let renderObject = current {
            if renderObject === self {
                return true
            }
            current = renderObject.parent
        }
        return false
    }
}
