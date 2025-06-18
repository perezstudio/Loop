//
//  NativeTypes.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import Foundation
import CoreGraphics
import CoreText
import SwiftUI

// MARK: - Native Font Weight

enum FontWeight {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
    
    func toSwiftUIWeight() -> Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

extension FontWeight: CustomStringConvertible {
    var description: String {
        switch self {
        case .ultraLight: return "ultraLight"
        case .thin: return "thin"
        case .light: return "light"
        case .regular: return "regular"
        case .medium: return "medium"
        case .semibold: return "semibold"
        case .bold: return "bold"
        case .heavy: return "heavy"
        case .black: return "black"
        }
    }
}

// MARK: - Color Extensions

extension Color {
    var nativeCGColor: CGColor {
        switch self {
        case .black: return CGColor.black
        case .white: return CGColor.white
        case .red: return CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        case .blue: return CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        case .green: return CGColor(red: 0, green: 1, blue: 0, alpha: 1)
        case .yellow: return CGColor(red: 1, green: 1, blue: 0, alpha: 1)
        case .orange: return CGColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        case .purple: return CGColor(red: 0.5, green: 0, blue: 0.5, alpha: 1)
        case .pink: return CGColor(red: 1, green: 0.75, blue: 0.8, alpha: 1)
        case .gray: return CGColor(gray: 0.5, alpha: 1)
        case .brown: return CGColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        case .cyan: return CGColor(red: 0, green: 1, blue: 1, alpha: 1)
        case .mint: return CGColor(red: 0, green: 1, blue: 0.8, alpha: 1)
        case .indigo: return CGColor(red: 0.3, green: 0, blue: 0.5, alpha: 1)
        case .teal: return CGColor(red: 0, green: 0.5, blue: 0.5, alpha: 1)
        case .primary: return CGColor.black
        case .secondary: return CGColor(gray: 0.6, alpha: 1)
        default: return CGColor.black
        }
    }
}

// MARK: - CSS Style Extensions

extension CSSStyle {
    var nativeCGColor: CGColor {
        return color?.nativeCGColor ?? CGColor.black
    }
}

// MARK: - CGColor Extensions

extension CGColor {
    var description: String {
        guard let components = self.components, components.count >= 3 else {
            return "CGColor(unknown)"
        }
        
        let red = components[0]
        let green = components[1]
        let blue = components[2]
        let alpha = components.count > 3 ? components[3] : 1.0
        
        return "CGColor(r: \(String(format: "%.2f", red)), g: \(String(format: "%.2f", green)), b: \(String(format: "%.2f", blue)), a: \(String(format: "%.2f", alpha)))"
    }
}
