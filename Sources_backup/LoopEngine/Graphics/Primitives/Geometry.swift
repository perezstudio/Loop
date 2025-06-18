//
//  Geometry.swift
//  LoopEngine
//
//  Core geometric primitives for layout and rendering
//  Uses SIMD for performance where applicable
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
    
    /// Unit point constants
    public static let unitX = Point(x: 1, y: 0)
    public static let unitY = Point(x: 0, y: 1)
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
    
    public var center: Point {
        return Point(x: midX, y: midY)
    }
    
    /// Zero rect constant
    public static let zero = Rect(origin: .zero, size: .zero)
    
    /// Check if rect is empty
    public var isEmpty: Bool {
        return size.width <= 0 || size.height <= 0
    }
    
    /// Check if rect is finite (no NaN or infinite values)
    public var isFinite: Bool {
        return origin.x.isFinite && origin.y.isFinite && 
               size.width.isFinite && size.height.isFinite
    }
    
    /// Area of the rectangle
    public var area: Float {
        return size.width * size.height
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
    
    public init(_ vector: simd_float2) {
        self.width = vector.x
        self.height = vector.y
    }
    
    /// Convert to SIMD vector
    public var simd: simd_float2 {
        return simd_float2(width, height)
    }
    
    /// Zero size constant
    public static let zero = Size(width: 0, height: 0)
    
    /// Check if size is empty
    public var isEmpty: Bool {
        return width <= 0 || height <= 0
    }
    
    /// Check if size is finite
    public var isFinite: Bool {
        return width.isFinite && height.isFinite
    }
    
    /// Area of the size
    public var area: Float {
        return width * height
    }
}

/// Edge insets for padding, margin, borders
public struct EdgeInsets: Hashable, Codable {
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
    
    public init(all: Float) {
        self.top = all
        self.left = all
        self.bottom = all
        self.right = all
    }
    
    public init(horizontal: Float, vertical: Float) {
        self.top = vertical
        self.left = horizontal
        self.bottom = vertical
        self.right = horizontal
    }
    
    /// Zero insets constant
    public static let zero = EdgeInsets()
    
    /// Total horizontal insets
    public var horizontal: Float {
        return left + right
    }
    
    /// Total vertical insets
    public var vertical: Float {
        return top + bottom
    }
    
    /// Convert to size (horizontal, vertical)
    public var size: Size {
        return Size(width: horizontal, height: vertical)
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
    
    public static func * (lhs: Point, rhs: Float) -> Point {
        return Point(lhs.simd * rhs)
    }
    
    public static func / (lhs: Point, rhs: Float) -> Point {
        return Point(lhs.simd / rhs)
    }
    
    public static func += (lhs: inout Point, rhs: Point) {
        lhs = lhs + rhs
    }
    
    public static func -= (lhs: inout Point, rhs: Point) {
        lhs = lhs - rhs
    }
    
    /// Distance between two points
    public func distance(to other: Point) -> Float {
        return simd_distance(simd, other.simd)
    }
}

extension Size {
    public static func + (lhs: Size, rhs: Size) -> Size {
        return Size(lhs.simd + rhs.simd)
    }
    
    public static func - (lhs: Size, rhs: Size) -> Size {
        return Size(lhs.simd - rhs.simd)
    }
    
    public static func * (lhs: Size, rhs: Float) -> Size {
        return Size(lhs.simd * rhs)
    }
    
    public static func / (lhs: Size, rhs: Float) -> Size {
        return Size(lhs.simd / rhs)
    }
    
    public static func += (lhs: inout Size, rhs: Size) {
        lhs = lhs + rhs
    }
    
    public static func -= (lhs: inout Size, rhs: Size) {
        lhs = lhs - rhs
    }
}

extension Rect {
    /// Create rect from two points
    public init(from point1: Point, to point2: Point) {
        let minX = min(point1.x, point2.x)
        let minY = min(point1.y, point2.y)
        let maxX = max(point1.x, point2.x)
        let maxY = max(point1.y, point2.y)
        
        self.init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// Check if point is inside rectangle
    public func contains(_ point: Point) -> Bool {
        return point.x >= minX && point.x <= maxX &&
               point.y >= minY && point.y <= maxY
    }
    
    /// Check if rectangle contains another rectangle
    public func contains(_ rect: Rect) -> Bool {
        return rect.minX >= minX && rect.maxX <= maxX &&
               rect.minY >= minY && rect.maxY <= maxY
    }
    
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
        if isEmpty { return rect }
        if rect.isEmpty { return self }
        
        let newMinX = min(minX, rect.minX)
        let newMinY = min(minY, rect.minY)
        let newMaxX = max(maxX, rect.maxX)
        let newMaxY = max(maxY, rect.maxY)
        
        return Rect(x: newMinX, y: newMinY, width: newMaxX - newMinX, height: newMaxY - newMinY)
    }
    
    /// Inset rectangle by edge insets
    public func inset(by insets: EdgeInsets) -> Rect {
        return Rect(
            x: x + insets.left,
            y: y + insets.top,
            width: width - insets.horizontal,
            height: height - insets.vertical
        )
    }
    
    /// Outset rectangle by edge insets
    public func outset(by insets: EdgeInsets) -> Rect {
        return Rect(
            x: x - insets.left,
            y: y - insets.top,
            width: width + insets.horizontal,
            height: height + insets.vertical
        )
    }
    
    /// Offset rectangle by point
    public func offset(by point: Point) -> Rect {
        return Rect(origin: origin + point, size: size)
    }
}

// MARK: - Extensions for Foundation Interop

#if canImport(CoreGraphics)
import CoreGraphics

extension Point {
    public init(_ cgPoint: CGPoint) {
        self.x = Float(cgPoint.x)
        self.y = Float(cgPoint.y)
    }
    
    public var cgPoint: CGPoint {
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

extension Size {
    public init(_ cgSize: CGSize) {
        self.width = Float(cgSize.width)
        self.height = Float(cgSize.height)
    }
    
    public var cgSize: CGSize {
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }
}

extension Rect {
    public init(_ cgRect: CGRect) {
        self.origin = Point(cgRect.origin)
        self.size = Size(cgRect.size)
    }
    
    public var cgRect: CGRect {
        return CGRect(origin: origin.cgPoint, size: size.cgSize)
    }
}
#endif
