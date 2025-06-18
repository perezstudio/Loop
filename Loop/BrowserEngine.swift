//
//  BrowserEngine.swift
//  Loop - Browser Engine with URL Fetching and WebCore Integration
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import SwiftUI
import Combine
import Network

// MARK: - Browser Engine

@MainActor
class BrowserEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var loadProgress: Double? = nil
    @Published var currentURL: URL?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isSecure = false
    @Published var hasError = false
    @Published var errorMessage = ""
    @Published var renderedContent: NSImage?
    @Published var showingDevTools = false
    @Published var showPerformanceMetrics = true
    
    // MARK: - Page Information
    
    @Published var currentPageInfo: PageInfo?
    @Published var domInfo: DOMInfo?
    @Published var performanceMetrics: PerformanceMetrics?
    @Published var consoleLogs: [ConsoleLog] = []
    @Published var networkRequests: [NetworkRequest]?
    
    // MARK: - Private Properties
    
    private let webCoreEngine: WebCoreEngine
    private let urlSession: URLSession
    private let networkMonitor = NWPathMonitor()
    private var navigationHistory: [URL] = []
    private var currentHistoryIndex = -1
    private var viewport: CGSize = CGSize(width: 1024, height: 768)
    
    // MARK: - Initialization
    
    init() {
        // Configure URL session for web requests
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: sessionConfig)
        
        // Initialize WebCore engine
        var webCoreConfig = WebCoreConfiguration()
        webCoreConfig.enableJavaScript = true
        webCoreConfig.enableGPUAcceleration = true
        webCoreConfig.enableIncrementalLayout = true
        webCoreConfig.enablePaintDebugging = true
        webCoreConfig.enableLayoutDebugging = true
        webCoreConfig.userAgentString = "Loop Browser 1.0 (WebKit Compatible)"
        
        self.webCoreEngine = WebCoreEngine(configuration: webCoreConfig)
        
        setupWebCoreDelegate()
        startNetworkMonitoring()
        
        print("🌐 Browser Engine initialized")
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - WebCore Integration
    
    private func setupWebCoreDelegate() {
        webCoreEngine.delegate = self
    }
    
    // MARK: - Public API
    
    func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
        showError("Invalid URL: \(urlString)")
            return
        }
        
        loadURL(url)
    }
    
    func loadURL(_ url: URL) {
        print("🌐 Loading URL: \(url.absoluteString)")
        
        // Reset state
        clearError()
        isLoading = true
        loadProgress = 0.0
        currentURL = url
        isSecure = url.scheme == "https"
        
        // Add to history
        addToHistory(url)
        
        // Start loading
        Task {
            await fetchAndRender(url)
        }
    }
    
    func reload() {
        guard let url = currentURL else { return }
        
        // Clear cache and reload
        urlSession.configuration.urlCache?.removeAllCachedResponses()
        loadURL(url)
    }
    
    func goBack() {
        guard canGoBack, currentHistoryIndex > 0 else { return }
        
        currentHistoryIndex -= 1
        let url = navigationHistory[currentHistoryIndex]
        loadURL(url)
        updateNavigationState()
    }
    
    func goForward() {
        guard canGoForward, currentHistoryIndex < navigationHistory.count - 1 else { return }
        
        currentHistoryIndex += 1
        let url = navigationHistory[currentHistoryIndex]
        loadURL(url)
        updateNavigationState()
    }
    
    func setViewport(_ size: CGSize) {
        viewport = size
        webCoreEngine.setViewport(size)
    }
    
    func toggleDevTools() {
        showingDevTools.toggle()
        updateDOMInfo()
    }
    
    func viewSource() {
        // TODO: Implement view source functionality
        addConsoleLog("View source functionality not yet implemented", level: .info)
    }
    
    func inspectElement() {
        // TODO: Implement inspect element functionality
        addConsoleLog("Inspect element functionality not yet implemented", level: .info)
    }
    
    // MARK: - URL Fetching
    
    private func fetchAndRender(_ url: URL) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Update progress
            await MainActor.run { loadProgress = 0.1 }
            
            // Create request
            var request = URLRequest(url: url)
            request.setValue(webCoreEngine.configuration.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
            
            // Log network request
            logNetworkRequest(request)
            
            // Fetch data
            await MainActor.run { loadProgress = 0.3 }
            let (data, response) = try await urlSession.data(for: request)
            
            // Validate response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BrowserError.invalidResponse
            }
            
            // Log response
            logNetworkResponse(httpResponse)
            
            guard httpResponse.statusCode == 200 else {
                throw BrowserError.httpError(httpResponse.statusCode)
            }
            
            // Parse HTML content
            await MainActor.run { loadProgress = 0.5 }
            
            guard let htmlString = String(data: data, encoding: .utf8) else {
                throw BrowserError.encodingError
            }
            
            // Extract page info
            let pageInfo = extractPageInfo(from: htmlString, url: url)
            await MainActor.run { 
                self.currentPageInfo = pageInfo
                loadProgress = 0.7
            }
            
            // Render with WebCore
            webCoreEngine.setViewport(viewport)
            webCoreEngine.loadHTML(htmlString, baseURL: url)
            
            // Wait for WebCore to complete
            await waitForWebCoreCompletion()
            
            // Generate final image
            await MainActor.run { loadProgress = 0.9 }
            
            if let image = webCoreEngine.createImage() {
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                await MainActor.run {
                    self.renderedContent = nsImage
                }
            }
            
            // Complete loading
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            await MainActor.run {
                self.isLoading = false
                self.loadProgress = 1.0
                updatePerformanceMetrics(loadTime: totalTime)
                addConsoleLog("Page loaded successfully in \(String(format: "%.2f", totalTime * 1000))ms", level: .info)
            }
            
        } catch {
            await MainActor.run {
                showError("Failed to load \(url.absoluteString): \(error.localizedDescription)")
                addConsoleLog("Load error: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func waitForWebCoreCompletion() async {
        // Wait for WebCore to finish processing
        for _ in 0..<100 { // Max 10 seconds
            if !webCoreEngine.isLoading {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    // MARK: - Content Processing
    
    private func extractPageInfo(from html: String, url: URL) -> PageInfo {
        var title = url.host ?? "Untitled"
        var description = ""
        var favicon: URL?
        
        // Extract title
        if let titleMatch = html.range(of: "<title[^>]*>([^<]*)</title>", options: [.regularExpression, .caseInsensitive]) {
            let titleContent = String(html[titleMatch])
            if let contentMatch = titleContent.range(of: ">([^<]*)<", options: .regularExpression) {
                title = String(titleContent[contentMatch]).dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Extract description
        let descPattern = #"<meta[^>]*name=["\']description["\'][^>]*content=["\']([^"\']*)["\']"#
        if let descMatch = html.range(of: descPattern, options: [.regularExpression, .caseInsensitive]) {
            let descContent = String(html[descMatch])
            if let contentMatch = descContent.range(of: #"content=["\']([^"\']*)["\']"#, options: .regularExpression) {
                description = String(descContent[contentMatch])
                    .replacingOccurrences(of: #"content=["\']"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"["\']"#, with: "", options: .regularExpression)
            }
        }
        
        // Extract favicon
        let faviconPattern = #"<link[^>]*rel=["\'][^"\']*icon[^"\']*["\'][^>]*href=["\']([^"\']*)["\']"#
        if let faviconMatch = html.range(of: faviconPattern, options: [.regularExpression, .caseInsensitive]) {
            let faviconContent = String(html[faviconMatch])
            if let hrefMatch = faviconContent.range(of: #"href=["\']([^"\']*)["\']"#, options: .regularExpression) {
                let faviconPath = String(faviconContent[hrefMatch])
                    .replacingOccurrences(of: #"href=["\']"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"["\']"#, with: "", options: .regularExpression)
                favicon = URL(string: faviconPath, relativeTo: url)
            }
        }
        
        return PageInfo(
            title: title,
            description: description,
            url: url,
            favicon: favicon,
            loadTime: Date()
        )
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        hasError = true
        errorMessage = message
        isLoading = false
        loadProgress = nil
        print("❌ Browser Error: \\(message)")
    }
    
    private func clearError() {
        hasError = false
        errorMessage = ""
    }
    
    // MARK: - Navigation History
    
    private func addToHistory(_ url: URL) {
        // Remove any forward history when navigating to a new URL
        if currentHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((currentHistoryIndex + 1)...)
        }
        
        // Add new URL
        navigationHistory.append(url)
        currentHistoryIndex = navigationHistory.count - 1
        
        // Limit history size
        if navigationHistory.count > 100 {
            navigationHistory.removeFirst()
            currentHistoryIndex -= 1
        }
        
        updateNavigationState()
    }
    
    private func updateNavigationState() {
        canGoBack = currentHistoryIndex > 0
        canGoForward = currentHistoryIndex < navigationHistory.count - 1
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    self?.showError("No internet connection")
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - Logging and Debugging
    
    private func logNetworkRequest(_ request: URLRequest) {
        guard let url = request.url else { return }
        
        let networkRequest = NetworkRequest(
            url: url.absoluteString,
            method: request.httpMethod ?? "GET",
            statusCode: 0,
            startTime: Date()
        )
        
        if networkRequests == nil {
            networkRequests = []
        }
        networkRequests?.append(networkRequest)
    }
    
    private func logNetworkResponse(_ response: HTTPURLResponse) {
        guard var requests = networkRequests,
              let lastIndex = requests.indices.last else { return }
        
        requests[lastIndex].statusCode = response.statusCode
        requests[lastIndex].endTime = Date()
        networkRequests = requests
    }
    
    private func addConsoleLog(_ message: String, level: ConsoleLog.Level) {
        let log = ConsoleLog(message: message, level: level, timestamp: Date())
        consoleLogs.append(log)
        
        // Limit console log size
        if consoleLogs.count > 1000 {
            consoleLogs.removeFirst(100)
        }
    }
    
    private func updateDOMInfo() {
        let debugInfo = webCoreEngine.getDebugInfo()
        
        domInfo = DOMInfo(
            nodeCount: debugInfo["documentNodeCount"] as? Int ?? 0,
            structure: "DOM structure inspection coming soon..."
        )
    }
    
    private func updatePerformanceMetrics(loadTime: TimeInterval) {
        let debugInfo = webCoreEngine.getDebugInfo()
        
        performanceMetrics = PerformanceMetrics(
            loadTime: loadTime,
            parseTime: 0, // Would be extracted from WebCore
            layoutTime: debugInfo["lastLayoutTime"] as? TimeInterval ?? 0,
            paintTime: debugInfo["lastPaintTime"] as? TimeInterval ?? 0,
            domNodes: debugInfo["documentNodeCount"] as? Int ?? 0,
            renderObjects: debugInfo["renderObjectCount"] as? Int ?? 0,
            memoryUsage: Double(getMemoryUsage())
        )
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

// MARK: - WebCore Engine Delegate

extension BrowserEngine: WebCoreEngineDelegate {
    
    nonisolated func webCoreDidStartLoading(_ engine: WebCoreEngine) {
        Task { @MainActor in
            addConsoleLog("WebCore started loading", level: .info)
        }
    }
    
    nonisolated func webCoreDidFinishLoading(_ engine: WebCoreEngine) {
        Task { @MainActor in
            addConsoleLog("WebCore finished loading", level: .info)
            updateDOMInfo()
        }
    }
    
    nonisolated func webCoreDidFailLoading(_ engine: WebCoreEngine, error: Error) {
        Task { @MainActor in
            addConsoleLog("WebCore loading failed: \\(error.localizedDescription)", level: .error)
        }
    }
    
    nonisolated func webCoreDidUpdateLayout(_ engine: WebCoreEngine) {
        Task { @MainActor in
            addConsoleLog("WebCore layout updated", level: .info)
        }
    }
    
    nonisolated func webCoreDidRepaint(_ engine: WebCoreEngine, dirtyRect: CGRect) {
        Task { @MainActor in
            // Update rendered content when repaint occurs
            if let image = engine.createImage() {
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                renderedContent = nsImage
            }
        }
    }
}

// MARK: - Supporting Types

struct PageInfo {
    let title: String
    let description: String
    let url: URL
    let favicon: URL?
    let loadTime: Date
}

struct DOMInfo {
    let nodeCount: Int
    let structure: String
}

struct PerformanceMetrics {
    let loadTime: TimeInterval
    let parseTime: TimeInterval
    let layoutTime: TimeInterval
    let paintTime: TimeInterval
    let domNodes: Int
    let renderObjects: Int
    let memoryUsage: Double
}

struct ConsoleLog {
    let id = UUID()
    let message: String
    let level: Level
    let timestamp: Date
    
    enum Level {
        case info, warning, error
    }
}

struct NetworkRequest {
    let url: String
    let method: String
    var statusCode: Int
    let startTime: Date
    var endTime: Date?
}

// MARK: - Browser Errors

enum BrowserError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case encodingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP Error \(code)"
        case .encodingError:
            return "Unable to decode page content"
        case .networkError:
            return "Network connection failed"
        }
    }
}
