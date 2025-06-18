//
//  WebCoreEngine.swift
//  Loop - WebKit-Inspired Rendering Engine
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import CoreText
import AppKit
import SwiftUI
import Combine

// MARK: - WebCore Engine Events

protocol WebCoreEngineDelegate: AnyObject {
    func webCoreDidStartLoading(_ engine: WebCoreEngine)
    func webCoreDidFinishLoading(_ engine: WebCoreEngine)
    func webCoreDidFailLoading(_ engine: WebCoreEngine, error: Error)
    func webCoreDidUpdateLayout(_ engine: WebCoreEngine)
    func webCoreDidRepaint(_ engine: WebCoreEngine, dirtyRect: CGRect)
}

// MARK: - Main WebCore Engine

class WebCoreEngine: ObservableObject {
    
    // MARK: - Core Components
    
    let configuration: WebCore.Configuration
    private let document: WebCoreDocument
    private let styleEngine: StyleEngine
    private let layoutEngine: WebCoreLayoutEngine
    private let renderTree: RenderTree
    private let paintEngine: WebCorePaintEngine
    
    // MARK: - State Management
    
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadProgress: Double = 0.0
    @Published private(set) var currentURL: URL?
    
    private var viewport: CGRect
    private var needsLayout: Bool = false
    private var needsRepaint: Bool = false
    private var lastLayoutTime: CFTimeInterval = 0
    private var lastPaintTime: CFTimeInterval = 0
    
    weak var delegate: WebCoreEngineDelegate?
    
    // MARK: - Initialization
    
    init(configuration: WebCore.Configuration = WebCore.Configuration()) {
        self.configuration = configuration
        self.viewport = CGRect(origin: .zero, size: configuration.viewport)
        
        // Initialize core components
        self.document = WebCoreDocument()
        self.styleEngine = StyleEngine(configuration: configuration)
        self.layoutEngine = WebCoreLayoutEngine(configuration: configuration)
        self.renderTree = RenderTree()
        self.paintEngine = WebCorePaintEngine(configuration: configuration)
        
        setupEngineConnections()
        
        print("🚀 WebCore Engine initialized with viewport: \(viewport)")
    }
    
    private func setupEngineConnections() {
        // Set up communication between components
        document.delegate = self
        styleEngine.delegate = self
        layoutEngine.delegate = self
        renderTree.delegate = self
        paintEngine.delegate = self
    }
    
    // MARK: - Public API
    
    /// Load HTML content into the engine
    func loadHTML(_ html: String, baseURL: URL? = nil) {
        print("📄 Loading HTML content...")
        
        isLoading = true
        loadProgress = 0.0
        delegate?.webCoreDidStartLoading(self)
        
        Task { @MainActor in
            do {
                // Parse HTML and build DOM
                loadProgress = 0.2
                try await document.loadHTML(html, baseURL: baseURL)
                
                // Process styles
                loadProgress = 0.4
                try await styleEngine.processStyles(document: document)
                
                // Build render tree
                loadProgress = 0.6
                try await renderTree.build(from: document, styleEngine: styleEngine)
                
                // Perform layout
                loadProgress = 0.8
                try await performLayout()
                
                // Complete loading
                loadProgress = 1.0
                isLoading = false
                
                delegate?.webCoreDidFinishLoading(self)
                print("✅ HTML loading completed successfully")
                
            } catch {
                isLoading = false
                delegate?.webCoreDidFailLoading(self, error: error)
                print("❌ HTML loading failed: \(error)")
            }
        }
    }
    
    /// Set the viewport size
    func setViewport(_ size: CGSize) {
        let newViewport = CGRect(origin: .zero, size: size)
        guard newViewport != viewport else { return }
        
        print("📐 Updating viewport: \(size)")
        viewport = newViewport
        scheduleLayout()
    }
    
    /// Force a layout recalculation
    func scheduleLayout() {
        guard !needsLayout else { return }
        needsLayout = true
        
        DispatchQueue.main.async { [weak self] in
            self?.performLayoutIfNeeded()
        }
    }
    
    /// Force a repaint
    func scheduleRepaint(dirtyRect: CGRect? = nil) {
        guard !needsRepaint else { return }
        needsRepaint = true
        
        DispatchQueue.main.async { [weak self] in
            self?.performRepaintIfNeeded(dirtyRect: dirtyRect)
        }
    }
    
    /// Render the current page to a CGContext
    func render(to context: CGContext) -> Bool {
        guard let rootRenderObject = renderTree.rootObject else {
            print("⚠️ No render tree available for painting")
            return false
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create paint context
        let paintContext = PaintContext(
            cgContext: context,
            viewport: viewport,
            scaleFactor: 1.0,
            enableDebugOverlays: configuration.enablePaintDebugging
        )
        
        // Paint the render tree
        let success = paintEngine.paint(rootRenderObject, context: paintContext)
        
        let paintTime = CFAbsoluteTimeGetCurrent() - startTime
        lastPaintTime = paintTime
        
        if configuration.enablePaintDebugging {
            print("🎨 Paint completed in \(String(format: "%.2f", paintTime * 1000))ms")
        }
        
        return success
    }
    
    /// Create a rendered image of the current page
    func createImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(viewport.width),
            height: Int(viewport.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            print("❌ Failed to create image context")
            return nil
        }
        
        // Flip coordinate system for proper rendering
        context.translateBy(x: 0, y: viewport.height)
        context.scaleBy(x: 1, y: -1)
        
        guard render(to: context) else {
            print("❌ Failed to render to image context")
            return nil
        }
        
        return context.makeImage()
    }
    
