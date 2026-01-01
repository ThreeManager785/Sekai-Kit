//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendCalculator.swift
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
internal import os

extension DoriFrontend {
    public enum Calculator {
        public static func calculateEvent(_ input: EventCalculatorInput) -> EventCalculatorResult {
            let cpCostPossibleValues = [200, 400, 800, 1600]
            
            // Verify
            if input.eventType == .challengeLive {
                precondition(
                    input.currentChallengePoint != nil,
                    "'currentChallengePoint' is required for challenge events"
                )
                precondition(
                    input.eventPointsGainPerChallengePoint != nil,
                    "'eventPointsGainPerChallengePoint' is required for challenge events"
                )
                precondition(
                    input.challengePointCostPerGameplay != nil,
                    "'challengePointCostPerGameplay' is required for challenge events"
                )
                
                if !cpCostPossibleValues.contains(input.challengePointCostPerGameplay!) {
                    logger.fault("""
                    'challengePointCostPerGameplay' is \(input.challengePointCostPerGameplay!), \
                    but possible values are \(cpCostPossibleValues). \
                    This may cause incorrect results
                    """)
                }
            } else {
                if input.currentChallengePoint != nil {
                    logger.error("'currentChallengePoint' is only applicable for challenge events, this value will be ignored")
                }
                if input.eventPointsGainPerChallengePoint != nil {
                    logger.error("'eventPointsGainPerChallengePoint' is only applicable for challenge events, this value will be ignored")
                }
                if input.challengePointCostPerGameplay != nil {
                    logger.error("'challengePointCostPerGameplay' is only applicable for challenge events, this value will be ignored")
                }
            }
            
            var result = EventCalculatorResult(
                consumedFlames: input.naturalFlamesCount &+ input.otherFlamesCount,
                equivalentFlames: 0,
                eventPointsGainFromFlame: 0,
                totalEventPoints: 0,
                gameplayByFlamesCount: 0,
                gameplayByFlamesDuration: .zero
            )
            result.equivalentFlames = result.consumedFlames &+ Int(Double(input.zeroFlamesGameplayCount) * 0.2)
            result.eventPointsGainFromFlame = result.equivalentFlames &* input.eventPointsGainPerFlame
            result.gameplayByFlamesCount = result.consumedFlames / input.flameCostPerGameplay + input.zeroFlamesGameplayCount
            result.gameplayByFlamesDuration = input.gameplayDuration &* result.gameplayByFlamesCount
            
            if input.eventType == .challengeLive {
                result.totalChallengePoints = input.currentChallengePoint! &+ result.eventPointsGainFromFlame / 20
                
                result.gameplayByChallengePointsCount = 0
                
                // 'totalChallengePoints'-chan (CP-chan) falls from the biggest
                // possible value to the smallest, each value drain the biggest
                // multiple of themselves from CP-chan. Drained CPs become
                // 'usableCP', CP-chan remains 'remainingCP'.
                var usableCP = 0
                var remainingCP = result.totalChallengePoints!
                for value in cpCostPossibleValues.reversed() {
                    let (q, r) = remainingCP.quotientAndRemainder(dividingBy: value)
                    usableCP = value &* q
                    remainingCP = r
                    result.gameplayByChallengePointsCount! &+= q
                }
                result.eventPointsGainFromChallengePoints = usableCP * input.eventPointsGainPerChallengePoint!
                
                result.gameplayByChallengePointsDuration = input.gameplayDuration &* result.gameplayByChallengePointsCount!
            }
            
            result.totalEventPoints = input.currentEventPoint
            &+ result.eventPointsGainFromFlame
            &+ (result.eventPointsGainFromChallengePoints ?? 0)
            
            if let target = input.targetEventPoint {
                if result.totalEventPoints < target {
                    var diff = EventCalculatorResult.GoalResult.Difference(
                        eventPoint: target - result.totalEventPoints,
                        flame: 0,
                        gameplayWithFlame: 0,
                        gameTimeWithFlame: .zero,
                        gameplayWithoutFlame: 0,
                        gameTimeWithoutFlame: .zero
                    )
                    diff.flame = Int(ceil(Double(diff.eventPoint) / Double(input.eventPointsGainPerFlame)))
                    diff.gameplayWithFlame = Int(ceil(Double(diff.flame) / Double(input.flameCostPerGameplay)))
                    diff.gameTimeWithFlame = input.gameplayDuration &* diff.gameplayWithFlame
                    diff.gameplayWithoutFlame = Int(ceil(Double(diff.flame) / 0.2 / Double(input.flameCostPerGameplay)))
                    diff.gameTimeWithoutFlame = input.gameplayDuration &* diff.gameplayWithoutFlame
                    result.goal = .notReached(difference: diff)
                } else {
                    result.goal = .reached
                }
            }
            
            return result
        }
    }
}

