//===---*- Greatdori! -*---------------------------------------------------===//
//
// IR2Bestdori.swift
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
internal import SwiftyJSON

extension IRConversion {
    internal static func convertToBestdori(_ ir: StoryIR) -> [String: Any] {
        var result: [String: Any] = [:]
        
        var irActions = ir.actions
        
        result.updateValue(0, forKey: "server")
        result.updateValue("", forKey: "voice")
        
        var removeIndexs: IndexSet = []
        // Find initial background & BGM
        for (index, action) in ir.actions.enumerated() {
            if case .changeBackground(path: let path) = action {
                result.updateValue(resolvePath(path, containsBundle: true, bundlePrefix: "bg/"), forKey: "background")
                removeIndexs.insert(index)
            } else if case .changeBGM(path: let path) = action {
                result.updateValue(resolvePath(path, containsBundle: false), forKey: "bgm")
                removeIndexs.insert(index)
            } else {
                break
            }
        }
        irActions.remove(atOffsets: removeIndexs)
        
        var actions: [[String: Any]] = []
        for (index, action) in irActions.enumerated() {
            actions.append(contentsOf: resolveAction(action, in: irActions, at: index))
        }
        result.updateValue(actions, forKey: "actions")
        
        return result
    }
    
    private static func resolveAction(
        _ action: StoryIR.StepAction,
        in list: [StoryIR.StepAction],
        at index: Int,
        wait: Bool = false
    ) -> [[String: Any]] {
        func addDelay(to result: inout [String: Any]) {
            guard index > 0 else {
                result.updateValue(0, forKey: "delay")
                return
            }
            find: for action in list[0..<index].reversed() {
                switch action {
                case .delay(seconds: let seconds):
                    result.updateValue(Int(seconds), forKey: "delay")
                    break find
                default: break find
                }
            }
            if result["delay"] == nil {
                result.updateValue(0, forKey: "delay")
            }
        }
        func lastPosition(of id: Int) -> StoryIR.StepAction.Position? {
            guard index > 0 else { return nil }
            for action in list[0..<index].reversed() {
                switch action {
                case .showModel(characterID: let charaID, modelPath: _, position: let pos):
                    if charaID == id {
                        return pos
                    }
                case .moveModel(characterID: let charaID, position: let pos):
                    if charaID == id {
                        return pos
                    }
                default: break
                }
            }
            return nil
        }
        func modelPath(for id: Int) -> String? {
            guard index > 0 else { return nil }
            for action in list[0..<index].reversed() {
                switch action {
                case .showModel(characterID: let charaID, modelPath: let path, position: _):
                    if charaID == id {
                        return path
                    }
                default: break
                }
            }
            return nil
        }
        
        var result: [[String: Any]] = []
        switch action {
        case .talk(let content, characterIDs: let characterIDs, characterNames: let characterNames, voicePath: let voicePath):
            var r: [String: Any] = [:]
            r.updateValue("talk", forKey: "type")
            addDelay(to: &r)
            r.updateValue(true, forKey: "wait") // We always wait in the `talk` action
            r.updateValue(characterIDs, forKey: "characters")
            r.updateValue(characterNames.first ?? "", forKey: "name")
            r.updateValue(content, forKey: "body")
            r.updateValue([], forKey: "motions")
            r.updateValue([], forKey: "voices")
            r.updateValue(false, forKey: "close")
            result.append(r)
        case .telop(let content):
            var r: [String: Any] = [:]
            r.updateValue("effect", forKey: "type")
            r.updateValue("telop", forKey: "effectType")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(content, forKey: "text")
            result.append(r)
        case .showModel(characterID: let characterID, modelPath: let modelPath, position: let position):
            var r: [String: Any] = [:]
            r.updateValue("layout", forKey: "type")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue("appear", forKey: "layoutType")
            r.updateValue(characterID, forKey: "character")
            r.updateValue(modelPath.components(separatedBy: "/").last ?? "", forKey: "costume")
            r.updateValue("", forKey: "motion")
            r.updateValue("", forKey: "expression")
            r.updateValue(mapPosition(position.base), forKey: "sideFrom")
            r.updateValue(Int(position.offsetX), forKey: "sideFromOffsetX")
            r.updateValue(mapPosition(position.base), forKey: "sideTo")
            r.updateValue(Int(position.offsetX), forKey: "sideToOffsetX")
            result.append(r)
        case .hideModel(characterID: let characterID):
            var r: [String: Any] = [:]
            r.updateValue("layout", forKey: "type")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue("hide", forKey: "layoutType")
            r.updateValue(characterID, forKey: "character")
            r.updateValue(modelPath(for: characterID)?.components(separatedBy: "/").last ?? "", forKey: "costume")
            r.updateValue("", forKey: "motion")
            r.updateValue("", forKey: "expression")
            let position = lastPosition(of: characterID) ?? .init(base: .center, offsetX: 0)
            r.updateValue(mapPosition(position.base), forKey: "sideFrom")
            r.updateValue(Int(position.offsetX), forKey: "sideFromOffsetX")
            r.updateValue(mapPosition(position.base), forKey: "sideTo")
            r.updateValue(Int(position.offsetX), forKey: "sideToOffsetX")
            result.append(r)
        case .moveModel(characterID: let characterID, position: let position):
            var r: [String: Any] = [:]
            r.updateValue("layout", forKey: "type")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue("move", forKey: "layoutType")
            r.updateValue(characterID, forKey: "character")
            r.updateValue(modelPath(for: characterID)?.components(separatedBy: "/").last ?? "", forKey: "costume")
            r.updateValue("", forKey: "motion")
            r.updateValue("", forKey: "expression")
            let lastPos = lastPosition(of: characterID) ?? .init(base: .center, offsetX: 0)
            r.updateValue(mapPosition(lastPos.base), forKey: "sideFrom")
            r.updateValue(Int(lastPos.offsetX), forKey: "sideFromOffsetX")
            r.updateValue(mapPosition(position.base), forKey: "sideTo")
            r.updateValue(Int(position.offsetX), forKey: "sideToOffsetX")
            result.append(r)
        case .act(characterID: let characterID, motionName: let motionName):
            var r: [String: Any] = [:]
            r.updateValue("motion", forKey: "type")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(characterID, forKey: "character")
            r.updateValue(modelPath(for: characterID)?.components(separatedBy: "/").last ?? "", forKey: "costume")
            r.updateValue(motionName, forKey: "motion")
            r.updateValue("", forKey: "expression")
            result.append(r)
        case .express(characterID: let characterID, expressionName: let expressionName):
            var r: [String: Any] = [:]
            r.updateValue("motion", forKey: "type")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(characterID, forKey: "character")
            r.updateValue(modelPath(for: characterID)?.components(separatedBy: "/").last ?? "", forKey: "costume")
            r.updateValue("", forKey: "motion")
            r.updateValue(expressionName, forKey: "expression")
            result.append(r)
        case .showBlackCover(duration: let duration):
            var r: [String: Any] = [:]
            r.updateValue("effect", forKey: "type")
            r.updateValue("blackIn", forKey: "effectType")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(duration, forKey: "duration")
            result.append(r)
        case .hideBlackCover(duration: let duration):
            var r: [String: Any] = [:]
            r.updateValue("effect", forKey: "type")
            r.updateValue("blackOut", forKey: "effectType")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(duration, forKey: "duration")
            result.append(r)
        case .showWhiteCover(duration: let duration):
            var r: [String: Any] = [:]
            r.updateValue("effect", forKey: "type")
            r.updateValue("whiteIn", forKey: "effectType")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(duration, forKey: "duration")
            result.append(r)
        case .hideWhiteCover(duration: let duration):
            var r: [String: Any] = [:]
            r.updateValue("effect", forKey: "type")
            r.updateValue("whiteOut", forKey: "effectType")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(duration, forKey: "duration")
            result.append(r)
        case .changeBackground(path: let path):
            var r: [String: Any] = [:]
            r.updateValue("effect", forKey: "type")
            r.updateValue("changeBackground", forKey: "effectType")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(resolvePath(path, containsBundle: true, bundlePrefix: "bg/"), forKey: "background")
            result.append(r)
        case .changeBGM(path: let path):
            var r: [String: Any] = [:]
            r.updateValue("sound", forKey: "type")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(resolvePath(path, containsBundle: false), forKey: "bgm")
            result.append(r)
        case .changeSE(path: let path):
            var r: [String: Any] = [:]
            r.updateValue("sound", forKey: "type")
            addDelay(to: &r)
            r.updateValue(wait, forKey: "wait")
            r.updateValue(resolvePath(path, containsBundle: true), forKey: "se")
            result.append(r)
        case .blocking(let actions):
            for (index, action) in actions.enumerated() {
                result.append(contentsOf: resolveAction(
                    action,
                    in: actions,
                    at: index,
                    wait: index == actions.count - 1
                ))
            }
        case .forkTask(let actions):
            for (index, action) in actions.enumerated() {
                result.append(contentsOf: resolveAction(
                    action,
                    in: actions,
                    at: index
                ))
            }
        default: break
        }
        return result
    }
    
