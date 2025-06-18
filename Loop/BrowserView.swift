//
//  BrowserView.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI
import Combine
import AppKit

struct BrowserView: View {
    @StateObject private var tabManager = TabManager()
    @State private var addressBarText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            TabBar(tabManager: tabManager)
            
            // Navigation Bar
            navigationBar
            
            // Web Content
            if let activeTab = tabManager.activeTab {
                NativeWebView(urlString: activeTab.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(activeTab.id) // Force re-render when tab changes
            } else {
                Text("No active tab")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            updateAddressBar()
        }
        .onChange(of: tabManager.activeTabIndex) {
            updateAddressBar()
        }
        .background(KeyboardShortcutHandler(tabManager: tabManager))
    }
    
    private var navigationBar: some View {
        VStack(spacing: 8) {
            // Top controls (back, forward, refresh)
            HStack(spacing: 12) {
                // Back button
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor((tabManager.activeTab?.canGoBack ?? false) ? .primary : .secondary)
                }
                .disabled(!(tabManager.activeTab?.canGoBack ?? false))
                
                // Forward button
                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor((tabManager.activeTab?.canGoForward ?? false) ? .primary : .secondary)
                }
                .disabled(!(tabManager.activeTab?.canGoForward ?? false))
                
                // Refresh button
                Button(action: refresh) {
                    Image(systemName: (tabManager.activeTab?.isLoading ?? false) ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Settings button (placeholder)
                Button(action: {}) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Address bar
            HStack(spacing: 12) {
                // URL field
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    FocusableTextField(
                        text: $addressBarText,
                        placeholder: "Enter URL or search",
                        onSubmit: navigateToURL
                    )
                    .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Go button
                Button(action: navigateToURL) {
                    Text("Go")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    // MARK: - Navigation Functions
    
    private func navigateToURL() {
        guard let activeTab = tabManager.activeTab else { return }
        
        var urlToNavigate = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no protocol specified
        if !urlToNavigate.hasPrefix("http://") && !urlToNavigate.hasPrefix("https://") {
            // Check if it looks like a URL (contains dots)
            if urlToNavigate.contains(".") && !urlToNavigate.contains(" ") {
                urlToNavigate = "https://" + urlToNavigate
            } else {
                // Treat as search query
                urlToNavigate = "https://www.google.com/search?q=" + urlToNavigate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        
        activeTab.url = urlToNavigate
        activeTab.addToHistory(urlToNavigate)
        addressBarText = urlToNavigate
    }
    
    private func goBack() {
        guard let activeTab = tabManager.activeTab else { return }
        if let url = activeTab.goBack() {
            addressBarText = url
        }
    }
    
    private func goForward() {
        guard let activeTab = tabManager.activeTab else { return }
        if let url = activeTab.goForward() {
            addressBarText = url
        }
    }
    
    private func refresh() {
        guard let activeTab = tabManager.activeTab else { return }
        // Force refresh by updating the URL (triggers WebRenderer reload)
        let temp = activeTab.url
        activeTab.url = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            activeTab.url = temp
        }
    }
    
    private func updateAddressBar() {
        guard let activeTab = tabManager.activeTab else { return }
        addressBarText = activeTab.url
    }
}

#Preview {
    BrowserView()
        .frame(width: 800, height: 600)
}
