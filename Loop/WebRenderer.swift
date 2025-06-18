//
//  WebRenderer.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - DOM Structures

enum NodeType {
	case element(name: String, attributes: [String: String])
	case text(String)
}

class Node: Identifiable {
	var id = UUID()
	var type: NodeType
	var children: [Node]

	init(type: NodeType, children: [Node] = []) {
		self.type = type
		self.children = children
	}
}

extension Scanner {
	func scanQuotedString() -> String? {
		let currentPosition = currentIndex
		
		if scanString("\"") != nil {
			if let result = scanUpToString("\"") {
				_ = scanString("\"")
				return result
			} else {
				// No closing quote found, restore position
				currentIndex = currentPosition
				return nil
			}
		} else if scanString("'") != nil {
			if let result = scanUpToString("'") {
				_ = scanString("'")
				return result
			} else {
				// No closing quote found, restore position
				currentIndex = currentPosition
				return nil
			}
		}
		return nil
	}
}

// MARK: - HTML Parser

class HTMLParser {
	func parse(_ html: String) -> Node {
		// Clean up the HTML first
		var cleanHTML = html
		
		// Remove DOCTYPE declaration
		if let doctypeRange = cleanHTML.range(of: "<!doctype[^>]*>", options: [.regularExpression, .caseInsensitive]) {
			cleanHTML.removeSubrange(doctypeRange)
		}
		
		// Remove comments
		while let commentStart = cleanHTML.range(of: "<!--") {
			if let commentEnd = cleanHTML.range(of: "-->", range: commentStart.upperBound..<cleanHTML.endIndex) {
				cleanHTML.removeSubrange(commentStart.lowerBound..<commentEnd.upperBound)
			} else {
				break
			}
		}
		
		var index = cleanHTML.startIndex
		var stack: [Node] = []
		let root = Node(type: .element(name: "root", attributes: [:]))
		stack.append(root)

		while index < cleanHTML.endIndex {
			if cleanHTML[index] == "<" {
				if let endTag = cleanHTML[index...].firstIndex(of: ">") {
					let tagContent = String(cleanHTML[cleanHTML.index(after: index)..<endTag])
					index = cleanHTML.index(after: endTag)

					if tagContent.hasPrefix("/") {
						// Close tag
						if stack.count > 1 {
							_ = stack.popLast()
						}
					} else if !tagContent.isEmpty {
						var tagString = tagContent
						var isSelfClosing = false
						
						// Check for self-closing tags
						if tagString.hasSuffix("/") {
							isSelfClosing = true
							tagString = String(tagString.dropLast()).trimmingCharacters(in: .whitespaces)
						}
						
						// Check for known self-closing HTML tags
						let selfClosingTags = ["img", "br", "hr", "input", "meta", "link", "area", "base", "col", "embed", "source", "track", "wbr"]
						
						let scanner = Scanner(string: tagString)
						scanner.charactersToBeSkipped = CharacterSet.whitespaces
						
						guard let tagName = scanner.scanUpToCharacters(from: .whitespaces) ?? scanner.scanUpToString("") else {
							continue
						}
						
						// Check if this is a self-closing tag by nature
						if selfClosingTags.contains(tagName.lowercased()) {
							isSelfClosing = true
						}

						var attributes: [String: String] = [:]
						while !scanner.isAtEnd {
							scanner.scanCharacters(from: .whitespaces)
							if let key = scanner.scanUpToString("=")?.trimmingCharacters(in: .whitespaces), !key.isEmpty {
								if scanner.scanString("=") != nil {
									let value = scanner.scanQuotedString() ?? scanner.scanUpToCharacters(from: .whitespaces) ?? ""
									attributes[key] = value
								} else {
									// Boolean attribute
									attributes[key] = key
								}
							} else if let remainingKey = scanner.scanUpToString("")?.trimmingCharacters(in: .whitespaces), !remainingKey.isEmpty {
								// Boolean attribute at the end
								attributes[remainingKey] = remainingKey
								break
							} else {
								break
							}
						}

						let node = Node(type: .element(name: tagName, attributes: attributes))
						stack.last?.children.append(node)

						if !isSelfClosing {
							stack.append(node)
						}
					}
				} else {
					// Malformed tag, skip the '<'
					index = cleanHTML.index(after: index)
				}
			} else {
				// Text content
				var textEnd = index
				while textEnd < cleanHTML.endIndex, cleanHTML[textEnd] != "<" {
					textEnd = cleanHTML.index(after: textEnd)
				}
				
				let text = String(cleanHTML[index..<textEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
				if !text.isEmpty {
					let node = Node(type: .text(text))
					stack.last?.children.append(node)
				}
				index = textEnd
			}
		}

		return root
	}
}

// MARK: - Renderer View

struct WebRenderer: View {
	var urlString: String

	@State private var rootNode: Node?
	@State private var isLoading = true
	@State private var errorMessage: String?

	var body: some View {
		Group {
			if isLoading {
				ProgressView("Loading...")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if let errorMessage = errorMessage {
				VStack {
					Image(systemName: "exclamationmark.triangle")
						.font(.largeTitle)
						.foregroundColor(.orange)
					Text("Error Loading Page")
						.font(.headline)
					Text(errorMessage)
						.font(.caption)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.center)
				}
				.padding()
			} else if let rootNode = rootNode {
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 8) {
						if rootNode.children.isEmpty {
							Text("No content found in parsed HTML")
								.foregroundColor(.secondary)
								.padding()
						} else {
							render(node: rootNode)
						}
					}
					.padding()
				}
			} else {
				Text("No content to display - rootNode is nil")
					.foregroundColor(.secondary)
					.onAppear {
						print("DEBUG: rootNode is nil, isLoading: \(isLoading), errorMessage: \(errorMessage ?? "none")")
					}
			}
		}
		.task {
			await loadHTML()
		}
	}

