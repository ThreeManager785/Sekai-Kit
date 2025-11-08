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

import Foundation
internal import SwiftSyntax
internal import SwiftParser

public final class DoriStoryBuilder: Sendable {
    public init() {
        
    }
    
    public func buildIR(from code: String, diags: inout [Diagnostic]) -> Data? {
        let source = Parser.parse(source: code)
        
        let sema = SemaEvaluator([source])
        if let ir = StoryIR(evaluator: sema, diags: &diags) {
            print(ir._actions.map { "\($0)" }.joined(separator: "\n"))
            
            if !diags.hasError {
                return ir.binEncode()
            }
        }
        
        return nil
    }
}
