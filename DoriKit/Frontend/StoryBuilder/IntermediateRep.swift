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
        let e = IRGenEvaluator(self, semaResult: evaluator)
        e.emitSemaResult(diags: &irGenDiags)
        diags.append(contentsOf: irGenDiags)
    }
    
    internal func emitAction(_ action: StepAction) {
        _actions.append(action)
    }
    
    internal enum StepAction: Codable {
        case talk(
            String,
            characterIDs: [Int],
            characterNames: [String],
            voicePath: String?
        )
        case telop(String)
        case showModel(
            characterID: Int,
            modelPath: String,
            position: Position
        )
        case hideModel(characterID: Int)
        case moveModel(characterID: Int, position: Position)
        case act(characterID: Int, motionName: String)
        case express(characterID: Int, expressionName: String)
        case showBlackCover(duration: Double)
        case hideBlackCover(duration: Double)
        case showWhiteCover(duration: Double)
        case hideWhiteCover(duration: Double)
        case changeBackground(path: String)
        case changeBGM(path: String)
        case changeSE(path: String)
        
        case blocking([StepAction])
        case delay(seconds: Double)
        case forkTask([StepAction])
        case waitForAll
    }
}

extension StoryIR.StepAction {
    internal struct Position: Codable {
        internal var base: Base
        internal var offsetX: Double
        
        internal enum Base: Int, Codable {
            case leftOutside
            case left
            case leftInside
            case leftBottom
            case leftInsideBottom
            case center
            case rightOutside
            case right
            case rightInside
            case rightBottom
            case rightInsideBottom
        }
    }
}