	private func loadHTML() async {
		await MainActor.run {
			isLoading = true
			errorMessage = nil
		}
		
		print("Starting HTML load for:", urlString)

		guard let url = URL(string: urlString) else {
			await MainActor.run {
				errorMessage = "Invalid URL: \(urlString)"
				isLoading = false
			}
			return
		}

		do {
			print("Fetching data from URL...")
			let (data, response) = try await URLSession.shared.data(from: url)

			if let httpResponse = response as? HTTPURLResponse {
				print("Received HTTP status code:", httpResponse.statusCode)
				
				guard httpResponse.statusCode == 200 else {
					await MainActor.run {
						errorMessage = "HTTP Error: \(httpResponse.statusCode)"
						isLoading = false
					}
					return
				}
			}

			if let html = String(data: data, encoding: .utf8) {
				print("HTML fetched successfully. Length:", html.count)
				print("HTML Preview (first 500 chars):", String(html.prefix(500)))
				
				let parser = HTMLParser()
				let parsedNode = parser.parse(html)
				
				print("Parsed DOM structure:")
				printDOMStructure(parsedNode, indent: 0)
				
				// Find body content more reliably
				let bodyNode = findBodyNode(in: parsedNode)
				print("Body node found:", bodyNode != nil)
				
				// Use body if found, otherwise use the first significant element, or fall back to root
				var renderNode: Node
				if let body = bodyNode {
					renderNode = body
				} else if let firstSignificantChild = parsedNode.children.first(where: { child in
					if case .element(let name, _) = child.type {
						return !["head", "meta", "title", "script", "style"].contains(name.lowercased())
					}
					return true
				}) {
					renderNode = firstSignificantChild
				} else {
					renderNode = parsedNode
				}
				
				print("Final render node type:", renderNode.type)
				print("Final render node children count:", renderNode.children.count)
				
				await MainActor.run {
					rootNode = renderNode
					isLoading = false
				}
			} else {
				await MainActor.run {
					errorMessage = "Failed to decode HTML data"
					isLoading = false
				}
			}
		} catch {
			print("Failed to fetch HTML:", error)
			await MainActor.run {
				errorMessage = "Network error: \(error.localizedDescription)"
				isLoading = false
			}
		}
	}
	
	private func findBodyNode(in node: Node) -> Node? {
		// Try to find body tag
		if case .element(let name, _) = node.type, name.lowercased() == "body" {
			return node
		}
		
		// Recursively search children
		for child in node.children {
			if let found = findBodyNode(in: child) {
				return found
			}
		}
		
		return nil
	}
	
	private func printDOMStructure(_ node: Node, indent: Int) {
		let indentation = String(repeating: "  ", count: indent)
		switch node.type {
		case .element(let name, let attributes):
			print("\(indentation)<\(name)> (children: \(node.children.count))")
		case .text(let text):
			let preview = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50)
			print("\(indentation)TEXT: \"\(preview)\"")
		}
		
