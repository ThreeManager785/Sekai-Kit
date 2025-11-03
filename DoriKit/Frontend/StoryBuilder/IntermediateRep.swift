//===---*- Greatdori! -*---------------------------------------------------===//
//
// IntermediateRep.swift
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

internal final class StoryIR {
    internal var _actions: [StepAction] = []
    
    internal init?(evaluator: SemaEvaluator, diags: inout [Diagnostic]) {
        let semaDiags = evaluator.performSema()
        diags = semaDiags
        if semaDiags.hasError {
            return nil
        }
        
        var irGenDiags: [Diagnostic] = []
        let e = IRGenEvaluator(self)
        e.emitSemaResult(evaluator, diags: &irGenDiags)
        diags.append(contentsOf: irGenDiags)
    }
    
    internal enum StepAction {
        
    }
}
