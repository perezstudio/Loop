//
//  NativeWebView.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI
import AppKit

// MARK: - Native Web View (SwiftUI Wrapper)

struct NativeWebView: NSViewRepresentable {
    let urlString: String
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    func makeNSView(context: Context) -> NativeCanvasView {
        let canvasView = NativeCanvasView()
        canvasView.delegate = context.coordinator
        return canvasView
    }
    
    func updateNSView(_ nsView: NativeCanvasView, context: Context) {
        if nsView.currentURL != urlString {
            nsView.loadURL(urlString)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NativeCanvasViewDelegate {
        let parent: NativeWebView
        
        init(_ parent: NativeWebView) {
            self.parent = parent
        }
        
        func canvasViewDidStartLoading(_ canvasView: NativeCanvasView) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.errorMessage = nil
            }
        }
        
        func canvasViewDidFinishLoading(_ canvasView: NativeCanvasView) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func canvasView(_ canvasView: NativeCanvasView, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.errorMessage = error.localizedDescription
            }
        }
        
        func canvasView(_ canvasView: NativeCanvasView, didClickLink url: String) {
            print("Link clicked: \(url)")
            // TODO: Handle navigation
        }
    }
}

// MARK: - Native Canvas View Delegate

protocol NativeCanvasViewDelegate: AnyObject {
    func canvasViewDidStartLoading(_ canvasView: NativeCanvasView)
    func canvasViewDidFinishLoading(_ canvasView: NativeCanvasView)
    func canvasView(_ canvasView: NativeCanvasView, didFailWithError error: Error)
    func canvasView(_ canvasView: NativeCanvasView, didClickLink url: String)
}

// MARK: - Native Canvas View (NSView)

