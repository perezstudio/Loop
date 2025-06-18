//
//  LoopEngineTests.swift
//  
//  Core engine tests for DOM, memory management, and geometry
//

import XCTest
@testable import LoopEngine

final class LoopEngineTests: XCTestCase {
    
    func testDOMCreation() {
        // Test basic DOM node creation
        let document = Document()
        XCTAssertEqual(document.nodeType, .document)
        XCTAssertTrue(document.isConnected)
        
        let element = Element(tagName: "div", document: document)
        XCTAssertEqual(element.tagName, "DIV")
        XCTAssertEqual(element.nodeType, .element)
        XCTAssertFalse(element.isConnected)
        
        document.appendChild(element)
        XCTAssertTrue(element.isConnected)
        XCTAssertEqual(element.parentNode, document)
    }
    
    func testElementAttributes() {
        let document = Document()
        let element = Element(tagName: "div", document: document)
        
        // Test attribute setting
        element.setAttribute("id", "test-id")
        XCTAssertEqual(element.getAttribute("id"), "test-id")
        XCTAssertEqual(element.id, "test-id")
        
        // Test class management
        element.addClass("class1")
        element.addClass("class2")
        XCTAssertTrue(element.hasClass("class1"))
        XCTAssertTrue(element.hasClass("class2"))
        XCTAssertEqual(element.className, "class1 class2")
        
        element.removeClass("class1")
        XCTAssertFalse(element.hasClass("class1"))
        XCTAssertTrue(element.hasClass("class2"))
    }
    
    func testTextNodes() {
        let document = Document()
        let textNode = document.createTextNode("Hello World")
        
        XCTAssertEqual(textNode.nodeType, .text)
        XCTAssertEqual(textNode.textContent, "Hello World")
        XCTAssertEqual(textNode.nodeValue, "Hello World")
    }
    
    func testDOMTreeTraversal() {
        let document = Document()
        let html = HTMLElement(document: document)
        let body = BodyElement(document: document)
        let div1 = Element(tagName: "div", document: document)
        let div2 = Element(tagName: "div", document: document)
        
        document.appendChild(html)
        html.appendChild(body)
        body.appendChild(div1)
        body.appendChild(div2)
        
        // Test child relationships
        XCTAssertEqual(body.childElementCount, 2)
        XCTAssertEqual(body.firstElementChild, div1)
        XCTAssertEqual(body.lastElementChild, div2)
        
        // Test sibling relationships
        XCTAssertEqual(div1.nextElementSibling, div2)
        XCTAssertEqual(div2.previousElementSibling, div1)
        
        // Test queries
        let divs = body.getElementsByTagName("div")
        XCTAssertEqual(divs.count, 2)
    }
    
    func testMemoryPool() {
        let pool = MemoryPool<Int>(itemsPerChunk: 4)
        
        // Allocate some items
        var pointers: [UnsafeMutablePointer<Int>] = []
        for i in 0..<6 {
            let ptr = pool.allocate()
            ptr.pointee = i
            pointers.append(ptr)
        }
        
        let stats = pool.statistics
        XCTAssertEqual(stats.usedItems, 6)
        XCTAssertEqual(stats.chunkCount, 2) // Should have created 2 chunks
        
        // Deallocate some items
        pool.deallocate(pointers[0])
        pool.deallocate(pointers[1])
        
        let newStats = pool.statistics
        XCTAssertEqual(newStats.usedItems, 4)
        
        // Clean up
        for i in 2..<6 {
            pool.deallocate(pointers[i])
        }
    }
    
    func testGeometryOperations() {
        // Test Point operations
        let p1 = Point(x: 10, y: 20)
        let p2 = Point(x: 5, y: 15)
        let sum = p1 + p2
        
        XCTAssertEqual(sum.x, 15)
        XCTAssertEqual(sum.y, 35)
        
        let distance = p1.distance(to: p2)
        XCTAssertEqual(distance, sqrt(25 + 25), accuracy: 0.001)
        
        // Test Rect operations
        let rect1 = Rect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = Rect(x: 50, y: 50, width: 100, height: 100)
        
        XCTAssertTrue(rect1.intersects(rect2))
        
        let intersection = rect1.intersection(rect2)
        XCTAssertEqual(intersection.x, 50)
        XCTAssertEqual(intersection.y, 50)
        XCTAssertEqual(intersection.width, 50)
        XCTAssertEqual(intersection.height, 50)
        
        let union = rect1.union(rect2)
        XCTAssertEqual(union.x, 0)
        XCTAssertEqual(union.y, 0)
        XCTAssertEqual(union.width, 150)
        XCTAssertEqual(union.height, 150)
    }
    
    func testRefCounting() {
        let document = Document()
        var element: Element? = Element(tagName: "div", document: document)
        
        // Element should have ref count of 1
        XCTAssertEqual(element?.referenceCount, 1)
        
        // Adding to DOM should increase ref count
        document.appendChild(element!)
        XCTAssertEqual(element?.referenceCount, 2)
        
        // Create a reference
        let ref = makeRef(element!)
        XCTAssertEqual(element?.referenceCount, 3)
        
        // Clear local reference
        element = nil
        XCTAssertEqual(ref.get.referenceCount, 2)
        
        // Remove from DOM
        ref.get.remove()
        XCTAssertEqual(ref.get.referenceCount, 1)
        
        // Ref should still be valid
        XCTAssertTrue(ref.isValid)
    }
    
    func testEdgeInsets() {
        let insets = EdgeInsets(top: 10, left: 5, bottom: 15, right: 20)
        
        XCTAssertEqual(insets.horizontal, 25)
        XCTAssertEqual(insets.vertical, 25)
        
        let rect = Rect(x: 0, y: 0, width: 100, height: 100)
        let insetRect = rect.inset(by: insets)
        
        XCTAssertEqual(insetRect.x, 5)
        XCTAssertEqual(insetRect.y, 10)
        XCTAssertEqual(insetRect.width, 75)
        XCTAssertEqual(insetRect.height, 75)
    }
    
    func testHTMLElementTypes() {
        XCTAssertTrue(HTMLElements.isHTMLElement("div"))
        XCTAssertTrue(HTMLElements.isHTMLElement("DIV"))
        XCTAssertFalse(HTMLElements.isHTMLElement("custom-element"))
        
        XCTAssertTrue(HTMLElements.isBlockElement("div"))
        XCTAssertTrue(HTMLElements.isInlineElement("span"))
        XCTAssertTrue(HTMLElements.isVoidElement("br"))
        XCTAssertFalse(HTMLElements.isVoidElement("div"))
    }
}
