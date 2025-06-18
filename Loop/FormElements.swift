//
//  FormElements.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - Minimal Form Element Renderer

struct FormElementRenderer {
    
    static func renderInput(_ node: Any) -> AnyView {
        return AnyView(
            TextField("Input", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        )
    }
    
    static func renderTextarea(_ node: Any) -> AnyView {
        return AnyView(
            TextEditor(text: .constant(""))
                .frame(minHeight: 80)
        )
    }
    
    static func renderSelect(_ node: Any) -> AnyView {
        return AnyView(
            Text("Select")
                .padding()
        )
    }
    
    static func renderButton(_ node: Any) -> AnyView {
        return AnyView(
            Button("Button") {
                print("Button clicked")
            }
        )
    }
}
