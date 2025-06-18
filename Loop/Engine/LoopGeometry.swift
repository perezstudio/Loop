//
//  LoopGeometry.swift
//  Loop
//
//  Core geometric primitives for the Loop engine
//

import Foundation
import simd

/// High-performance point structure using SIMD
public struct Point: Hashable, Codable {
    public var x: Float
    public var y: Float
    
    public init(x: Float = 0, y: Float = 0) {
        self.x = x
        self.y = y
    }
    
    public init(_ vector: simd_float2) {
        self.x = vector.x
        self.y = vector.y
    }
    
    /// Convert to SIMD vector for fast math operations
    public var simd: simd_float2 {
        return simd_float2(x, y)
    }
    
    /// Zero point constant
    public static let zero = Point(x: 0, y: 0)
}

/// Rectangle structure optimized for layout calculations
public struct Rect: Hashable, Codable {
    public var origin: Point
    public var size: Size
    
    public init(origin: Point = .zero, size: Size = .zero) {
        self.origin = origin
        self.size = size
    }
    
    public init(x: Float, y: Float, width: Float, height: Float) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }
    
    /// Rect properties
    public var x: Float {
        get { origin.x }
        set { origin.x = newValue }
    }
    
    public var y: Float {
        get { origin.y }
        set { origin.y = newValue }
    }
    
    public var width: Float {
        get { size.width }
        set { size.width = newValue }
    }
    
    public var height: Float {
        get { size.height }
        set { size.height = newValue }
    }
    
    /// Computed properties
    public var minX: Float { origin.x }
    public var midX: Float { origin.x + size.width * 0.5 }
    public var maxX: Float { origin.x + size.width }
    
    public var minY: Float { origin.y }
    public var midY: Float { origin.y + size.height * 0.5 }
    public var maxY: Float { origin.y + size.height }
    
    /// Zero rect constant
    public static let zero = Rect(origin: .zero, size: .zero)
    
    /// Check if rectangles intersect
    public func intersects(_ rect: Rect) -> Bool {
        return maxX > rect.minX && minX < rect.maxX &&
               maxY > rect.minY && minY < rect.maxY
    }
    
    /// Get intersection of two rectangles
    public func intersection(_ rect: Rect) -> Rect {
        let newMinX = max(minX, rect.minX)
        let newMinY = max(minY, rect.minY)
        let newMaxX = min(maxX, rect.maxX)
        let newMaxY = min(maxY, rect.maxY)
        
        if newMinX < newMaxX && newMinY < newMaxY {
            return Rect(x: newMinX, y: newMinY, width: newMaxX - newMinX, height: newMaxY - newMinY)
        } else {
            return .zero
        }
    }
    
    /// Get union of two rectangles
    public func union(_ rect: Rect) -> Rect {
        let newMinX = min(minX, rect.minX)
        let newMinY = min(minY, rect.minY)
        let newMaxX = max(maxX, rect.maxX)
        let newMaxY = max(maxY, rect.maxY)
        
        return Rect(x: newMinX, y: newMinY, width: newMaxX - newMinX, height: newMaxY - newMinY)
    }
    
    /// Inset rectangle by edge insets
    public func inset(by insets: LoopEdgeInsets) -> Rect {
        return Rect(
            x: x + insets.left,
            y: y + insets.top,
            width: width - insets.horizontal,
            height: height - insets.vertical
        )
    }
}

/// Size structure for dimensions
public struct Size: Hashable, Codable {
    public var width: Float
    public var height: Float
    
    public init(width: Float = 0, height: Float = 0) {
        self.width = width
        self.height = height
    }
    
    /// Zero size constant
    public static let zero = Size(width: 0, height: 0)
}

/// Edge insets for padding, margin, borders
public struct LoopEdgeInsets: Hashable, Codable {
    public var top: Float
    public var left: Float
    public var bottom: Float
    public var right: Float
    
    public init(top: Float = 0, left: Float = 0, bottom: Float = 0, right: Float = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
    
    /// Zero insets constant
    public static let zero = LoopEdgeInsets()
    
    /// Total horizontal insets
    public var horizontal: Float {
        return left + right
    }
    
    /// Total vertical insets
    public var vertical: Float {
        return top + bottom
    }
}

// MARK: - Arithmetic Operations

extension Point {
    public static func + (lhs: Point, rhs: Point) -> Point {
        return Point(lhs.simd + rhs.simd)
    }
    
    public static func - (lhs: Point, rhs: Point) -> Point {
        return Point(lhs.simd - rhs.simd)
    }
    
    /// Distance between two points
    public func distance(to other: Point) -> Float {
        return simd_distance(simd, other.simd)
    }
}

extension Size {
    public static func + (lhs: Size, rhs: Size) -> Size {
        return Size(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}
