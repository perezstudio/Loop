//
//  EngineTests.swift
//  Loop
//
//  Simple tests for the Loop engine components
//

import Foundation

/// Simple test runner for Loop engine components
public struct EngineTests {
    
    public static func runAllTests() -> String {
        var output = "🧪 Running Loop Engine Tests\n"
        output += "============================\n\n"
        
        output += testGeometry()
        output += testMemoryPool()
        output += testDOM()
        
        output += "\n✅ All tests completed!\n"
        return output
    }
    
    private static func testGeometry() -> String {
        var output = "📐 Geometry Tests:\n"
        
        // Test Point operations
        let p1 = Point(x: 10, y: 20)
        let p2 = Point(x: 5, y: 15)
        let sum = p1 + p2
        
        assert(sum.x == 15 && sum.y == 35, "Point addition failed")
        output += "  ✓ Point arithmetic\n"
        
        let distance = p1.distance(to: p2)
        let expectedDistance = Float(sqrt(25.0 + 25.0))
        assert(abs(distance - expectedDistance) < 0.001, "Distance calculation failed")
        output += "  ✓ Distance calculation\n"
        
        // Test Rect operations
        let rect1 = Rect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = Rect(x: 50, y: 50, width: 100, height: 100)
        
        assert(rect1.intersects(rect2), "Intersection detection failed")
        output += "  ✓ Rectangle intersection\n"
        
        let intersection = rect1.intersection(rect2)
        assert(intersection.width == 50 && intersection.height == 50, "Intersection calculation failed")
        output += "  ✓ Rectangle intersection calculation\n"
        
        // Test EdgeInsets
        let insets = LoopEdgeInsets(top: 10, left: 5, bottom: 10, right: 5)
        assert(insets.horizontal == 10 && insets.vertical == 20, "EdgeInsets calculation failed")
        output += "  ✓ EdgeInsets calculations\n"
        
        output += "\n"
        return output
    }
    
    private static func testMemoryPool() -> String {
        var output = "🧠 Memory Pool Tests:\n"
        
        let pool = MemoryPool<Int>(itemsPerChunk: 4)
        var pointers: [UnsafeMutablePointer<Int>] = []
        
        // Allocate some items
        for i in 0..<6 {
            let ptr = pool.allocate()
            ptr.pointee = i
            pointers.append(ptr)
        }
        
        let stats = pool.statistics
        assert(stats.usedItems == 6, "Memory pool allocation failed")
        assert(stats.chunkCount == 2, "Memory pool chunk creation failed")
        output += "  ✓ Memory allocation\n"
        output += "  ✓ Pool statistics\n"
        
        // Deallocate some items
        pool.deallocate(pointers[0])
        pool.deallocate(pointers[1])
        
        let newStats = pool.statistics
        assert(newStats.usedItems == 4, "Memory pool deallocation failed")
        output += "  ✓ Memory deallocation\n"
        
        // Clean up remaining
        for i in 2..<6 {
            pool.deallocate(pointers[i])
        }
        
        output += "\n"
        return output
    }
    
    private static func testDOM() -> String {
        var output = "🌳 DOM Tests:\n"
        
        // Test basic DOM creation
        let document = Document()
        assert(document.nodeType == .document, "Document creation failed")
        output += "  ✓ Document creation\n"
        
        let element = Element(tagName: "div", document: document)
        assert(element.tagName == "DIV", "Element creation failed")
        assert(element.nodeType == .element, "Element type failed")
        output += "  ✓ Element creation\n"
        
        document.appendChild(element)
        assert(element.parentNode === document, "Parent relationship failed")
        output += "  ✓ DOM tree construction\n"
        
        // Test attributes
        element.setAttribute("id", "test-id")
        assert(element.getAttribute("id") == "test-id", "Attribute setting failed")
        assert(element.id == "test-id", "ID property failed")
        output += "  ✓ Attribute management\n"
        
        // Test classes
        element.addClass("class1")
        element.addClass("class2")
        assert(element.hasClass("class1"), "Class addition failed")
        assert(element.hasClass("class2"), "Class addition failed")
        output += "  ✓ Class management\n"
        
        element.removeClass("class1")
        assert(!element.hasClass("class1"), "Class removal failed")
        assert(element.hasClass("class2"), "Class removal affected wrong class")
        output += "  ✓ Class removal\n"
        
        // Test text nodes
        let textNode = document.createTextNode("Hello World")
        assert(textNode.nodeType == .text, "Text node creation failed")
        assert(textNode.textContent == "Hello World", "Text content failed")
        output += "  ✓ Text node creation\n"
        
        element.appendChild(textNode)
        assert(element.textContent == "Hello World", "Text content inheritance failed")
        output += "  ✓ Text content inheritance\n"
        
        // Test queries
        let html = HTMLElement(document: document)
        let body = BodyElement(document: document)
        
        html.appendChild(body)
        body.appendChild(element)
        
        let foundElement = body.getElementById("test-id")
        assert(foundElement === element, "getElementById failed")
        output += "  ✓ Element queries\n"
        
        let classList = body.getElementsByClassName("class2")
        assert(classList.count == 1 && classList[0] === element, "getElementsByClassName failed")
        output += "  ✓ Class queries\n"
        
        output += "\n"
        return output
    }
}
