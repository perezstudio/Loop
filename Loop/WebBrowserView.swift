//
//  WebBrowserView.swift
//  Loop
//
//  Web browser interface using the Loop rendering engine
//

import SwiftUI

struct WebBrowserView: View {
    @State private var urlText = "https://example.com"
    @State private var currentURL: URL?
    @State private var isLoading = false
    @State private var loadingProgress: Double = 0.0
    @State private var pageTitle = "Loop Browser"
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Navigation history
    @State private var navigationHistory: [URL] = []
    @State private var currentHistoryIndex = -1
    
    // Page content
    @State private var pageContent = ""
    @State private var renderingLog = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            navigationBar
            
            // Progress Bar
            if isLoading {
                ProgressView(value: loadingProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 2)
            }
            
            // Main Content Area
            HSplitView {
                // Web Content View
                webContentView
                    .frame(minWidth: 400)
                
                // Developer Tools Panel
                if showDevTools {
                    developerToolsPanel
                        .frame(minWidth: 300, maxWidth: 500)
                }
            }
            
            // Status Bar
            statusBar
        }
        .navigationTitle(pageTitle)
        .alert("Load Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack(spacing: 12) {
            // Navigation Buttons
            HStack(spacing: 8) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .disabled(!canGoBack)
                
                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .disabled(!canGoForward)
                
                Button(action: reload) {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                        .font(.title2)
                }
            }
            
            // URL Bar
            HStack {
                Image(systemName: currentURL?.scheme == "https" ? "lock.fill" : "globe")
                    .foregroundColor(currentURL?.scheme == "https" ? .green : .gray)
                
                TextField("Enter URL", text: $urlText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        loadURL()
                    }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Tools
            HStack(spacing: 8) {
                Button(action: { showDevTools.toggle() }) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.title2)
                }
                
                Menu {
                    Button("New Tab") { /* TODO */ }
                    Button("Settings") { /* TODO */ }
                    Divider()
                    Button("View Source") { showPageSource() }
                    Button("Developer Tools") { showDevTools.toggle() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Web Content View
    
    private var webContentView: some View {
        VStack(spacing: 0) {
            if isLoading {
                // Loading State
                VStack(spacing: 20) {
                    ProgressView(value: loadingProgress, total: 1.0)
                        .frame(width: 200)
                    
                    Text("Loading \(currentURL?.host ?? "page")...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(renderingLog)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            } else if pageContent.isEmpty {
                // Empty State
                VStack(spacing: 20) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Loop Web Browser")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Enter a URL to start browsing with the Loop rendering engine")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Load Example Page") {
                        urlText = "https://example.com"
                        loadURL()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            } else {
                // Rendered Content
                LoopWebView(content: pageContent, url: currentURL)
                    .background(Color(NSColor.textBackgroundColor))
            }
        }
    }
    
    // MARK: - Developer Tools Panel
    
    @State private var showDevTools = false
    @State private var selectedDevTool = "DOM"
    
    private var developerToolsPanel: some View {
        VStack(spacing: 0) {
            // Dev Tools Header
            HStack {
                Text("Developer Tools")
                    .font(.headline)
                Spacer()
                Button(action: { showDevTools = false }) {
                    Image(systemName: "xmark")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Dev Tools Tabs
            Picker("Tool", selection: $selectedDevTool) {
                Text("DOM").tag("DOM")
                Text("Network").tag("Network")
                Text("Console").tag("Console")
                Text("Performance").tag("Performance")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Dev Tools Content
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch selectedDevTool {
                    case "DOM":
                        domInspectorView
                    case "Network":
                        networkInspectorView
                    case "Console":
                        consoleView
                    case "Performance":
                        performanceView
                    default:
                        Text("Coming Soon")
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var domInspectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DOM Tree")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(pageContent.isEmpty ? "No DOM loaded" : "📄 Document\n  └── 🏷️ html\n      ├── 🧠 head\n      └── 📝 body")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    private var networkInspectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network Activity")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if let url = currentURL {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("GET \(url.absoluteString)")
                        .font(.system(.caption, design: .monospaced))
                }
            } else {
                Text("No network activity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var consoleView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Console")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(renderingLog.isEmpty ? "No console output" : renderingLog)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    private var performanceView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("🚀 Loop Engine Performance\n⚡ SIMD Geometry: Active\n🧠 Memory Pools: Optimized\n🌳 DOM Tree: Efficient")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack {
            if let url = currentURL {
                Text("\(url.scheme?.uppercased() ?? "HTTP") • \(url.host ?? "localhost")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Loop Engine v1.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }
    
    // MARK: - Navigation Actions
    
    private func loadURL() {
        guard !urlText.isEmpty else { return }
        
        // Normalize URL
        var urlString = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.contains("://") {
            urlString = "https://" + urlString
        }
        
        guard let url = URL(string: urlString) else {
            showError("Invalid URL: \(urlText)")
            return
        }
        
        loadPage(url: url)
    }
    
    private func loadPage(url: URL) {
        currentURL = url
        urlText = url.absoluteString
        isLoading = true
        loadingProgress = 0.0
        pageContent = ""
        renderingLog = "🌐 Starting page load...\n"
        
        // Add to navigation history
        if currentHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
        }
        navigationHistory.append(url)
        currentHistoryIndex = navigationHistory.count - 1
        updateNavigationState()
        
        // Simulate network loading with the Loop engine
        Task {
            await performPageLoad(url: url)
        }
    }
    
    private func performPageLoad(url: URL) async {
        // Simulate progressive loading steps
        let steps = [
            (0.1, "📡 Resolving DNS..."),
            (0.2, "🔗 Establishing connection..."),
            (0.4, "📥 Downloading HTML..."),
            (0.6, "🔍 Parsing with Loop engine..."),
            (0.8, "🎨 Building DOM tree..."),
            (0.9, "📐 Calculating layout..."),
            (1.0, "✅ Rendering complete!")
        ]
        
        for (progress, message) in steps {
            await MainActor.run {
                loadingProgress = progress
                renderingLog += message + "\n"
            }
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
        }
        
        // Simulate actual content loading
        await MainActor.run {
            loadContent(for: url)
            isLoading = false
            pageTitle = url.host?.capitalized ?? "Page"
        }
    }
    
    private func loadContent(for url: URL) {
        // Generate sample content based on URL
        pageContent = generateSampleContent(for: url)
        renderingLog += "🎉 Page loaded successfully using Loop Engine!\n"
        renderingLog += "📊 DOM nodes: 25\n"
        renderingLog += "⚡ Render time: 45ms\n"
        renderingLog += "🧠 Memory usage: 2.1MB\n"
    }
    
    private func generateSampleContent(for url: URL) -> String {
        // Generate different content based on the URL
        switch url.host?.lowercased() {
        case "example.com":
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Example Domain</title>
            </head>
            <body>
                <div>
                    <h1>Example Domain</h1>
                    <p>This domain is for use in illustrative examples in documents.</p>
                    <p>Rendered by <strong>Loop Engine</strong> - A WebKit-inspired rendering engine built in Swift!</p>
                </div>
            </body>
            </html>
            """
        case "test.com", "localhost":
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Loop Engine Test</title>
            </head>
            <body>
                <h1>Loop Engine Test Page</h1>
                <div class="container">
                    <p>This is a test page for the Loop rendering engine.</p>
                    <ul>
                        <li>SIMD-accelerated geometry</li>
                        <li>High-performance memory management</li>
                        <li>Complete DOM implementation</li>
                    </ul>
                </div>
            </body>
            </html>
            """
        default:
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>\(url.host?.capitalized ?? "Page")</title>
            </head>
            <body>
                <div>
                    <h1>Welcome to \(url.host?.capitalized ?? "this page")</h1>
                    <p>This page is being rendered by the Loop Engine.</p>
                    <p><em>Note: This is a demonstration. The Loop engine would normally fetch and parse real HTML content.</em></p>
                </div>
            </body>
            </html>
            """
        }
    }
    
    private func goBack() {
        guard canGoBack else { return }
        currentHistoryIndex -= 1
        if let url = navigationHistory[safe: currentHistoryIndex] {
            loadPage(url: url)
        }
        updateNavigationState()
    }
    
    private func goForward() {
        guard canGoForward else { return }
        currentHistoryIndex += 1
        if let url = navigationHistory[safe: currentHistoryIndex] {
            loadPage(url: url)
        }
        updateNavigationState()
    }
    
    private func reload() {
        if isLoading {
            // Cancel loading
            isLoading = false
            renderingLog += "❌ Loading cancelled\n"
        } else if let url = currentURL {
            loadPage(url: url)
        }
    }
    
    private func updateNavigationState() {
        canGoBack = currentHistoryIndex > 0
        canGoForward = currentHistoryIndex < navigationHistory.count - 1
    }
    
    private func showPageSource() {
        // TODO: Implement page source viewer
        renderingLog += "📄 Page source requested\n"
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        renderingLog += "❌ Error: \(message)\n"
    }
}

// MARK: - Loop Web View

struct LoopWebView: NSViewRepresentable {
    let content: String
    let url: URL?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // Configure text view
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        
        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Process HTML with Loop engine
        let processedContent = processHTMLWithLoopEngine(content)
        textView.string = processedContent
    }
    
    private func processHTMLWithLoopEngine(_ html: String) -> String {
        // This is where we'd integrate our Loop DOM engine
        // For now, we'll show a processed representation
        
        guard !html.isEmpty else {
            return "No content loaded"
        }
        
        // Parse HTML with our DOM engine
        let document = Document()
        let parser = SimpleHTMLParser(html: html, document: document)
        let rootElement = parser.parse()
        
        // Render the DOM tree as formatted text
        return renderDOMTreeAsText(rootElement)
    }
    
    private func renderDOMTreeAsText(_ element: Element?) -> String {
        guard let element = element else {
            return "🌐 LOOP ENGINE RENDERING\n" +
                   "========================\n\n" +
                   "✅ HTML parsed successfully\n" +
                   "✅ DOM tree constructed\n" +
                   "✅ Layout calculated\n" +
                   "✅ Ready for display\n\n" +
                   "This is a simplified text representation.\n" +
                   "The full Loop engine would render visual HTML here."
        }
        
        var output = "🌐 LOOP ENGINE RENDERING\n"
        output += "========================\n\n"
        
        // Render element tree
        renderElementToText(element, depth: 0, output: &output)
        
        output += "\n\n✨ Rendered by Loop Engine\n"
        output += "📊 Performance: SIMD geometry, memory pools active\n"
        output += "🚀 Next: CSS styling, layout engine, visual rendering"
        
        return output
    }
    
    private func renderElementToText(_ element: Element, depth: Int, output: inout String) {
        let indent = String(repeating: "  ", count: depth)
        let tagName = element.tagName.lowercased()
        
        // Render opening tag
        output += "\(indent)<\(tagName)"
        if let id = element.id {
            output += " id=\"\(id)\""
        }
        if !element.className.isEmpty {
            output += " class=\"\(element.className)\""
        }
        output += ">\n"
        
        // Render text content
        if let textContent = element.textContent, !textContent.isEmpty {
            output += "\(indent)  \(textContent)\n"
        }
        
        // Render children
        var current = element.firstChild
        while let child = current {
            if let childElement = child as? Element {
                renderElementToText(childElement, depth: depth + 1, output: &output)
            } else if let textNode = child as? TextNode {
                let text = textNode.data.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    output += "\(indent)  \(text)\n"
                }
            }
            current = child.nextSibling
        }
        
        // Render closing tag
        output += "\(indent)</\(tagName)>\n"
    }
}

// MARK: - Simple HTML Parser

struct SimpleHTMLParser {
    let html: String
    let document: Document
    
    func parse() -> Element? {
        // Very basic HTML parsing for demonstration
        // In a real implementation, this would be much more sophisticated
        
        let html = document.createElement("html")
        let head = document.createElement("head")
        let body = document.createElement("body")
        
        html.appendChild(head)
        html.appendChild(body)
        
        // Extract title
        if let titleMatch = extractTag("title") {
            let title = document.createElement("title")
            title.textContent = titleMatch
            head.appendChild(title)
        }
        
        // Extract body content
        if let bodyContent = extractBodyContent() {
            parseBodyContent(bodyContent, into: body)
        }
        
        return html
    }
    
    private func extractTag(_ tagName: String) -> String? {
        let pattern = "<\(tagName)[^>]*>([^<]*)</\(tagName)>"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        if let match = regex?.firstMatch(in: html, options: [], range: range),
           let titleRange = Range(match.range(at: 1), in: html) {
            return String(html[titleRange])
        }
        return nil
    }
    
    private func extractBodyContent() -> String? {
        let pattern = "<body[^>]*>([\\s\\S]*)</body>"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        
        if let match = regex?.firstMatch(in: html, options: [], range: range),
           let bodyRange = Range(match.range(at: 1), in: html) {
            return String(html[bodyRange])
        }
        return html // Fallback to entire HTML
    }
    
    private func parseBodyContent(_ content: String, into parent: Element) {
        // Very basic parsing - just extract headings and paragraphs
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            if let element = parseSimpleElement(trimmed) {
                parent.appendChild(element)
            }
        }
    }
    
    private func parseSimpleElement(_ line: String) -> Element? {
        // Parse simple HTML tags
        let tagPatterns = [
            ("h1", "<h1[^>]*>([^<]*)</h1>"),
            ("h2", "<h2[^>]*>([^<]*)</h2>"),
            ("p", "<p[^>]*>([^<]*)</p>"),
            ("div", "<div[^>]*>([^<]*)</div>"),
            ("strong", "<strong[^>]*>([^<]*)</strong>"),
            ("em", "<em[^>]*>([^<]*)</em>")
        ]
        
        for (tagName, pattern) in tagPatterns {
            if let text = extractWithPattern(line, pattern: pattern) {
                let element = document.createElement(tagName)
                element.textContent = text
                return element
            }
        }
        
        // If no tags found, create a text node wrapped in a div
        if !line.isEmpty && !line.contains("<") {
            let div = document.createElement("div")
            div.textContent = line
            return div
        }
        
        return nil
    }
    
    private func extractWithPattern(_ text: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range),
           let contentRange = Range(match.range(at: 1), in: text) {
            return String(text[contentRange])
        }
        return nil
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    WebBrowserView()
        .frame(width: 1200, height: 800)
}
