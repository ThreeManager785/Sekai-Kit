//===---*- Greatdori! -*---------------------------------------------------===//
//
// StoryBuilder.swift
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

@available(watchOS, unavailable)
public final class DoriStoryBuilder: Sendable {
    public let locale: _DoriAPI.Locale
    
    public init(for locale: _DoriAPI.Locale) {
        self.locale = locale
    }
    
    public func buildIR(from code: String, diags: inout [Diagnostic]) -> StoryIR? {
        let source = Parser.parse(source: code)
        
        let sema = SemaEvaluator([source], in: locale)
        if let ir = StoryIR(evaluator: sema, diags: &diags) {
            if !diags.hasError {
                return ir
            }
        }
        
        return nil
    }
    
    public func generateDiagnostics(for code: String) -> [Diagnostic] {
        let source = Parser.parse(source: code)
        
        var diags: [Diagnostic] = []
        
        let sema = SemaEvaluator([source], in: locale)
        _ = StoryIR(evaluator: sema, diags: &diags)
        
        return diags
    }
    
    public func syntaxHighlight(
        for attributedString: NSMutableAttributedString,
        config: SyntaxHighlightConfig = .init()
    ) {
        _highlightZeileCode(for: attributedString, config: config)
    }
    public func syntaxHighlight(
        code: String,
        config: SyntaxHighlightConfig = .init()
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: code)
        _highlightZeileCode(for: result, config: config)
        return .init(attributedString: result)
    }
    
    public func completeCode(
        _ code: String,
        at index: String.Index
    ) -> [CodeCompletionItem] {
        _completeZeileCode(code, at: index, in: locale)
    }
}

@available(watchOS, unavailable)
extension DoriStoryBuilder {
    public enum Conversion {
        public static func bestdoriJSON(fromIR ir: StoryIR) -> String? {
            let rawResult = IRConversion.convertToBestdori(ir)
            if let data = try? JSONSerialization.data(withJSONObject: rawResult) {
                return .init(data: data, encoding: .utf8)
            } else {
                return nil
            }
        }
        
        public static func zeileIR(
            fromBandori asset: _DoriAPI.Misc.StoryAsset,
            in locale: _DoriAPI.Locale,
            voiceBundlePath: String
        ) -> StoryIR {
            let ir = IRConversion.convertFromBandori(
                asset,
                in: locale,
                voiceBundlePath: voiceBundlePath
            )
            return ir
        }
        
        public static func plainText(fromIR ir: StoryIR) -> String {
            IRConversion.convertToPlainText(ir)
        }
    }
}
