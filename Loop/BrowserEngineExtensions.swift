//
//  BrowserEngineExtensions.swift
//  Loop - Browser Engine Extensions and Helpers
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import SwiftUI
import Combine
import Network

// MARK: - WebCoreConfiguration Extension

extension WebCore.Configuration {
    var userAgent: String {
        get { return self.userAgentString }
        set { /* userAgent is read-only in this implementation */ }
    }
}

// MARK: - URL Extensions

extension URL {
    var isSecure: Bool {
        return scheme?.lowercased() == "https"
    }
    
    var displayString: String {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.fragment = nil // Remove fragment for display
        return components?.url?.absoluteString ?? absoluteString
    }
}

// MARK: - String Extensions

extension String {
    func isValidURL() -> Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    func toSearchURL() -> String {
        let encodedQuery = self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
        return "https://duckduckgo.com/?q=\(encodedQuery)"
    }
    
    func normalizeURL() -> String {
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            return self
        } else if self.contains(".") && !self.contains(" ") {
            return "https://" + self
        } else {
            return self.toSearchURL()
        }
    }
}

// MARK: - Error Extensions

extension Error {
    var userFriendlyDescription: String {
        if let browserError = self as? BrowserError {
            return browserError.errorDescription ?? localizedDescription
        }
        
        if let urlError = self as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection"
            case .timedOut:
                return "Request timed out"
            case .cannotFindHost:
                return "Cannot find server"
            case .badServerResponse:
                return "Invalid server response"
            case .cannotDecodeContentData:
                return "Cannot decode page content"
            default:
                return urlError.localizedDescription
            }
        }
        
        return localizedDescription
    }
}

// MARK: - Performance Monitoring

class PerformanceMonitor {
    private var startTime: CFAbsoluteTime = 0
    private var milestones: [String: CFAbsoluteTime] = [:]
    
    func start() {
        startTime = CFAbsoluteTimeGetCurrent()
        milestones.removeAll()
    }
    
    func milestone(_ name: String) {
        milestones[name] = CFAbsoluteTimeGetCurrent()
    }
    
    func duration(from milestone: String) -> TimeInterval? {
        guard let milestoneTime = milestones[milestone] else { return nil }
        return CFAbsoluteTimeGetCurrent() - milestoneTime
    }
    
    func totalDuration() -> TimeInterval {
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    func report() -> [String: TimeInterval] {
        var report: [String: TimeInterval] = [:]
        report["total"] = totalDuration()
        
        for (name, time) in milestones {
            report[name] = time - startTime
        }
        
        return report
    }
}

// MARK: - Memory Utilities

struct MemoryUtils {
    static func getCurrentMemoryUsage() -> UInt64 {
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
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Network Status

class NetworkStatus: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi, cellular, ethernet, unknown
    }
    
    private let monitor = NWPathMonitor()
    
    init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}

// MARK: - User Preferences

class BrowserPreferences: ObservableObject {
    @Published var enableJavaScript = true
    @Published var enableImages = true
    @Published var enablePopups = false
    @Published var enableDevTools = true
    @Published var showPerformanceMetrics = true
    @Published var defaultSearchEngine = "DuckDuckGo"
    @Published var userAgent = "Loop Browser 1.0"
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadPreferences()
    }
    
    private func loadPreferences() {
        enableJavaScript = userDefaults.object(forKey: "enableJavaScript") as? Bool ?? true
        enableImages = userDefaults.object(forKey: "enableImages") as? Bool ?? true
        enablePopups = userDefaults.object(forKey: "enablePopups") as? Bool ?? false
        enableDevTools = userDefaults.object(forKey: "enableDevTools") as? Bool ?? true
        showPerformanceMetrics = userDefaults.object(forKey: "showPerformanceMetrics") as? Bool ?? true
        defaultSearchEngine = userDefaults.string(forKey: "defaultSearchEngine") ?? "DuckDuckGo"
        userAgent = userDefaults.string(forKey: "userAgent") ?? "Loop Browser 1.0"
    }
    
    func savePreferences() {
        userDefaults.set(enableJavaScript, forKey: "enableJavaScript")
        userDefaults.set(enableImages, forKey: "enableImages")
        userDefaults.set(enablePopups, forKey: "enablePopups")
        userDefaults.set(enableDevTools, forKey: "enableDevTools")
        userDefaults.set(showPerformanceMetrics, forKey: "showPerformanceMetrics")
        userDefaults.set(defaultSearchEngine, forKey: "defaultSearchEngine")
        userDefaults.set(userAgent, forKey: "userAgent")
    }
}

// MARK: - Bookmark Manager

class BookmarkManager: ObservableObject {
    @Published var bookmarks: [Bookmark] = []
    
    struct Bookmark: Identifiable, Codable {
        let id = UUID()
        let title: String
        let url: URL
        let favicon: URL?
        let dateAdded: Date
        
        init(title: String, url: URL, favicon: URL? = nil) {
            self.title = title
            self.url = url
            self.favicon = favicon
            self.dateAdded = Date()
        }
    }
    
    init() {
        loadBookmarks()
    }
    
    func addBookmark(title: String, url: URL, favicon: URL? = nil) {
        let bookmark = Bookmark(title: title, url: url, favicon: favicon)
        bookmarks.append(bookmark)
        saveBookmarks()
    }
    
    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }
    
    func isBookmarked(_ url: URL) -> Bool {
        return bookmarks.contains { $0.url == url }
    }
    
    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: "bookmarks"),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return
        }
        bookmarks = decoded
    }
    
    private func saveBookmarks() {
        guard let encoded = try? JSONEncoder().encode(bookmarks) else { return }
        UserDefaults.standard.set(encoded, forKey: "bookmarks")
    }
}

// MARK: - History Manager

class HistoryManager: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    
    struct HistoryItem: Identifiable, Codable {
        let id = UUID()
        let title: String
        let url: URL
        let visitDate: Date
        
        init(title: String, url: URL) {
            self.title = title
            self.url = url
            self.visitDate = Date()
        }
    }
    
    init() {
        loadHistory()
    }
    
    func addHistoryItem(title: String, url: URL) {
        // Don't add duplicate entries for the same URL within a short time
        if let lastItem = historyItems.first,
           lastItem.url == url,
           Date().timeIntervalSince(lastItem.visitDate) < 300 { // 5 minutes
            return
        }
        
        let item = HistoryItem(title: title, url: url)
        historyItems.insert(item, at: 0)
        
        // Limit history size
        if historyItems.count > 1000 {
            historyItems = Array(historyItems.prefix(1000))
        }
        
        saveHistory()
    }
    
    func clearHistory() {
        historyItems.removeAll()
        saveHistory()
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "history"),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }
        historyItems = decoded
    }
    
    private func saveHistory() {
        guard let encoded = try? JSONEncoder().encode(historyItems) else { return }
        UserDefaults.standard.set(encoded, forKey: "history")
    }
}

// MARK: - Import Required Modules

#if canImport(AppKit)
import AppKit
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#endif
