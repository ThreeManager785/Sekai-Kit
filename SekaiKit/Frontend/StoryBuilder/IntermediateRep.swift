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

public final class StoryIR {
    public internal(set) var locale: SekaiAPI.Locale
    public internal(set) var actions: [StepAction] = []
    
    internal init(locale: SekaiAPI.Locale, actions: [StepAction]) {
        self.locale = locale
        self.actions = actions
    }
    
    internal init?(evaluator: SemaEvaluator, diags: inout [Diagnostic]) {
        self.locale = evaluator.locale
        
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
        actions.append(action)
    }
    
    public enum StepAction: Sendable, Codable {
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
        case horizontalShake(characterID: Int)
        case verticalShake(characterID: Int)
        
        case showBlackCover(duration: Double)
        case hideBlackCover(duration: Double)
        case showWhiteCover(duration: Double)
        case hideWhiteCover(duration: Double)
        case shakeScreen(duration: Double)
        case shakeDialogBox(duration: Double)
        
        case changeBackground(path: String)
        case changeBGM(path: String)
        case changeSE(path: String)
        
        case blocking([StepAction])
        case delay(seconds: Double)
        case forkTask([StepAction])
        case waitForTap
        case waitForAll
    }
}

extension StoryIR.StepAction {
    public struct Position: Sendable, Hashable, Codable {
        public var base: Base
        public var offsetX: Double
        
        public enum Base: Int, Sendable, Hashable, Codable {
            case leftOutside
            case left
            case leftInside
            case leftBottom
            case leftInsideBottom
            case center
            case centerBottom
            case rightOutside
            case right
            case rightInside
            case rightBottom
            case rightInsideBottom
        }
    }
}
