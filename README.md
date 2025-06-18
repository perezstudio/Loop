# Loop - WebKit-Inspired Rendering Engine

A high-performance web rendering engine built from scratch in Swift, inspired by WebKit's architecture and leveraging native macOS/iOS APIs.

## Overview

Loop is a modern web rendering engine designed to provide:

- **High Performance**: Built with Swift and low-level APIs like Metal, Core Text, and SIMD
- **Native Integration**: Seamless integration with macOS and iOS platforms
- **Standards Compliance**: Following W3C specifications for HTML, CSS, and JavaScript
- **Modular Architecture**: Clean separation between parsing, layout, rendering, and execution
- **Memory Efficiency**: Custom memory management and object pooling

## Architecture

The engine is organized into several key modules:

### Core Engine (`LoopEngine`)
- **Foundation**: Memory management, threading, data structures
- **DOM**: HTML document object model with full tree manipulation
- **Graphics**: Geometric primitives and rendering abstractions
- **Parser**: HTML5 and CSS3 parsing with proper error handling
- **Style**: CSS cascade, specificity, and computed style resolution
- **Layout**: Box model, flexbox, grid, and positioning algorithms
- **Rendering**: Paint operations and GPU-accelerated composition

### Browser UI (`LoopUI`)
- Web view components
- Navigation and tab management
- Developer tools integration
- Native scrolling and input handling

### Networking (`LoopNet`)
- HTTP/HTTPS resource loading
- Caching and compression
- Security policies (CORS, CSP)
- WebSocket support

### JavaScript Runtime (`LoopJS`)
- JavaScriptCore integration
- DOM API bindings
- Web API implementations
- Promise and async/await support

## Current Status

### ✅ Completed (Phase 1)
- [x] Core memory management system with object pooling
- [x] Reference counting for automatic memory management
- [x] High-performance geometric primitives using SIMD
- [x] Basic DOM node hierarchy with full tree manipulation
- [x] Element attribute and class management
- [x] HTML element registry and type checking

### 🚧 In Progress (Phase 2)
- [ ] HTML5 tokenizer and parser
- [ ] CSS lexer and parser
- [ ] Basic style computation and cascade
- [ ] Simple layout algorithms (block and inline)

### 📋 Planned (Future Phases)
- [ ] Advanced layout (flexbox, grid, positioning)
- [ ] Rendering pipeline with Metal acceleration
- [ ] JavaScript engine integration
- [ ] Network resource loading
- [ ] Browser UI components

## Building and Running

### Prerequisites
- Xcode 15.0 or later
- macOS 14.0 or later
- Swift 5.9 or later

### Building the Project

1. **Clone the repository**:
   ```bash
   cd /Users/keviruchis/Developer/Loop
   ```

2. **Open in Xcode**:
   ```bash
   open Loop.xcodeproj
   ```

3. **Build and run**:
   - Select the Loop target
   - Press Cmd+R to build and run

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter LoopEngineTests
```

### Swift Package Manager

You can also build using Swift Package Manager:

```bash
# Build all targets
swift build

# Build specific target
swift build --target LoopEngine

# Run tests
swift test
```

## Testing the Engine

The app includes several test functions to verify core functionality:

1. **DOM Creation Test**: Creates a basic DOM tree and tests manipulation
2. **Memory Pool Test**: Verifies custom memory allocation performance
3. **Geometry Test**: Tests SIMD-accelerated geometric operations

Click the test buttons in the app to see the engine in action.

## Performance Goals

- **Cold Start**: < 100ms to first paint
- **Memory Usage**: < 50MB for typical web pages
- **Scrolling**: 60fps smooth scrolling with GPU acceleration
- **JavaScript**: Performance competitive with V8/JavaScriptCore
- **Network**: Efficient resource loading with HTTP/2 support

## Development Guidelines

### Code Organization
- Use clear module boundaries between components
- Prefer composition over inheritance
- Keep hot paths allocation-free
- Use Swift's type system for safety

### Performance
- Profile early and often
- Use Instruments for memory and CPU analysis
- Optimize critical paths with SIMD and Metal
- Implement object pooling for frequently allocated objects

### Memory Management
- Use custom allocators where beneficial
- Implement reference counting for DOM nodes
- Avoid retain cycles with weak references
- Pool objects to reduce allocation overhead

### Testing
- Write unit tests for all core functionality
- Include performance benchmarks
- Test with real-world web content
- Verify memory leak prevention

## Contributing

This is currently a solo development project, but the architecture is designed to be:
- Modular and extensible
- Well-documented
- Test-driven
- Performance-focused

## License

This project is for educational and research purposes. The architecture draws inspiration from WebKit and other open-source browsers while implementing everything from scratch in Swift.

## Inspiration and References

- **WebKit**: Architecture and performance patterns
- **Chromium**: Rendering pipeline concepts
- **Servo**: Rust-based parallel rendering ideas
- **Swift**: Native integration and memory safety
- **Metal**: GPU-accelerated rendering
- **Core Text**: Advanced typography

## Development Roadmap

### Month 1: Foundation
- [x] Core infrastructure and memory management
- [x] DOM tree implementation
- [x] Basic geometric primitives
- [ ] HTML5 parsing basics

### Month 2: Parsing
- [ ] Complete HTML5 parser
- [ ] CSS parsing and tokenization
- [ ] Basic style computation
- [ ] Simple layout algorithms

### Month 3-4: Layout Engine
- [ ] Box model implementation
- [ ] Block and inline formatting
- [ ] Text layout with Core Text
- [ ] Positioning algorithms

### Month 5-6: Rendering
- [ ] Render tree construction
- [ ] Paint operations
- [ ] Metal-based composition
- [ ] Animation support

### Month 7-8: JavaScript
- [ ] JavaScriptCore integration
- [ ] DOM API bindings
- [ ] Event system
- [ ] Basic Web APIs

### Month 9-10: Networking
- [ ] HTTP resource loading
- [ ] Caching implementation
- [ ] Security policies
- [ ] WebSocket support

### Month 11-12: Browser Features
- [ ] Complete browser UI
- [ ] Developer tools
- [ ] Multi-tab support
- [ ] Extensions API

The goal is to create a production-quality rendering engine that demonstrates the power of Swift and native APIs for web technologies.
