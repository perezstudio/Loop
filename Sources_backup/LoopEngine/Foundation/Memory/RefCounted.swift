//
//  RefCounted.swift
//  LoopEngine
//
//  Reference counting system similar to WebKit's RefCounted
//

import Foundation

/// Base class for reference-counted objects
/// Provides automatic memory management for DOM nodes and style objects
public class RefCounted {
    private var refCount: Int32 = 1
    private let refCountLock = NSLock()
    
    public init() {}
    
    /// Increment reference count
    @discardableResult
    public final func ref() -> Self {
        refCountLock.lock()
        defer { refCountLock.unlock() }
        refCount += 1
        return self
    }
    
    /// Decrement reference count and delete if it reaches zero
    public final func deref() {
        var shouldDestroy = false
        
        refCountLock.lock()
        refCount -= 1
        shouldDestroy = refCount == 0
        refCountLock.unlock()
        
        if shouldDestroy {
            destroy()
        }
    }
    
    /// Current reference count (for debugging)
    public final var referenceCount: Int32 {
        refCountLock.lock()
        defer { refCountLock.unlock() }
        return refCount
    }
    
    /// Override this method to perform cleanup
    /// Called automatically when reference count reaches zero
    open func destroy() {
        // Subclasses should override this
    }
    
    deinit {
        assert(refCount == 0, "RefCounted object deallocated with non-zero ref count: \(refCount)")
    }
}

/// A smart pointer that automatically manages reference counting
public final class Ref<T: RefCounted> {
    private var pointer: T?
    
    public init(_ object: T) {
        pointer = object.ref()
    }
    
    public init?(_ object: T?) {
        guard let obj = object else {
            pointer = nil
            return
        }
        pointer = obj.ref()
    }
    
    deinit {
        pointer?.deref()
    }
    
    /// Get the underlying object
    public var object: T? {
        return pointer
    }
    
    /// Access the underlying object (force unwrap)
    public var get: T {
        guard let obj = pointer else {
            fatalError("Attempting to access null Ref")
        }
        return obj
    }
    
    /// Release the current reference and take a new one
    public func reset(_ newObject: T?) {
        let oldPointer = pointer
        
        if let obj = newObject {
            pointer = obj.ref()
        } else {
            pointer = nil
        }
        
        oldPointer?.deref()
    }
    
    /// Release the reference
    public func clear() {
        reset(nil)
    }
    
    /// Check if the reference is valid
    public var isValid: Bool {
        return pointer != nil
    }
}

/// Convenience functions for creating references
public func makeRef<T: RefCounted>(_ object: T) -> Ref<T> {
    return Ref(object)
}

/// Protocol for objects that can be reference counted
public protocol RefCountable: AnyObject {
    func ref() -> Self
    func deref()
}

extension RefCounted: RefCountable {}

/// Weak reference that doesn't affect reference counting
public final class WeakRef<T: RefCounted> {
    private weak var pointer: T?
    
    public init(_ object: T?) {
        pointer = object
    }
    
    public var object: T? {
        return pointer
    }
    
    public var isValid: Bool {
        return pointer != nil
    }
    
    public func clear() {
        pointer = nil
    }
}
