//
//  TabManager.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI
import Combine

// MARK: - Tab Data Model
class BrowserTab: ObservableObject, Identifiable {
    let id = UUID()
    @Published var url: String
    @Published var title: String
    @Published var isLoading: Bool = false
    @Published var history: [String] = []
    @Published var historyIndex: Int = -1
    
    var canGoBack: Bool {
        historyIndex > 0
    }
    
    var canGoForward: Bool {
        historyIndex < history.count - 1
    }
    
    init(url: String, title: String = "New Tab") {
        self.url = url
        self.title = title
        addToHistory(url)
    }
    
    func addToHistory(_ url: String) {
        // Remove any forward history if we're not at the end
        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)...)
        }
        
        // Add new URL if it's different from current
        if history.isEmpty || history.last != url {
            history.append(url)
            historyIndex = history.count - 1
        }
    }
    
    func goBack() -> String? {
        guard canGoBack else { return nil }
        historyIndex -= 1
        url = history[historyIndex]
        return url
    }
    
    func goForward() -> String? {
        guard canGoForward else { return nil }
        historyIndex += 1
        url = history[historyIndex]
        return url
    }
}

// MARK: - Tab Manager
class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabIndex: Int = 0
    
    var activeTab: BrowserTab? {
        guard activeTabIndex >= 0 && activeTabIndex < tabs.count else { return nil }
        return tabs[activeTabIndex]
    }
    
    init() {
        // Create initial tab
        addNewTab(url: "https://google.com")
    }
    
    func addNewTab(url: String = "https://google.com", makeActive: Bool = true) {
        let newTab = BrowserTab(url: url)
        tabs.append(newTab)
        if makeActive {
            activeTabIndex = tabs.count - 1
        }
    }
    
    func closeTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        tabs.remove(at: index)
        
        if tabs.isEmpty {
            // Create a new tab if we closed the last one
            addNewTab()
        } else if activeTabIndex >= tabs.count {
            // If we closed the active tab and it was the last one
            activeTabIndex = tabs.count - 1
        } else if index <= activeTabIndex {
            // If we closed a tab before or at the active tab
            activeTabIndex = max(0, activeTabIndex - 1)
        }
    }
    
    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        activeTabIndex = index
    }
    
    func moveTab(from source: Int, to destination: Int) {
        guard source != destination else { return }
        let tab = tabs.remove(at: source)
        tabs.insert(tab, at: destination)
        
        // Update active tab index
        if activeTabIndex == source {
            activeTabIndex = destination
        } else if activeTabIndex > source && activeTabIndex <= destination {
            activeTabIndex -= 1
        } else if activeTabIndex < source && activeTabIndex >= destination {
            activeTabIndex += 1
        }
    }
}

// MARK: - Tab Bar View
struct TabBar: View {
    @ObservedObject var tabManager: TabManager
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabView(
                            tab: tab,
                            isActive: index == tabManager.activeTabIndex,
                            onSelect: { tabManager.selectTab(at: index) },
                            onClose: { tabManager.closeTab(at: index) }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            
            // New Tab Button
            Button(action: { tabManager.addNewTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
}

// MARK: - Individual Tab View
struct TabView: View {
    @ObservedObject var tab: BrowserTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Tab content
            HStack(spacing: 4) {
                // Favicon placeholder
                Image(systemName: "globe")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                // Title
                Text(tab.title)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 150)
            
            // Close button
            if isHovered || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color(NSColor.selectedControlColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(NSColor.separatorColor), lineWidth: isActive ? 0 : 0.5)
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
