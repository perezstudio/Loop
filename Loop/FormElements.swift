//
//  FormElements.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - Form Element Renderer (Basic Version)

struct FormElementRenderer {
    
    @ViewBuilder
    static func renderInput(_ node: DOMNode) -> some View {
        let type = node.getAttribute("type")?.lowercased() ?? "text"
        let placeholder = node.getAttribute("placeholder") ?? ""
        let value = node.getAttribute("value") ?? ""
        
        switch type {
        case "text", "email", "url", "search":
            TextField(placeholder, text: .constant(value))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case "password":
            SecureField(placeholder, text: .constant(value))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case "checkbox":
            Button(action: {}) {
                Image(systemName: "square")
                    .foregroundColor(.gray)
            }
        default:
            TextField(placeholder, text: .constant(value))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    @ViewBuilder
    static func renderTextarea(_ node: DOMNode) -> some View {
        let placeholder = node.getAttribute("placeholder") ?? ""
        
        TextEditor(text: .constant(""))
            .frame(minHeight: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    static func renderSelect(_ node: DOMNode) -> some View {
        Menu("Select...") {
            Button("Option 1") { }
            Button("Option 2") { }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    static func renderButton(_ node: DOMNode) -> some View {
        let buttonText = node.getAllTextContent().isEmpty ? "Button" : node.getAllTextContent()
        
        Button(action: {
            print("Button clicked: \(buttonText)")
        }) {
            Text(buttonText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
