//
//  CSSTypes.swift
//  Loop - CSS Type Aliases for WebCore Integration
//
//  Created by Assistant on 6/17/25.
//

import Foundation
import CoreGraphics

// MARK: - This file provides type aliases for WebCore CSS types
// All actual type definitions are in WebCoreTypes.swift

// These aliases allow existing code to use familiar CSS type names
// while actually using the new WebCore namespace types

// MARK: - CSS Parse Errors

enum CSSParseError: Error {
    case invalidRule(String)
    case invalidDeclaration(String)
    case invalidValue(String)
    case unexpectedCharacter(Character)
}