		// Only print first few levels to avoid spam
		if indent < 3 {
			for child in node.children {
				printDOMStructure(child, indent: indent + 1)
			}
		}
	}

	private func render(node: Node) -> AnyView {
		switch node.type {
		case .text(let text):
			let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmed.isEmpty {
				return AnyView(
					Text(trimmed)
						.fixedSize(horizontal: false, vertical: true)
				)
			} else {
				return AnyView(EmptyView())
			}
			
		case .element(let name, let attributes):
			switch name.lowercased() {
			case "p":
				return AnyView(
					VStack(alignment: .leading, spacing: 4) {
						ForEach(node.children) { child in
							render(node: child)
						}
					}
					.padding(.vertical, 4)
				)
				
			case "div", "section", "article", "main":
				return AnyView(
					VStack(alignment: .leading, spacing: 6) {
						ForEach(node.children) { child in
							render(node: child)
						}
					}
				)
				
			case "h1":
				return AnyView(heading(node, font: .largeTitle))
				
			case "h2":
				return AnyView(heading(node, font: .title))
				
			case "h3":
				return AnyView(heading(node, font: .title2))
				
			case "h4":
				return AnyView(heading(node, font: .title3))
				
			case "h5":
				return AnyView(heading(node, font: .headline))
				
			case "h6":
				return AnyView(heading(node, font: .subheadline))
				
			case "ul", "ol":
				return AnyView(
					VStack(alignment: .leading, spacing: 4) {
						ForEach(node.children) { child in
							render(node: child)
						}
					}
					.padding(.leading, 16)
				)
				
			case "li":
				return AnyView(
					HStack(alignment: .top, spacing: 8) {
						Text("•")
							.font(.system(size: 12))
						VStack(alignment: .leading, spacing: 2) {
							ForEach(node.children) { child in
								render(node: child)
							}
						}
					}
				)
				
			case "img":
				if let src = attributes["src"] {
					let imageURL = resolveImageURL(src, baseURL: urlString)
					if let url = URL(string: imageURL) {
						return AnyView(
							AsyncImage(url: url) { image in
								image
									.resizable()
									.aspectRatio(contentMode: .fit)
							} placeholder: {
								RoundedRectangle(cornerRadius: 8)
									.fill(Color.gray.opacity(0.3))
									.overlay(
										Image(systemName: "photo")
											.foregroundColor(.gray)
									)
							}
							.frame(maxWidth: 300, maxHeight: 200)
							.clipped()
						)
					}
				}
				return AnyView(EmptyView())
				
			case "a":
				if let href = attributes["href"] {
					return AnyView(
						Button(action: {
							print("Tapped link: \(href)")
						}) {
							HStack(spacing: 4) {
								ForEach(node.children) { child in
									render(node: child)
								}
							}
							.foregroundColor(.blue)
							.underline()
						}
						.buttonStyle(PlainButtonStyle())
					)
				} else {
					return AnyView(
						VStack(alignment: .leading) {
							ForEach(node.children) { child in
								render(node: child)
							}
						}
					)
				}
				
			case "br":
				return AnyView(
					Spacer()
						.frame(height: 8)
				)
				
			case "hr":
				return AnyView(
					Divider()
						.padding(.vertical, 8)
				)
				
			case "strong", "b":
				return AnyView(
					VStack(alignment: .leading) {
						ForEach(node.children) { child in
							render(node: child)
								.bold()
						}
					}
				)
				
			case "em", "i":
				return AnyView(
					VStack(alignment: .leading) {
						ForEach(node.children) { child in
							render(node: child)
								.italic()
						}
					}
				)
				
			case "span":
				return AnyView(
					HStack(spacing: 0) {
						ForEach(node.children) { child in
							render(node: child)
						}
					}
				)
				
			default:
				// Render children for unhandled tags
				return AnyView(
					VStack(alignment: .leading) {
						ForEach(node.children) { child in
							render(node: child)
						}
					}
				)
			}
		}
	}

	private func heading(_ node: Node, font: Font) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			ForEach(node.children) { child in
				switch child.type {
				case .text(let text):
					Text(text)
						.font(font)
						.bold()
						.fixedSize(horizontal: false, vertical: true)
				default:
					render(node: child)
						.font(font)
						.bold()
				}
			}
		}
		.padding(.vertical, 8)
	}
	
	private func resolveImageURL(_ src: String, baseURL: String) -> String {
		if src.hasPrefix("http://") || src.hasPrefix("https://") {
			return src
		} else if src.hasPrefix("//") {
			return "https:" + src
		} else if src.hasPrefix("/") {
			// Absolute path
			if let url = URL(string: baseURL),
			   let scheme = url.scheme,
			   let host = url.host {
				return "\(scheme)://\(host)\(src)"
			}
		} else {
			// Relative path
			if let url = URL(string: baseURL) {
				return url.appendingPathComponent(src).absoluteString
			}
		}
		return src
	}
}
