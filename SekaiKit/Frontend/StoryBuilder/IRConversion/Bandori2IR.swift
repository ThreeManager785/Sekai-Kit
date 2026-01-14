//===---*- Greatdori! -*---------------------------------------------------===//
//
// Bandori2IR.swift
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

extension IRConversion {
    internal static func convertFromBandori(
        _ asset: SekaiAPI.Misc.StoryAsset,
        in locale: SekaiAPI.Locale,
        voiceBundlePath: String
    ) -> StoryIR {
        let bgmBasePath = "\(locale.rawValue)/sound/scenario/bgm/"
        
        let ir = StoryIR(locale: locale, actions: [])
        
        ir.emitAction(.changeBGM(path: "\(bgmBasePath)/\(asset.firstBGM.lowercased())/\(asset.firstBGM).mp3"))
        ir.emitAction(.changeBackground(path: "\(locale.rawValue)/\(asset.firstBackgroundBundleName)/\(asset.firstBackground).png"))
        
        func actions(
            at index: Int,
            in snippets: [SekaiAPI.Misc.StoryAsset.Snippet]
        ) -> [StoryIR.StepAction] {
            let snippet = snippets[index]
            
            var result: [StoryIR.StepAction] = []
            
            if snippet.progressType == 1 {
                result.append(.waitForAll)
            }
            
            switch snippet.actionType {
            case .none:
                break
            case .talk:
                let talkData = asset.talkData[snippet.referenceIndex]
                var voicePath: String?
                if let id = talkData.voices.first?.voiceID {
                    voicePath = "\(voiceBundlePath)/\(id).mp3"
                }
                result.append(.talk(
                    talkData.body,
                    characterIDs: talkData.talkCharacters.map { $0.characterID },
                    characterNames: [talkData.windowDisplayName],
                    voicePath: voicePath
                ))
                
                for motion in talkData.motions {
                    if !motion.motionName.isEmpty {
                        result.append(.act(
                            characterID: motion.characterID,
                            motionName: motion.motionName
                        ))
                    }
                    if !motion.expressionName.isEmpty {
                        result.append(.express(
                            characterID: motion.characterID,
                            expressionName: motion.expressionName
                        ))
                    }
                }
            case .layout, .motion:
                let layoutData = asset.layoutData[snippet.referenceIndex]
                
                if snippet.actionType == .layout {
                    switch layoutData.type {
                    case .none:
                        break
                    case .move:
                        result.append(.moveModel(
                            characterID: layoutData.characterID,
                            position: .init(
                                base: .init(bandori: layoutData.sideTo),
                                offsetX: Double(layoutData.sideToOffsetX)
                            )
                        ))
                    case .appear:
                        var modelName = ""
                        if !layoutData.costumeType.isEmpty {
                            modelName = layoutData.costumeType
                        } else {
                            // Some layout actions omit the costume name
                            // if the same costume has presented previously.
                            // We have to find it out
                            for data in asset.layoutData[...snippet.referenceIndex].reversed() {
                                if data.characterID == layoutData.characterID
                                    && !data.costumeType.isEmpty {
                                    modelName = data.costumeType
                                    break
                                }
                            }
                            
                            if modelName.isEmpty {
                                logger.fault("""
                                Live2D model path for character \
                                \(layoutData.characterID) has never defined. \
                                This causes undefined behaviors
                                """)
                            }
                        }
                        
                        var hasAppeared = false
                        if snippet.referenceIndex > 0 {
                            for data in asset.layoutData[..<snippet.referenceIndex].reversed() {
                                if data.characterID == layoutData.characterID {
                                    if data.type == .hide {
                                        break
                                    } else if data.type == .appear || data.type == .move {
                                        hasAppeared = true
                                    }
                                }
                            }
                        }
                        
                        if !hasAppeared {
                            result.append(.showModel(
                                characterID: layoutData.characterID,
                                modelPath: "\(locale.rawValue)/live2d/chara/\(modelName)",
                                position: .init(
                                    base: .init(bandori: layoutData.sideTo),
                                    offsetX: Double(layoutData.sideToOffsetX)
                                )
                            ))
                        } else {
                            result.append(.moveModel(
                                characterID: layoutData.characterID,
                                position: .init(
                                    base: .init(bandori: layoutData.sideTo),
                                    offsetX: Double(layoutData.sideToOffsetX)
                                )
                            ))
                        }
                    case .hide:
                        result.append(.hideModel(characterID: layoutData.characterID))
                    case .shakeX:
                        result.append(.horizontalShake(characterID: layoutData.characterID))
                    case .shakeY:
                        result.append(.verticalShake(characterID: layoutData.characterID))
                    }
                }
                
                if layoutData.type != .hide || snippet.actionType == .motion {
                    if !layoutData.motionName.isEmpty {
                        result.append(.act(
                            characterID: layoutData.characterID,
                            motionName: layoutData.motionName
                        ))
                    }
                    if !layoutData.expressionName.isEmpty {
                        result.append(.express(
                            characterID: layoutData.characterID,
                            expressionName: layoutData.expressionName
                        ))
                    }
                }
            case .input:
                logger.error("The 'input' action is not supported in the Zeile IR. Skipping")
            case .selectable:
                logger.error("The 'selectable' action is not supported in the Zeile IR. Skipping")
            case .effect:
                let effectData = asset.specialEffectData[snippet.referenceIndex]
                switch effectData.effectType {
                case .none:
                    break
                case .blackIn:
                    result.append(.hideBlackCover(duration: effectData.duration))
                case .blackOut:
                    result.append(.showBlackCover(duration: effectData.duration))
                case .whiteIn:
                    result.append(.hideWhiteCover(duration: effectData.duration))
                case .whiteOut:
                    result.append(.showWhiteCover(duration: effectData.duration))
                case .shakeScreen:
                    result.append(.shakeScreen(duration: effectData.duration))
                case .shakeWindow:
                    result.append(.shakeDialogBox(duration: effectData.duration))
                case .changeBackground, .changeBackgroundStill, .changeCardStill:
                    result.append(.changeBackground(path: "\(locale.rawValue)/\(effectData.stringVal)/\(effectData.stringValSub).png"))
                case .telop:
                    result.append(.telop(effectData.stringVal))
                case .playScenarioEffect:
                    if effectData.stringVal.hasPrefix("bgchange") {
                        result.append(.changeBackground(path: "\(locale.rawValue)/\(effectData.stringValSub)/bg.png"))
                    }
                    // There're a large number of scenario effects in GBP
                    // that we can't convert to IR because they're likely
                    // depending on Unity animation objects that we're
                    // unable to extract
                case .stopScenarioEffect:
                    break
                default: break
                }
            case .sound:
                let soundData = asset.soundData[snippet.referenceIndex]
                if !soundData.bgm.isEmpty {
                    result.append(.changeBGM(path: "\(bgmBasePath)/\(soundData.bgm.lowercased())/\(soundData.bgm).mp3"))
                }
                if !soundData.se.isEmpty {
                    if !soundData.seBundleName.isEmpty {
                        result.append(.changeSE(path: "\(locale.rawValue)/sound/se/\(soundData.seBundleName)/\(soundData.se).mp3"))
                    } else {
                        result.append(.changeSE(path: "https://bestdori.com/res/CommonSE/\(soundData.se).mp3"))
                    }
                }
            }
            
            if snippet.delay > 0 {
                var previousDelay = 0.0
                if index > 0 {
                    for snippet in snippets[0..<index].reversed() {
                        if snippet.progressType == 1 {
                            break
                        }
                        
                        if snippet.delay > 0 {
                            previousDelay = snippet.delay
                            break
                        }
                    }
                }
                result.insert(.delay(seconds: snippet.delay - previousDelay), at: 0)
            }
            
            return result
        }
        
        for i in 0..<asset.snippets.count {
            ir.actions.append(contentsOf: actions(at: i, in: asset.snippets))
        }
        
        return ir
    }
}

extension StoryIR.StepAction.Position.Base {
    fileprivate init(bandori side: SekaiAPI.Misc.StoryAsset.LayoutData.Side) {
        self = switch side {
        case .none:
            logger.fault(
                """
                Story layout side provides 'none', which it not supported \
                in the Zeile IR. Evaluating as 'center'.
                """,
                evaluate: .center
            )
        case .left: .left
        case .leftOver: .leftOutside
        case .leftInside: .leftInside
        case .center: .center
        case .right: .right
        case .rightOver: .rightOutside
        case .rightInside: .rightInside
        case .leftUnder: .leftBottom
        case .leftInsideUnder: .leftInsideBottom
        case .centerUnder: .centerBottom
        case .rightUnder: .rightBottom
        case .rightInsideUnder: .rightInsideBottom
        }
    }
}
