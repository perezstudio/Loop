//
//  KeyboardShortcuts.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - Keyboard Shortcuts Support

struct KeyboardShortcutHandler: NSViewRepresentable {
    @ObservedObject var tabManager: TabManager
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        // Set up local event monitor for key events
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return handleKeyEvent(event)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags
        let keyCode = event.keyCode
        
        // Check for Command key combinations
        if modifiers.contains(.command) {
            switch keyCode {
            case 17: // Cmd+T - New Tab
                tabManager.addNewTab()
                return nil
                
            case 13: // Cmd+W - Close Tab
                if tabManager.tabs.count > 1 {
                    tabManager.closeTab(at: tabManager.activeTabIndex)
                }
                return nil
                
            case 15: // Cmd+R - Refresh
                refreshCurrentTab()
                return nil
                
            case 37: // Cmd+L - Focus Address Bar
                focusAddressBar()
                return nil
                
            case 3: // Cmd+D - Bookmark (placeholder)
                bookmarkCurrentPage()
                return nil
                
            case 1: // Cmd+S - Save Page (placeholder)
                saveCurrentPage()
                return nil
                
            case 2: // Cmd+D - Duplicate Tab (when Shift is also pressed)
                if modifiers.contains(.shift) {
                    duplicateCurrentTab()
                    return nil
                }
                
            case 125: // Cmd+Down Arrow - End of page
                scrollToBottom()
                return nil
                
            case 126: // Cmd+Up Arrow - Top of page
                scrollToTop()
                return nil
                
            default:
                break
            }
            
            // Handle Cmd+Number for tab switching
            if keyCode >= 18 && keyCode <= 26 { // Numbers 1-9
                let tabIndex = Int(keyCode - 18)
                if tabIndex < tabManager.tabs.count {
                    tabManager.selectTab(at: tabIndex)
                    return nil
                }
            }
        }
        
        // Check for Cmd+Shift combinations
        if modifiers.contains([.command, .shift]) {
            switch keyCode {
            case 17: // Cmd+Shift+T - Reopen closed tab (placeholder)
                reopenClosedTab()
                return nil
                
            case 15: // Cmd+Shift+R - Hard refresh
                hardRefreshCurrentTab()
                return nil
                
            default:
                break
            }
        }
        
        // Check for Cmd+Option combinations
        if modifiers.contains([.command, .option]) {
            switch keyCode {
            case 123: // Cmd+Option+Left - Previous tab
                selectPreviousTab()
                return nil
                
            case 124: // Cmd+Option+Right - Next tab
                selectNextTab()
                return nil
                
            default:
                break
            }
        }
        
        // Allow the event to continue
        return event
    }
    
    // MARK: - Action Handlers
    
    private func refreshCurrentTab() {
        guard let activeTab = tabManager.activeTab else { return }
        // Trigger refresh by temporarily clearing and restoring URL
        let currentURL = activeTab.url
        activeTab.url = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            activeTab.url = currentURL
        }
    }
    
    private func hardRefreshCurrentTab() {
        // Same as regular refresh for now, but could clear cache in the future
        refreshCurrentTab()
    }
    
    private func focusAddressBar() {
        // Post notification to focus address bar
        NotificationCenter.default.post(name: .focusAddressBar, object: nil)
    }
    
    private func bookmarkCurrentPage() {
        guard let activeTab = tabManager.activeTab else { return }
        print("Bookmarking: \(activeTab.url)")
        // TODO: Implement bookmarking system
    }
    
    private func saveCurrentPage() {
        guard let activeTab = tabManager.activeTab else { return }
        print("Saving page: \(activeTab.url)")
        // TODO: Implement page saving
    }
    
    private func duplicateCurrentTab() {
        guard let activeTab = tabManager.activeTab else { return }
        tabManager.addNewTab(url: activeTab.url, makeActive: true)
    }
    
    private func scrollToTop() {
        // Post notification to scroll to top
        NotificationCenter.default.post(name: .scrollToTop, object: nil)
    }
    
    private func scrollToBottom() {
        // Post notification to scroll to bottom
        NotificationCenter.default.post(name: .scrollToBottom, object: nil)
    }
    
    private func selectPreviousTab() {
        let currentIndex = tabManager.activeTabIndex
        let newIndex = currentIndex > 0 ? currentIndex - 1 : tabManager.tabs.count - 1
        tabManager.selectTab(at: newIndex)
    }
    
    private func selectNextTab() {
        let currentIndex = tabManager.activeTabIndex
        let newIndex = currentIndex < tabManager.tabs.count - 1 ? currentIndex + 1 : 0
        tabManager.selectTab(at: newIndex)
    }
    
    private func reopenClosedTab() {
        // TODO: Implement recently closed tabs tracking
        print("Reopening closed tab (not implemented)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let focusAddressBar = Notification.Name("focusAddressBar")
    static let scrollToTop = Notification.Name("scrollToTop")
    static let scrollToBottom = Notification.Name("scrollToBottom")
}

// MARK: - Address Bar Focus Support

struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.stringValue = text
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        
        // Listen for focus notification
        NotificationCenter.default.addObserver(
            forName: .focusAddressBar,
            object: nil,
            queue: .main
        ) { _ in
            textField.becomeFirstResponder()
            textField.selectText(nil)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FocusableTextField
        
        init(_ parent: FocusableTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onSubmit()
        }
    }
}
