//===---*- Greatdori! -*---------------------------------------------------===//
//
// Symbolization.swift
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

internal final class ZeileSymbolizer {
    internal let semaEvaluator: SemaEvaluator
    
    internal init(semaResult evaluator: SemaEvaluator) {
        self.semaEvaluator = evaluator
    }
    
    internal func symbolizeAll() -> [String] {
        var result: [String] = []
        
        for (n, s) in semaEvaluator._resolvedStructs {
            for f in s.staticMethods {
                result.append(mangleFunction(f, parent: n, isStatic: true))
            }
            for m in s.instanceMethods {
                result.append(mangleFunction(m, parent: n, isStatic: false))
            }
            for i in s.initializers {
                result.append(mangleFunction(i, parent: n, isStatic: true))
            }
        }
        for f in semaEvaluator._resolvedTopFunctions {
            result.append(mangleFunction(f, parent: nil, isStatic: false))
        }
        
        return result
    }
}