    // MARK: - Hit Testing
    
    func hitTest(at point: CGPoint) -> RenderObject? {
        guard let rootRenderObject = renderTree.rootObject else { return nil }
        return renderTree.hitTest(rootRenderObject, at: point)
    }
    
    // MARK: - Internal Layout Management
    
    @MainActor
    private func performLayoutIfNeeded() {
        guard needsLayout else { return }
        
        Task {
            await performLayout()
        }
    }
    
    private func performLayout() async {
        guard let rootRenderObject = renderTree.rootObject else {
            print("⚠️ No render tree available for layout")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        needsLayout = false
        
        do {
            // Create layout context
            let layoutContext = WebCore.LayoutContext(
                viewport: viewport,
                enableIncrementalLayout: configuration.enableIncrementalLayout,
                enableDebugging: configuration.enableLayoutDebugging
            )
            
            // Perform layout
            try await layoutEngine.layout(rootRenderObject, context: layoutContext)
            
            let layoutTime = CFAbsoluteTimeGetCurrent() - startTime
            lastLayoutTime = layoutTime
            
            if configuration.enableLayoutDebugging {
                print("📐 Layout completed in \(String(format: "%.2f", layoutTime * 1000))ms")
            }
            
            // Schedule repaint
            await MainActor.run {
                scheduleRepaint()
                delegate?.webCoreDidUpdateLayout(self)
            }
            
        } catch {
            print("❌ Layout failed: \(error)")
        }
    }
    
    @MainActor
    private func performRepaintIfNeeded(dirtyRect: CGRect? = nil) {
        guard needsRepaint else { return }
        needsRepaint = false
        
        let repaintRect = dirtyRect ?? viewport
        delegate?.webCoreDidRepaint(self, dirtyRect: repaintRect)
    }
    
    // MARK: - Debug Information
    
    func getDebugInfo() -> [String: Any] {
        return [
            "viewport": viewport,
            "isLoading": isLoading,
            "loadProgress": loadProgress,
            "needsLayout": needsLayout,
            "needsRepaint": needsRepaint,
            "lastLayoutTime": lastLayoutTime,
            "lastPaintTime": lastPaintTime,
            "documentNodeCount": document.getNodeCount(),
            "renderObjectCount": renderTree.getObjectCount(),
            "configuration": [
                "enableJavaScript": configuration.enableJavaScript,
                "enableGPUAcceleration": configuration.enableGPUAcceleration,
                "enableIncrementalLayout": configuration.enableIncrementalLayout
            ]
        ]
    }
    
    func printDebugInfo() {
        let info = getDebugInfo()
        print("🔍 WebCore Engine Debug Info:")
        for (key, value) in info {
            print("  \(key): \(value)")
        }
    }
}

// MARK: - WebCore Engine Delegate Implementations

extension WebCoreEngine: WebCoreDocumentDelegate {
    func documentDidChange(_ document: WebCoreDocument) {
        print("📄 Document changed, scheduling style recalculation")
        Task {
            await styleEngine.processStyles(document: document)
            await renderTree.build(from: document, styleEngine: styleEngine)
            await MainActor.run { scheduleLayout() }
        }
    }
    
    func documentDidFinishLoading(_ document: WebCoreDocument) {
        print("📄 Document finished loading")
    }
}

extension WebCoreEngine: StyleEngineDelegate {
    func styleEngineDidUpdateStyles(_ engine: StyleEngine) {
        print("🎨 Styles updated, rebuilding render tree")
        Task {
            await renderTree.build(from: document, styleEngine: styleEngine)
            await MainActor.run { scheduleLayout() }
        }
    }
}

extension WebCoreEngine: WebCoreLayoutEngineDelegate {
    func layoutEngineDidCompleteLayout(_ engine: WebCoreLayoutEngine) {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleRepaint()
        }
    }
    
    func layoutEngineDidInvalidate(_ engine: WebCoreLayoutEngine, rect: CGRect) {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleRepaint(dirtyRect: rect)
        }
    }
}

extension WebCoreEngine: RenderTreeDelegate {
    func renderTreeDidChange(_ tree: RenderTree) {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleLayout()
        }
    }
}

extension WebCoreEngine: WebCorePaintEngineDelegate {
    func paintEngineDidInvalidate(_ engine: WebCorePaintEngine, rect: CGRect) {
        DispatchQueue.main.async { [weak self] in
            self?.scheduleRepaint(dirtyRect: rect)
        }
    }
}
