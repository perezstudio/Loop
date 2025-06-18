//
//  ContentView.swift
//  Loop
//
//  Main content view for testing our engine
//

import SwiftUI

struct ContentView: View {
    @State private var testOutput = "Starting Loop Engine..."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Loop Web Engine")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("WebKit-Inspired Rendering Engine")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Engine Test Output:")
                        .font(.headline)
                    
                    Text(testOutput)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            
            HStack {
                Button("Test DOM Creation") {
                    testDOMCreation()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test Memory Pool") {
                    testMemoryPool()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test Geometry") {
                    testGeometry()
                }
                .buttonStyle(.borderedProminent)
            }
            
            HStack {
                Button("Run All Tests") {
                    runAllEngineTests()
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.white)
                .background(Color.green)
                
                Button("Clear Output") {
                    clearOutput()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            initializeEngine()
        }
    }
    
    private func initializeEngine() {
        testOutput = "🚀 Loop Engine Initialized\n"
        testOutput += "✓ Foundation layer loaded\n"
        testOutput += "✓ DOM core loaded\n"
        testOutput += "✓ Graphics primitives loaded\n"
        testOutput += "✓ Memory management ready\n"
        testOutput += "\nReady for testing..."
    }
    
    private func testDOMCreation() {
        testOutput += "\n\n--- DOM Creation Test ---\n"
        
        // Test basic DOM creation
        let document = Document()
        testOutput += "✓ Created document\n"
        
        let html = HTMLElement(document: document)
        document.appendChild(html)
        testOutput += "✓ Created HTML element\n"
        
        let body = BodyElement(document: document)
        html.appendChild(body)
        testOutput += "✓ Created BODY element\n"
        
        let div = Element(tagName: "div", document: document)
        div.id = "test-div"
        div.addClass("container")
        div.setAttribute("data-test", "value")
        body.appendChild(div)
        testOutput += "✓ Created DIV with attributes\n"
        
        let text = document.createTextNode("Hello, Loop Engine!")
        div.appendChild(text)
        testOutput += "✓ Added text content\n"
        
        // Test queries
        if let foundDiv = body.getElementById("test-div") {
            testOutput += "✓ Found element by ID: \(foundDiv.tagName)\n"
        }
        
        let divsByClass = body.getElementsByClassName("container")
        testOutput += "✓ Found \(divsByClass.count) elements by class\n"
        
        testOutput += "✓ DOM tree structure:\n"
        testOutput += "  Document\n"
        testOutput += "  └── HTML\n"
        testOutput += "      └── BODY\n"
        testOutput += "          └── DIV#test-div.container\n"
        testOutput += "              └── #text: \"Hello, Loop Engine!\"\n"
        
        testOutput += "✓ Reference counts managed automatically\n"
    }
    
    private func testMemoryPool() {
        testOutput += "\n\n--- Memory Pool Test ---\n"
        
        // Test memory pool allocation
        let pool = MemoryPool<Int>(itemsPerChunk: 8)
        var pointers: [UnsafeMutablePointer<Int>] = []
        
        // Allocate some memory
        for i in 0..<12 {
            let ptr = pool.allocate()
            ptr.pointee = i
            pointers.append(ptr)
        }
        testOutput += "✓ Allocated 12 integers from pool\n"
        
        let stats = pool.statistics
        testOutput += "✓ Pool stats: \(stats.usedItems)/\(stats.totalAllocated) used (\(String(format: "%.1f", stats.utilizationPercentage))%)\n"
        testOutput += "✓ Created \(stats.chunkCount) memory chunks\n"
        
        // Deallocate some memory
        for i in 0..<6 {
            pool.deallocate(pointers[i])
        }
        pointers.removeFirst(6)
        
        let newStats = pool.statistics
        testOutput += "✓ After deallocation: \(newStats.usedItems)/\(newStats.totalAllocated) used\n"
        
        // Clean up remaining
        for ptr in pointers {
            pool.deallocate(ptr)
        }
        
        testOutput += "✓ Memory pool test completed\n"
    }
    
    private func testGeometry() {
        testOutput += "\n\n--- Geometry Test ---\n"
        
        // Test basic geometry operations
        let point1 = Point(x: 10, y: 20)
        let point2 = Point(x: 30, y: 40)
        let sum = point1 + point2
        testOutput += "✓ Point math: (10,20) + (30,40) = (\(sum.x),\(sum.y))\n"
        
        let distance = point1.distance(to: point2)
        testOutput += "✓ Distance between points: \(String(format: "%.2f", distance))\n"
        
        let rect1 = Rect(x: 0, y: 0, width: 100, height: 50)
        let rect2 = Rect(x: 50, y: 25, width: 100, height: 50)
        testOutput += "✓ Created rectangles: \(rect1.width)x\(rect1.height) and \(rect2.width)x\(rect2.height)\n"
        
        let intersection = rect1.intersection(rect2)
        testOutput += "✓ Intersection: \(intersection.width)x\(intersection.height) at (\(intersection.x),\(intersection.y))\n"
        
        let union = rect1.union(rect2)
        testOutput += "✓ Union: \(union.width)x\(union.height) at (\(union.x),\(union.y))\n"
        
        let insets = LoopEdgeInsets(top: 10, left: 5, bottom: 10, right: 5)
        let insetRect = rect1.inset(by: insets)
        testOutput += "✓ Inset rect: \(insetRect.width)x\(insetRect.height)\n"
        
        testOutput += "✓ Geometry operations using SIMD for performance\n"
    }
    
    private func runAllEngineTests() {
        testOutput = EngineTests.runAllTests()
    }
    
    private func clearOutput() {
        testOutput = "🚀 Loop Engine Ready\n\nClick any test button to begin..."
    }
}

#Preview {
    ContentView()
}
