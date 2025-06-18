//
//  Logger.swift
//  LoopEngine
//
//  High-performance logging system for debugging and profiling
//  Inspired by WebKit's WTFLogVerbose system
//

import Foundation
import OSLog

/// Log levels for different types of messages
public enum LogLevel: Int, Comparable, CaseIterable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var emoji: String {
        switch self {
        case .verbose: return "🔍"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

/// Log categories for different engine subsystems
public enum LogCategory: String, CaseIterable {
    case dom = "DOM"
    case layout = "Layout"
    case rendering = "Rendering"
    case parser = "Parser"
    case style = "Style"
    case javascript = "JavaScript"
    case network = "Network"
    case memory = "Memory"
    case performance = "Performance"
    case graphics = "Graphics"
    case general = "General"
    
    var osLogger: os.Logger {
        return os.Logger(subsystem: "com.loop.engine", category: rawValue)
    }
}

/// High-performance logger with compile-time optimizations
public struct Logger {
    
    // MARK: - Configuration
    
    /// Global log level - messages below this level are ignored
    public static var globalLogLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .warning
        #endif
    }()
    
    /// Enable/disable specific categories
    public static var enabledCategories: Set<LogCategory> = Set(LogCategory.allCases)
    
    /// Enable performance logging (can be expensive)
    public static var performanceLoggingEnabled: Bool = {
        #if LOOP_ENGINE_PERFORMANCE_LOGGING
        return true
        #else
        return false
        #endif
    }()
    
    /// Maximum message length before truncation
    public static var maxMessageLength: Int = 1000
    
    // MARK: - Core Logging Functions
    
    /// Log a message with specified level and category
    @inlinable
    public static func log(
        level: LogLevel,
        category: LogCategory,
        message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Early return for disabled logs (compile-time optimization)
        guard level >= globalLogLevel && enabledCategories.contains(category) else {
            return
        }
        
        let messageText = message()
        let truncatedMessage = messageText.count > maxMessageLength 
            ? String(messageText.prefix(maxMessageLength)) + "..."
            : messageText
            
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(category.rawValue)] \(function):\(line) - \(truncatedMessage)"
        
        // Use os_log for optimal performance
        let logger = category.osLogger
        logger.log(level: level.osLogType, "\(logMessage, privacy: .public)")
        
        // Also print to console in debug builds
        #if DEBUG
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("\(timestamp) \(level.emoji) \(logMessage)")
        #endif
    }
    
    // MARK: - Convenience Functions
    
    @inlinable
    public static func verbose(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .verbose, category: category, message: message(), file: file, function: function, line: line)
    }
    
    @inlinable
    public static func debug(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, category: category, message: message(), file: file, function: function, line: line)
    }
    
    @inlinable
    public static func info(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, category: category, message: message(), file: file, function: function, line: line)
    }
    
    @inlinable
    public static func warning(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, category: category, message: message(), file: file, function: function, line: line)
    }
    
    @inlinable
    public static func error(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, category: category, message: message(), file: file, function: function, line: line)
    }
    
    @inlinable
    public static func critical(
        _ message: @autoclosure () -> String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .critical, category: category, message: message(), file: file, function: function, line: line)
    }
}

// MARK: - Performance Profiling

/// High-precision timer for performance measurements
public struct PerformanceTimer {
    private let startTime: UInt64
    private let category: LogCategory
    private let operation: String
    
    public init(category: LogCategory, operation: String) {
        self.category = category
        self.operation = operation
        self.startTime = mach_absolute_time()
        
        if Logger.performanceLoggingEnabled {
            Logger.verbose("Started: \(operation)", category: category)
        }
    }
    
    /// Get elapsed time in nanoseconds
    public var elapsedNanoseconds: UInt64 {
        let endTime = mach_absolute_time()
        let elapsed = endTime - startTime
        
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        
        return elapsed * UInt64(timebase.numer) / UInt64(timebase.denom)
    }
    
    /// Get elapsed time in microseconds
    public var elapsedMicroseconds: Double {
        return Double(elapsedNanoseconds) / 1000.0
    }
    
    /// Get elapsed time in milliseconds
    public var elapsedMilliseconds: Double {
        return Double(elapsedNanoseconds) / 1_000_000.0
    }
    