    private static func resolvePath(
        _ path: String,
        containsBundle: Bool,
        bundlePrefix: String = ""
    ) -> [String: Any] {
        var result: [String: Any] = [:]
        
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            result.updateValue("custom", forKey: "type")
            result.updateValue(path, forKey: "url")
        } else {
            result.updateValue("bandori", forKey: "type")
            let splitedPath = path.components(separatedBy: "/")
            if let filePart = splitedPath.last {
                let removedSuffix = filePart
                    .split(separator: ".")
                    .dropLast()
                    .joined(separator: ".")
                result.updateValue(removedSuffix, forKey: "file")
            }
            if containsBundle && splitedPath.count > 1 {
                var bundlePart = splitedPath[splitedPath.count - 2]
                if bundlePart.hasSuffix("_rip") {
                    bundlePart.removeLast("_rip".count)
                }
                result.updateValue(bundlePrefix + bundlePart, forKey: "bundle")
            }
        }
        
        return result
    }
    
    private static func mapPosition(_ position: StoryIR.StepAction.Position.Base) -> String {
        switch position {
        case .leftOutside: "leftOver"
        case .left: "leftInside"
        case .leftInside: "leftInside"
        case .leftBottom: "leftInside"
        case .leftInsideBottom: "leftInside"
        case .center: "center"
        case .centerBottom: "center"
        case .rightOutside: "rightOver"
        case .right: "rightInside"
        case .rightInside: "rightInside"
        case .rightBottom: "rightInside"
        case .rightInsideBottom: "rightInside"
        }
    }
}
