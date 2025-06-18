//
//  BrowserEngineView.swift
//  Loop - Central Browser View with WebCore Integration
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Browser Engine View

struct BrowserEngineView: View {
    
    // MARK: - State
    
    @StateObject private var browserEngine = BrowserEngine()
    @State private var urlString: String = "https://example.com"
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var renderedImage: NSImage?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            navigationBar
            
            // Content Area
            contentArea
            
            // Status Bar
            statusBar
        }
        .frame(minWidth: 800, minHeight: 600)
        .onReceive(browserEngine.$renderedContent) { image in
            self.renderedImage = image
        }
        .onReceive(browserEngine.$errorMessage) { message in
            if !message.isEmpty {
                self.errorMessage = message
                self.showingError = true
            }
        }
        .alert("Browser Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack(spacing: 12) {
            // Navigation buttons
            HStack(spacing: 8) {
                Button(action: browserEngine.goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(!browserEngine.canGoBack)
                
                Button(action: browserEngine.goForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(!browserEngine.canGoForward)
                
                Button(action: { browserEngine.reload() }) {
                    Image(systemName: browserEngine.isLoading ? "stop.fill" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .buttonStyle(.borderless)
            
            // URL Bar
            HStack {
                Image(systemName: browserEngine.isSecure ? "lock.fill" : "globe")
                    .foregroundColor(browserEngine.isSecure ? .green : .secondary)
                    .font(.system(size: 14))
                
                TextField("Enter URL or search", text: $urlString)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        loadURL()
                    }
                
                if browserEngine.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: { browserEngine.toggleDevTools() }) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 16))
                }
                
                Menu {
                    Button("View Source") { browserEngine.viewSource() }
                    Button("Inspect Element") { browserEngine.inspectElement() }
                    Divider()
                    Button("Settings") { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    // MARK: - Content Area
    
    private var contentArea: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(NSColor.textBackgroundColor)
                
                // Rendered content or loading state
                if let image = renderedImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: image)
                            .interpolation(.none)
                            .frame(
                                width: max(CGFloat(image.size.width), geometry.size.width),
                                height: max(CGFloat(image.size.height), geometry.size.height),
                                alignment: .topLeading
                            )
                    }
                } else if browserEngine.isLoading {
                    loadingView
                } else if browserEngine.hasError {
                    errorView
                } else {
                    welcomeView
                }
                
                // Dev tools overlay
                if browserEngine.showingDevTools {
                    devToolsOverlay
                }
            }
            .onAppear {
                browserEngine.setViewport(geometry.size)
            }
            .onChange(of: geometry.size) { newSize in
                browserEngine.setViewport(newSize)
            }
        }
    }
    
    // MARK: - Status Bar
    
    private var statusBar: some View {
        HStack {
            // Page info
            if let pageInfo = browserEngine.currentPageInfo {
                HStack(spacing: 8) {
                    Text(pageInfo.title.isEmpty ? "Untitled" : pageInfo.title)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if browserEngine.isLoading {
                        Text("Loading...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ready")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Loop Browser")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Performance metrics
            if browserEngine.showPerformanceMetrics {
                performanceMetrics
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading \(browserEngine.currentURL?.host ?? "page")...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if let progress = browserEngine.loadProgress, progress > 0 {
                ProgressView(value: progress)
                    .frame(width: 200)
            }
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Failed to Load Page")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(browserEngine.errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                browserEngine.reload()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Welcome to Loop Browser")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Enter a URL in the address bar to get started")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Try these examples:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(sampleURLs, id: \.self) { url in
                    Button(url) {
                        urlString = url
                        loadURL()
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }
    
    private var devToolsOverlay: some View {
        VStack {
            Spacer()
            
            DevToolsPanel(browserEngine: browserEngine)
                .frame(height: 300)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor)),
                    alignment: .top
                )
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut(duration: 0.3), value: browserEngine.showingDevTools)
    }
    
    private var performanceMetrics: some View {
        HStack(spacing: 12) {
            if let metrics = browserEngine.performanceMetrics {
                Group {
                    Label("\(Int(metrics.loadTime * 1000))ms", systemImage: "clock")
                    Label("\(metrics.domNodes)", systemImage: "list.bullet")
                    Label("\(metrics.renderObjects)", systemImage: "square.stack.3d.up")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Sample URLs
    
    private let sampleURLs = [
        "https://example.com",
        "https://httpbin.org/html",
        "https://www.w3.org/",
        "https://developer.mozilla.org/"
    ]
    
    // MARK: - Actions
    
    private func loadURL() {
        guard !urlString.isEmpty else { return }
        
        // Auto-complete URL if needed
        let processedURL: String
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            processedURL = urlString
        } else if urlString.contains(".") {
            processedURL = "https://" + urlString
        } else {
            // Search query
            let encodedQuery = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
            processedURL = "https://duckduckgo.com/?q=\(encodedQuery)"
        }
        
        browserEngine.loadURL(processedURL)
    }
}

// MARK: - Dev Tools Panel

struct DevToolsPanel: View {
    @ObservedObject var browserEngine: BrowserEngine
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack {
                ForEach(["Elements", "Console", "Network", "Performance"], id: \.self) { tab in
                    Button(tab) {
                        selectedTab = ["Elements", "Console", "Network", "Performance"].firstIndex(of: tab) ?? 0
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(selectedTab == ["Elements", "Console", "Network", "Performance"].firstIndex(of: tab) ? .primary : .secondary)
                }
                
                Spacer()
                
                Button {
                    browserEngine.toggleDevTools()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch selectedTab {
                    case 0: elementsPanel
                    case 1: consolePanel
                    case 2: networkPanel
                    case 3: performancePanel
                    default: EmptyView()
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private var elementsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let domInfo = browserEngine.domInfo {
                Text("DOM Structure (\\(domInfo.nodeCount) nodes)")
                    .font(.headline)
                
                Text(domInfo.structure)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                Text("No DOM information available")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var consolePanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Console")
                .font(.headline)
            
            ForEach(browserEngine.consoleLogs, id: \.id) { log in
                Text(log.message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(log.level == .error ? .red : .primary)
            }
        }
    }
    
    private var networkPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Network Requests")
                .font(.headline)
            
            if let requests = browserEngine.networkRequests {
                ForEach(requests, id: \.url) { request in
                    HStack {
                        Text(request.method)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.blue)
                        
                        Text(request.url)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\\(request.statusCode)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(request.statusCode < 400 ? .green : .red)
                    }
                }
            } else {
                Text("No network requests")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var performancePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)
            
            if let metrics = browserEngine.performanceMetrics {
                Group {
                    metricRow("Load Time", "\(String(format: "%.2f", metrics.loadTime * 1000))ms")
                    metricRow("Parse Time", "\(String(format: "%.2f", metrics.parseTime * 1000))ms")
                    metricRow("Layout Time", "\(String(format: "%.2f", metrics.layoutTime * 1000))ms")
                    metricRow("Paint Time", "\(String(format: "%.2f", metrics.paintTime * 1000))ms")
                    metricRow("DOM Nodes", "\(metrics.domNodes)")
                    metricRow("Render Objects", "\(metrics.renderObjects)")
                    metricRow("Memory Usage", "\(String(format: "%.1f", metrics.memoryUsage / 1024 / 1024))MB")
                }
            } else {
                Text("No performance data available")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    BrowserEngineView()
        .frame(width: 1200, height: 800)
}