    /// Complete the timer and log the result
    public func complete() {
        if Logger.performanceLoggingEnabled {
            let ms = elapsedMilliseconds
            Logger.info("Completed: \(operation) in \(String(format: "%.3f", ms))ms", category: category)
        }
    }
}

/// Macro for automatic performance timing
@inlinable
public func measurePerformance<T>(
    category: LogCategory,
    operation: String,
    block: () throws -> T
) rethrows -> T {
    let timer = PerformanceTimer(category: category, operation: operation)
    defer { timer.complete() }
    return try block()
}

/// Async version of performance measurement
@inlinable
public func measurePerformanceAsync<T>(
    category: LogCategory,
    operation: String,
    block: () async throws -> T
) async rethrows -> T {
    let timer = PerformanceTimer(category: category, operation: operation)
    defer { timer.complete() }
    return try await block()
}

// MARK: - Memory Logging

/// Log memory allocation/deallocation for debugging
public struct MemoryLogger {
    
    @inlinable
    public static func logAllocation(type: String, size: Int, pointer: UnsafeRawPointer?) {
        guard Logger.performanceLoggingEnabled else { return }
        Logger.verbose(
            "Allocated \(type): \(size) bytes at \(String(describing: pointer))",
            category: .memory
        )
    }
    
    @inlinable
    public static func logDeallocation(type: String, pointer: UnsafeRawPointer?) {
        guard Logger.performanceLoggingEnabled else { return }
        Logger.verbose(
            "Deallocated \(type) at \(String(describing: pointer))",
            category: .memory
        )
    }
    
    @inlinable
    public static func logMemoryUsage(category: String, bytesUsed: Int) {
        Logger.info(
            "Memory usage [\(category)]: \(ByteCountFormatter.string(fromByteCount: Int64(bytesUsed), countStyle: .memory))",
            category: .memory
        )
    }
}

// MARK: - Assert and Fatal Error Logging

/// Enhanced assert that logs the failure
@inlinable
public func loopAssert(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = "Assertion failed",
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    if !condition() {
        Logger.critical(
            "ASSERTION FAILED: \(message())",
            category: category,
            file: file,
            function: function,
            line: line
        )
        assertionFailure(message(), file: file, line: UInt(line))
    }
}

/// Fatal error with logging
@inlinable
public func loopFatalError(
    _ message: @autoclosure () -> String,
    category: LogCategory = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) -> Never {
    Logger.critical(
        "FATAL ERROR: \(message())",
        category: category,
        file: file,
        function: function,
        line: line
    )
    fatalError(message(), file: file, line: UInt(line))
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Category-Specific Logging Extensions

extension Logger {
    
    // DOM-specific logging
    public static func domNodeCreated(_ nodeType: String, nodeId: UInt64) {
        debug("Created \(nodeType) node (ID: \(nodeId))", category: .dom)
    }
    
    public static func domNodeDestroyed(_ nodeType: String, nodeId: UInt64) {
        debug("Destroyed \(nodeType) node (ID: \(nodeId))", category: .dom)
    }
    
    public static func domTreeModified(_ operation: String, nodeId: UInt64) {
        verbose("DOM tree modified: \(operation) (Node ID: \(nodeId))", category: .dom)
    }
    
    // Layout-specific logging
    public static func layoutStarted(for elementCount: Int) {
        info("Layout started for \(elementCount) elements", category: .layout)
    }
    
    public static func layoutCompleted(duration: Double) {
        info("Layout completed in \(String(format: "%.2f", duration))ms", category: .layout)
    }
    
    // Rendering-specific logging
    public static func renderFrameStarted() {
        verbose("Render frame started", category: .rendering)
    }
    
    public static func renderFrameCompleted(duration: Double) {
        info("Render frame completed in \(String(format: "%.2f", duration))ms", category: .rendering)
    }
    
    // Style-specific logging
    public static func styleRecalcStarted() {
        verbose("Style recalculation started", category: .style)
    }
    
    public static func styleRecalcCompleted(elementCount: Int, duration: Double) {
        info("Style recalc completed: \(elementCount) elements in \(String(format: "%.2f", duration))ms", category: .style)
    }
    
    // Network-specific logging
    public static func networkRequestStarted(url: String) {
        info("Network request started: \(url)", category: .network)
    }
    
    public static func networkRequestCompleted(url: String, statusCode: Int, duration: Double) {
        info("Network request completed: \(url) (\(statusCode)) in \(String(format: "%.2f", duration))ms", category: .network)
    }
}
