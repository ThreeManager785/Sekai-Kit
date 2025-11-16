//===---*- Greatdori! -*---------------------------------------------------===//
//
// IR2PlainText.swift
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

// IR text representation reference:
//
// Actions:
// tlk: talk
// tlp: telop
// mds: showModel (MoDelShow)
// mdh: hideModel (MoDelHide)
// mdm: moveModel (MoDelMove)
// act: act
// exp: express
// hsk: horizontalShake (HorizontalShaKe)
// vsk: verticalShake (VerticalShaKe)
// bcs: showBlackCover (BlackCoverShow)
// bch: hideBlackCover (BlackCoverHide)
// wcs: showWhiteCover (WhiteCoverShow)
// wch: hideWhiteCover (WhiteCoverHide)
// ssc: shakeScreen (ShakeSCreen)
// sdb: shakeDialogBox (ShakeDialogBox)
// cbg: changeBackground (ChangeBackGround)
// cbm: changeBGM (ChangeBackgroundMusic)
// cse: changeSE
// blk: blocking
// slp: delay (SLeeP)
// tsk: forkTask (TaSK)
// wfa: waitForAll
// wft: waitForTap
//
// For arguments list of actions, see definitions in IntermediateRep.swift,
// each arguments is passed respectively, separated by a comma(,),
// with an optional spacing.
// Numbers(Int and Float) are start with a hash(#).
// Texts and Paths have to be defined before with a name for reference,
// ending with a semicolon(;). Use a slash(\) to escape a semicolon in text.

extension IRConversion {
    internal static func convertToPlainText(_ ir: StoryIR) -> String {
        var textList: [String] = []
        var pathList: [String] = []
        
        func resolveTexts(_ actions: [StoryIR.StepAction]) {
            for action in actions {
                switch action {
                case .talk(let text, let characterIDs, let characterNames, let voicePath):
                    textList.append(text)
                    textList.append(contentsOf: characterNames)
                    if let voicePath {
                        pathList.append(voicePath)
                    }
                case .telop(let text):
                    textList.append(text)
                case .showModel(let characterID, let modelPath, let position):
                    pathList.append(modelPath)
                case .act(let characterID, let motionName):
                    textList.append(motionName)
                case .express(let characterID, let expressionName):
                    textList.append(expressionName)
                case .changeBackground(let path):
                    pathList.append(path)
                case .changeBGM(let path):
                    pathList.append(path)
                case .changeSE(let path):
                    pathList.append(path)
                case .blocking(let actions):
                    resolveTexts(actions)
                case .forkTask(let actions):
                    resolveTexts(actions)
                default: break
                }
            }
        }
        resolveTexts(ir.actions)
        
        textList = textList.uniqueElements()
        pathList = pathList.uniqueElements()
        
        var result = ""
        
        result += ".text\n"
        for (index, text) in textList.enumerated() {
            result += "t\(index): \(text.replacing(";", with: "\\;"));\n"
        }
        result += "\n"
        
        result += ".path\n"
        for (index, path) in pathList.enumerated() {
            result += "p\(index): \(path.replacing(";", with: "\\;"));\n"
        }
        result += "\n"
        
        var subCodes: [String] = []
        
        func convertActions(_ actions: [StoryIR.StepAction]) -> String {
            var result = ""
            for action in actions {
                switch action {
                case .talk(let text, let characterIDs, let characterNames, let voicePath):
                    let textIndex = textList.firstIndex(of: text)!
                    let charaIDStr = characterIDs.map { "#\($0)" }.joined(separator: ", ")
                    let charaNameStr = characterNames
                        .map { textList.firstIndex(of: $0)! }
                        .map { "t\($0)" }
                        .joined(separator: ", ")
                    result += "tlk    t\(textIndex), [\(charaIDStr)], [\(charaNameStr)]"
                    if let voicePath {
                        let index = pathList.firstIndex(of: voicePath)!
                        result += ", p\(index)"
                    }
                    result += "\n"
                case .telop(let text):
                    let textIndex = textList.firstIndex(of: text)!
                    result += "tlp    t\(textIndex)\n"
                case .showModel(let characterID, let modelPath, let position):
                    let pathIndex = pathList.firstIndex(of: modelPath)!
                    result += "mds    #\(characterID), p\(pathIndex), \(positionText(position))\n"
                case .hideModel(let characterID):
                    result += "mdh    #\(characterID)\n"
                case .moveModel(let characterID, let position):
                    result += "mdm    #\(characterID), \(positionText(position))\n"
                case .act(let characterID, let motionName):
                    let textIndex = textList.firstIndex(of: motionName)!
                    result += "act    #\(characterID), t\(textIndex)\n"
                case .express(let characterID, let expressionName):
                    let textIndex = textList.firstIndex(of: expressionName)!
                    result += "exp    #\(characterID), t\(textIndex)\n"
                case .horizontalShake(let characterID):
                    result += "hsk    #\(characterID)\n"
                case .verticalShake(let characterID):
                    result += "vsk    #\(characterID)\n"
                case .showBlackCover(let duration):
                    result += "bcs    #\(duration)\n"
                case .hideBlackCover(let duration):
                    result += "bch    #\(duration)\n"
                case .showWhiteCover(let duration):
                    result += "wcs    #\(duration)\n"
                case .hideWhiteCover(let duration):
                    result += "wch    #\(duration)\n"
                case .shakeScreen(let duration):
                    result += "ssc    #\(duration)\n"
                case .shakeDialogBox(let duration):
                    result += "sdb    #\(duration)\n"
                case .changeBackground(let path):
                    let pathIndex = pathList.firstIndex(of: path)!
                    result += "cbg    p\(pathIndex)\n"
                case .changeBGM(let path):
                    let pathIndex = pathList.firstIndex(of: path)!
                    result += "cbm    p\(pathIndex)\n"
                case .changeSE(let path):
                    let pathIndex = pathList.firstIndex(of: path)!
                    result += "cse    p\(pathIndex)\n"
                case .blocking(let actions):
                    subCodes.append(convertActions(actions))
                    result += "blk    $sub_\(subCodes.count - 1)\n"
                case .delay(let seconds):
                    result += "slp    #\(seconds)\n"
                case .forkTask(let actions):
                    subCodes.append(convertActions(actions))
                    result += "tsk    $sub_\(subCodes.count - 1)\n"
                case .waitForAll:
                    result += "wfa\n"
                case .waitForTap:
                    result += "wft\n"
                }
            }
            return result
        }
        
        result += ".code\n"
        result += convertActions(ir.actions)
        result += "\n"
        result += subCodes.enumerated().map { "sub_\($0.offset):\n\($0.element)" }.joined(separator: "\n")
        
        return result
    }
}

private func positionText(_ position: StoryIR.StepAction.Position) -> String {
    "{#\(position.base.rawValue), #\(position.offsetX)}"
}

extension Array<String> {
    fileprivate func uniqueElements() -> [Element] {
        var seen = Set<Element>()
        return self.filter { element in
            if seen.contains(element) {
                return false
            } else {
                seen.insert(element)
                return true
            }
        }
    }
}
