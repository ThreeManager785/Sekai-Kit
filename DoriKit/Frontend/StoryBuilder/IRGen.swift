//===---*- Greatdori! -*---------------------------------------------------===//
//
// IRGen.swift
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

internal import SwiftSyntax

internal final class IRGenEvaluator {
    internal var ir: StoryIR
    
    internal init(_ ir: StoryIR) {
        self.ir = ir
    }
    
    internal func emitSemaResult(_ evaluator: SemaEvaluator, diags: inout [Diagnostic]) {
        
    }
}