class NativeCanvasView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: NativeCanvasViewDelegate?
    
    private let renderingEngine = NativeRenderingEngine()
    private var scrollView: NSScrollView?
    private var documentView: DocumentView?
    
    var currentURL: String = ""
    private var isLoading = false
    
    // Mouse tracking
    private var trackingArea: NSTrackingArea?
    private var hoveredNode: RenderNode?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupScrollView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScrollView()
    }
    
    // MARK: - Setup
    
    private func setupScrollView() {
        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor.white
        
        // Create document view
        let documentView = DocumentView()
        documentView.canvasView = self
        scrollView.documentView = documentView
        
        // Add to view hierarchy
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        self.scrollView = scrollView
        self.documentView = documentView
    }
    
    // MARK: - Loading
    
    func loadURL(_ urlString: String) {
        guard !isLoading, urlString != currentURL else { 
            print("⚠️ Skipping load - already loading or same URL")
            return 
        }
        
        print("🚀 Starting to load URL: \(urlString)")
        currentURL = urlString
        isLoading = true
        
        delegate?.canvasViewDidStartLoading(self)
        
        Task {
            do {
                print("🌍 Fetching HTML from network...")
                let html = try await fetchHTML(from: urlString)
                print("✅ HTML fetch successful")
                
                await MainActor.run {
                    self.loadHTML(html)
                }
            } catch {
                print("❌ HTML fetch failed: \(error)")
                await MainActor.run {
                    self.delegate?.canvasView(self, didFailWithError: error)
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadHTML(_ html: String) {
        print("📝 Loading HTML into rendering engine...")
        print("📊 HTML length: \(html.count) characters")
        print("🔍 HTML preview: \(String(html.prefix(200)))...")
        
        let viewport = CGRect(origin: .zero, size: bounds.size)
        print("📱 Viewport: \(viewport)")
        
        renderingEngine.loadHTML(html, viewport: viewport)
        print("⚙️ HTML loaded into rendering engine")
        
        // Update document view size based on content
        if let contentSize = getContentSize() {
            documentView?.setFrameSize(contentSize)
            print("📌 Document view size set to: \(contentSize)")
        }
        
        // Force immediate redraw
        print("🔄 Forcing document view redraw...")
        documentView?.needsDisplay = true
        documentView?.display()  // Force immediate redraw
        print("🔄 Document view redraw completed")
        
        isLoading = false
        delegate?.canvasViewDidFinishLoading(self)
        print("✅ HTML loading complete")
    }
    
    private func fetchHTML(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw WebViewError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    throw WebViewError.httpError(httpResponse.statusCode)
                }
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                throw WebViewError.encodingError
            }
            
            return html
        } catch {
            throw WebViewError.networkError(error)
        }
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    // MARK: - Mouse Events
    
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let adjustedPoint = documentView?.convert(point, from: self) ?? point
        
        let hitNode = renderingEngine.hitTest(adjustedPoint)
        
        if hitNode !== hoveredNode {
            hoveredNode = hitNode
            updateCursor(for: hitNode)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let adjustedPoint = documentView?.convert(point, from: self) ?? point
        
        if let hitNode = renderingEngine.hitTest(adjustedPoint) {
            handleClick(on: hitNode)
        }
    }
    
    private func updateCursor(for node: RenderNode?) {
        if let node = node, node.domNode.tagName?.lowercased() == "a" {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
    
    private func handleClick(on node: RenderNode) {
        if node.domNode.tagName?.lowercased() == "a",
           let href = node.domNode.getAttribute("href") {
            delegate?.canvasView(self, didClickLink: href)
        }
    }
    
    // MARK: - Content Size
    
    private func getContentSize() -> CGSize? {
        // This would need to be implemented to get the actual content size
        // from the rendering engine
        return CGSize(width: bounds.width, height: max(bounds.height, 1000))
    }
    
    // MARK: - Rendering Access
    
    func getRenderingEngine() -> NativeRenderingEngine {
        return renderingEngine
    }
}

// MARK: - Document View

class DocumentView: NSView {
    weak var canvasView: NativeCanvasView?
    private var isDrawing = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        print("📝 DocumentView initialized with frame: \(frameRect)")
        self.wantsLayer = false  // Ensure we use draw(_:) not updateLayer
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("📝 DocumentView initialized from coder")
        self.wantsLayer = false
    }
    
    override var isFlipped: Bool {
        return true // Use top-left origin like web content
    }
    
    override var wantsUpdateLayer: Bool {
        return false  // Change to false to use draw(_:) method
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Prevent excessive redraws during the same drawing cycle
        guard !isDrawing else { 
            print("⚠️ Skipping draw - already drawing")
            return 
        }
        isDrawing = true
        defer { isDrawing = false }
        
        guard let context = NSGraphicsContext.current?.cgContext,
              let canvasView = canvasView else { 
            print("❌ No context or canvas view in DocumentView.draw")
            return 
        }
        
        // Always log draws for debugging the white page issue
        print("🖼️ DocumentView drawing - dirtyRect: \(dirtyRect), bounds: \(bounds)")
        
        // Clear background with white
        context.setFillColor(CGColor.white)
        context.fill(bounds)
        print("⬜ Background cleared with white")
        
        // Render web content
        let renderResult = canvasView.getRenderingEngine().render(to: context)
        print("🎨 Render result: \(renderResult)")
        
        if renderResult {
            print("✅ Web content rendered successfully")
        } else {
            print("⚠️ No web content to render - showing loading message")
            
            // Show loading message when no content
            context.setFillColor(CGColor.black)
            let loadingText = "Loading web content..."
            let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: CGColor.black
            ]
            let attributedString = CFAttributedStringCreate(nil, loadingText as CFString, attributes as CFDictionary)!
            let line = CTLineCreateWithAttributedString(attributedString)
            
            context.textPosition = CGPoint(x: 50, y: bounds.height - 100)
            CTLineDraw(line, context)
            print("📝 Loading message drawn")
        }
        
        // Add a small debug indicator to confirm drawing is working
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        context.fill(CGRect(x: 10, y: 10, width: 50, height: 20))
        print("🔴 Debug indicator drawn")
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle keyboard events for web content
        super.keyDown(with: event)
    }
}

// MARK: - Error Types

enum WebViewError: Error {
    case invalidURL
    case networkError(Error)
    case httpError(Int)
    case encodingError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .encodingError:
            return "Text encoding error"
        }
    }
}
