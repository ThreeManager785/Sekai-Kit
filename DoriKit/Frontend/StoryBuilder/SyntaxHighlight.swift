//===---*- Greatdori! -*---------------------------------------------------===//
//
// SyntaxHighlight.swift
//
// This source file is part of the Greatdori! open source project
//
// Copyright (c) 2025 the Greatdori! project authors
// Licensed under Apache License v2.0
//
// See https://greatdori.com/LICENSE.txt for license information
// See https://greatdori.com/CONTRIBUTORS.txt for the list of Greatdori! project authors
//
//===----------------------------------------------------------------------===//

import SwiftUI
import Foundation
internal import SwiftSyntax
internal import SwiftParser
internal import SwiftIDEUtils

internal func _highlightZeileCode(
    for attributedString: NSMutableAttributedString,
    config: SyntaxHighlightConfig
) {
    let code = attributedString.string
    let source = Parser.parse(source: code)
    let classifications = source.classifications
    
    attributedString.removeAttribute(
        .foregroundColor,
        range: .init(location: 0, length: attributedString.length)
    )
    attributedString.addAttribute(
        .foregroundColor,
        value: config.colors.others.resolveUI(),
        range: .init(location: 0, length: attributedString.length)
    )
    
    for classification in classifications {
        let color = switch classification.kind {
        case .attribute: config.colors.attribute
        case .blockComment, .docBlockComment, .docLineComment, .lineComment:
            config.colors.comment
        case .dollarIdentifier, .identifier:
            config.colors.identifier
        case .editorPlaceholder: config.colors.editorPlaceholder
        case .floatLiteral: config.colors.floatLiteral
        case .integerLiteral: config.colors.integerLiteral
        case .keyword: config.colors.keyword
        case .operator: config.colors.operator
        case .stringLiteral: config.colors.stringLiteral
        case .type: config.colors.type
        case .argumentLabel: config.colors.argumentLabel
        default: config.colors.others
        }
        
        let sourceRange = classification.range
        let startIndex = code.utf8.index(
            code.utf8.startIndex,
            offsetBy: sourceRange.lowerBound.utf8Offset
        )
        let endIndex = code.utf8.index(
            code.utf8.startIndex,
            offsetBy: sourceRange.upperBound.utf8Offset
        )
        
        guard let start = String.Index(startIndex, within: code),
              let end = String.Index(endIndex, within: code) else {
            continue
        }
        
        let range = NSRange(start..<end, in: code)
        attributedString.addAttribute(
            .foregroundColor,
            value: color.resolveUI(),
            range: range
        )
    }
}

public struct SyntaxHighlightConfig {
    public var colors: ColorConfig = .init()
    
    public init() {}
    
    public struct ColorConfig {
        public var attribute: Color
        public var comment: Color
        public var editorPlaceholder: Color
        public var floatLiteral: Color
        public var identifier: Color
        public var integerLiteral: Color
        public var keyword: Color
        public var `operator`: Color
        public var stringLiteral: Color
        public var type: Color
        public var argumentLabel: Color
        public var others: Color
        
        public init() {
            self.attribute = .init("ZeileSyntaxHighlightAttribute", bundle: #bundle)
            self.comment = .init("ZeileSyntaxHighlightComment", bundle: #bundle)
            self.editorPlaceholder = .init("ZeileSyntaxHighlightEditorPlaceholder", bundle: #bundle)
            self.floatLiteral = .init("ZeileSyntaxHighlightFloatLiteral", bundle: #bundle)
            self.identifier = .init("ZeileSyntaxHighlightIdentifier", bundle: #bundle)
            self.integerLiteral = .init("ZeileSyntaxHighlightIntegerLiteral", bundle: #bundle)
            self.keyword = .init("ZeileSyntaxHighlightKeyword", bundle: #bundle)
            self.operator = .init("ZeileSyntaxHighlightOperator", bundle: #bundle)
            self.stringLiteral = .init("ZeileSyntaxHighlightStringLiteral", bundle: #bundle)
            self.type = .init("ZeileSyntaxHighlightType", bundle: #bundle)
            self.argumentLabel = .init("ZeileSyntaxHighlightArgumentLabel", bundle: #bundle)
            self.others = .init("ZeileSyntaxHighlightOther", bundle: #bundle)
        }
        
        public init(
            attribute: Color,
            comment: Color,
            editorPlaceholder: Color,
            floatLiteral: Color,
            identifier: Color,
            integerLiteral: Color,
            keyword: Color,
            operator: Color,
            stringLiteral: Color,
            type: Color,
            argumentLabel: Color,
            others: Color
        ) {
            self.attribute = attribute
            self.comment = comment
            self.editorPlaceholder = editorPlaceholder
            self.floatLiteral = floatLiteral
            self.identifier = identifier
            self.integerLiteral = integerLiteral
            self.keyword = keyword
            self.operator = `operator`
            self.stringLiteral = stringLiteral
            self.type = type
            self.argumentLabel = argumentLabel
            self.others = others
        }
    }
}

extension Color {
    #if os(macOS)
    fileprivate func resolveUI() -> NSColor {
        NSColor(self)
    }
    #else
    fileprivate func resolveUI() -> UIColor {
        UIColor(self)
    }
    #endif
}
