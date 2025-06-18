//
//  MemoryPool.swift
//  LoopEngine
//
//  High-performance memory pool for frequent allocations
//  Inspired by WebKit's WTF::FastMalloc
//

import Foundation

/// A high-performance memory pool that pre-allocates chunks of memory
/// for objects of a specific size, reducing allocation overhead
public final class MemoryPool<T> {
    private let chunkSize: Int
    private let itemsPerChunk: Int
    private var chunks: [UnsafeMutablePointer<T>] = []
    private var freeList: UnsafeMutablePointer<T>?
    private let lock = NSLock()
    
    public init(itemsPerChunk: Int = 64) {
        self.chunkSize = MemoryLayout<T>.stride
        self.itemsPerChunk = itemsPerChunk
    }
    
    deinit {
        lock.lock()
        defer { lock.unlock() }
        
        for chunk in chunks {
            chunk.deallocate()
        }
    }
    
    /// Allocate a new item from the pool
    public func allocate() -> UnsafeMutablePointer<T> {
        lock.lock()
        defer { lock.unlock() }
        
        if let free = freeList {
            // Pop from free list
            freeList = free.pointee as? UnsafeMutablePointer<T>
            return free
        }
        
        // Allocate new chunk
        let newChunk = UnsafeMutablePointer<T>.allocate(capacity: itemsPerChunk)
        chunks.append(newChunk)
        
        // Chain together free items in the chunk
        for i in 1..<itemsPerChunk {
            let current = newChunk.advanced(by: i - 1)
            let next = newChunk.advanced(by: i)
            current.withMemoryRebound(to: UnsafeMutablePointer<T>?.self, capacity: 1) { ptr in
                ptr.pointee = next
            }
        }
        
        // Last item points to previous free list
        let lastItem = newChunk.advanced(by: itemsPerChunk - 1)
        lastItem.withMemoryRebound(to: UnsafeMutablePointer<T>?.self, capacity: 1) { ptr in
            ptr.pointee = freeList
        }
        
        // Update free list to point to second item
        freeList = newChunk.advanced(by: 1)
        
        return newChunk
    }
    
    /// Return an item to the pool
    public func deallocate(_ pointer: UnsafeMutablePointer<T>) {
        lock.lock()
        defer { lock.unlock() }
        
        // Add to front of free list
        pointer.withMemoryRebound(to: UnsafeMutablePointer<T>?.self, capacity: 1) { ptr in
            ptr.pointee = freeList
        }
        freeList = pointer
    }
    
    /// Get pool statistics
    public var statistics: PoolStatistics {
        lock.lock()
        defer { lock.unlock() }
        
        let totalAllocated = chunks.count * itemsPerChunk
        var freeCount = 0
        var current = freeList
        
        while current != nil {
            freeCount += 1
            current = current?.withMemoryRebound(to: UnsafeMutablePointer<T>?.self, capacity: 1) { $0.pointee }
        }
        
        return PoolStatistics(
            totalAllocated: totalAllocated,
            freeItems: freeCount,
            usedItems: totalAllocated - freeCount,
            chunkCount: chunks.count
        )
    }
}

public struct PoolStatistics {
    public let totalAllocated: Int
    public let freeItems: Int
    public let usedItems: Int
    public let chunkCount: Int
    
    public var utilizationPercentage: Double {
        guard totalAllocated > 0 else { return 0.0 }
        return Double(usedItems) / Double(totalAllocated) * 100.0
    }
}

/// Thread-safe global memory pools for common types
public enum GlobalPools {
    private static let domNodePool = MemoryPool<Void>(itemsPerChunk: 128)
    private static let styleObjectPool = MemoryPool<Void>(itemsPerChunk: 256)
    private static let layoutBoxPool = MemoryPool<Void>(itemsPerChunk: 64)
    
    public static func allocateDOMNode<T>(_ type: T.Type) -> UnsafeMutablePointer<T> {
        return domNodePool.allocate().assumingMemoryBound(to: type)
    }
    
    public static func deallocateDOMNode<T>(_ pointer: UnsafeMutablePointer<T>) {
        domNodePool.deallocate(pointer.assumingMemoryBound(to: Void.self))
    }
    
    public static func allocateStyleObject<T>(_ type: T.Type) -> UnsafeMutablePointer<T> {
        return styleObjectPool.allocate().assumingMemoryBound(to: type)
    }
    
    public static func deallocateStyleObject<T>(_ pointer: UnsafeMutablePointer<T>) {
        styleObjectPool.deallocate(pointer.assumingMemoryBound(to: Void.self))
    }
    
    public static func allocateLayoutBox<T>(_ type: T.Type) -> UnsafeMutablePointer<T> {
        return layoutBoxPool.allocate().assumingMemoryBound(to: type)
    }
    
    public static func deallocateLayoutBox<T>(_ pointer: UnsafeMutablePointer<T>) {
        layoutBoxPool.deallocate(pointer.assumingMemoryBound(to: Void.self))
    }
}