extension DoriFrontend.Calculator {
    public struct EventCalculatorInput: Sendable, Hashable {
        public var eventType: DoriAPI.Events.EventType
        public var currentEventPoint: Int
        public var currentChallengePoint: Int?
        public var targetEventPoint: Int?
        
        public var eventPointsGainPerFlame: Int
        public var eventPointsGainPerChallengePoint: Int?
        
        public var naturalFlamesCount: Int
        public var otherFlamesCount: Int
        public var zeroFlamesGameplayCount: Int
        
        public var flameCostPerGameplay: Int
        public var challengePointCostPerGameplay: Int?
        public var gameplayDuration: Duration
        
        public init(
            eventType: DoriAPI.Events.EventType,
            currentEventPoint: Int,
            currentChallengePoint: Int? = nil,
            targetEventPoint: Int? = nil,
            eventPointsGainPerFlame: Int,
            eventPointsGainPerChallengePoint: Int? = nil,
            naturalFlamesCount: Int,
            otherFlamesCount: Int,
            zeroFlamesGameplayCount: Int,
            flameCostPerGameplay: Int,
            challengePointCostPerGameplay: Int? = nil,
            gameplayDuration: Duration
        ) {
            self.eventType = eventType
            self.currentEventPoint = currentEventPoint
            self.currentChallengePoint = currentChallengePoint
            self.targetEventPoint = targetEventPoint
            self.eventPointsGainPerFlame = eventPointsGainPerFlame
            self.eventPointsGainPerChallengePoint = eventPointsGainPerChallengePoint
            self.naturalFlamesCount = naturalFlamesCount
            self.otherFlamesCount = otherFlamesCount
            self.zeroFlamesGameplayCount = zeroFlamesGameplayCount
            self.flameCostPerGameplay = flameCostPerGameplay
            self.challengePointCostPerGameplay = challengePointCostPerGameplay
            self.gameplayDuration = gameplayDuration
        }
    }
    
    public struct EventCalculatorResult: Sendable, Hashable {
        public var goal: GoalResult?
        public var consumedFlames: Int
        public var equivalentFlames: Int
        public var eventPointsGainFromFlame: Int
        public var totalEventPoints: Int
        public var totalChallengePoints: Int?
        public var eventPointsGainFromChallengePoints: Int?
        public var gameplayByFlamesCount: Int
        public var gameplayByFlamesDuration: Duration
        public var gameplayByChallengePointsCount: Int?
        public var gameplayByChallengePointsDuration: Duration?
        
        @inlinable
        public var totalGameplayCount: Int {
            gameplayByFlamesCount &+ (gameplayByChallengePointsCount ?? 0)
        }
        @inlinable
        public var totalGameplayDuration: Duration {
            gameplayByFlamesDuration &+ (gameplayByChallengePointsDuration ?? .zero)
        }
        
        public enum GoalResult: Sendable, Hashable {
            case reached
            case notReached(difference: Difference)
            
            public struct Difference: Sendable, Hashable {
                public var eventPoint: Int
                public var flame: Int
                public var gameplayWithFlame: Int
                public var gameTimeWithFlame: Duration
                public var gameplayWithoutFlame: Int
                public var gameTimeWithoutFlame: Duration
            }
        }
    }
}
