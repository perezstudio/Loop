//
//  CascadeResolver.swift
//  Loop - WebCore Cascade Resolver
//
//  Created by Assistant on 6/17/25.
//

import Foundation

// MARK: - WebCore Cascade Resolver

class WebCoreCascadeResolver {
    func apply(_ declarations: [WebCore.Declaration], to style: inout ComputedStyle, origin: WebCore.StyleOrigin) {
        // Apply CSS declarations to computed style
        for declaration in declarations {
            applyDeclaration(declaration, to: &style)
        }
    }
    
    private func applyDeclaration(_ declaration: WebCore.Declaration, to style: inout ComputedStyle) {
        // Map CSS properties to computed style properties
        switch declaration.property.lowercased() {
        case "color":
            if case .color(let color) = declaration.value {
                style.color = color
            }
        case "background-color":
            if case .color(let color) = declaration.value {
                style.backgroundColor = color
            }
        case "font-size":
            if case .length(let value, let unit) = declaration.value {
                style.fontSize = .relative(value, unit == .px ? .em : .em)
            }
        case "display":
            if case .keyword(let value) = declaration.value {
                switch value.lowercased() {
                case "block": style.display = .block
                case "inline": style.display = .inline
                case "none": style.display = .none
                case "flex": style.display = .flex
                default: break
                }
            }
        default:
            break
        }
    }
}
