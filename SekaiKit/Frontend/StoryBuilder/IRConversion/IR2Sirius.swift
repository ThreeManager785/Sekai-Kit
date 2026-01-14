//===---*- Greatdori! -*---------------------------------------------------===//
//
// IR2Sirius.swift
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

extension IRConversion {
    internal static func convertToSirius(_ ir: StoryIR, allowClosures: Bool = true) -> String {
        var result = ""
        
        result.append("# LOCALE: \(ir.locale.rawValue.uppercased())\n\n")
        result.append(siriusParseActions(ir.actions, allowClosures: allowClosures))
        result.append("\nEOF.")
        
        return result
    }
    
    private static func siriusParseActions(_ actions: [StoryIR.StepAction], depth: Int = 0, allowClosures: Bool) -> String {
        var result = ""
        for index in 0..<actions.count {
            result.append("\(String(repeating: "  ", count: depth))\(index) ")
            result.append(sirius2ParseAction(actions[index], depth: depth, allowClosures: allowClosures))
            result.append("\n")
        }
        return result
    }
    
    private static func sirius2ParseAction(_ action: StoryIR.StepAction, depth: Int = 0, allowClosures: Bool) -> String {
        if allowClosures {
            switch action {
            case .blocking(let array):
                return siriusGiveClosure("Blocking", content: siriusParseActions(array, depth: depth+1, allowClosures: true), depth: depth)
            case .forkTask(let array):
                return siriusGiveClosure("ForkTask", content: siriusParseActions(array, depth: depth+1, allowClosures: true), depth: depth)
            default:
                return "\(action)".siriusFormatted()
            }
        } else {
            return "\(action)".siriusFormatted()
        }
    }
    
    // NO USAGE
    /*
    private static func sirius1ParseActionFull(_ action: StoryIR.StepAction, depth: Int = 0, allowClosures: Bool) -> String {
        switch action {
        case .talk(let string, let characterIDs, let characterNames, let voicePath):
            return siriusCombineReadableOutput("Talk", ["": string.replacingOccurrences(of: "\n", with: "\\n"), "charID": characterIDs, "charName": characterNames, "voicePath": voicePath])
            
        case .telop(let string):
            return siriusCombineReadableOutput("Telop", ["": string])
            
        case .showModel(let characterID, let modelPath, let position):
            return siriusCombineReadableOutput("ShowModel", ["charID": characterID, "modelPath": modelPath, "position": position])
            
        case .hideModel(let characterID):
            return siriusCombineReadableOutput("HideModel", ["charID": characterID])
            
        case .moveModel(let characterID, let position):
            return siriusCombineReadableOutput("MoveModel", ["charID": characterID, "position": position])
            
        case .act(let characterID, let motionName):
            return siriusCombineReadableOutput("Act", ["charID": characterID, "motionName": motionName])
            
        case .express(let characterID, let expressionName):
            return siriusCombineReadableOutput("Express", ["charID": characterID, "motionName": expressionName])
            
        case .horizontalShake(let characterID):
            return siriusCombineReadableOutput("HorizontalShake", ["charID": characterID])
            
        case .verticalShake(let characterID):
            return siriusCombineReadableOutput("VerticalShake", ["charID": characterID])
            
        case .showBlackCover(let duration):
            return siriusCombineReadableOutput("ShowBlackCover", ["duration": duration])
            
        case .hideBlackCover(let duration):
            return siriusCombineReadableOutput("HideBlackCover", ["duration": duration])
            
        case .showWhiteCover(let duration):
            return siriusCombineReadableOutput("ShowWhiteCover", ["duration": duration])
            
        case .hideWhiteCover(let duration):
            return siriusCombineReadableOutput("HideWhiteCover", ["duration": duration])
            
        case .shakeScreen(let duration):
            return siriusCombineReadableOutput("ShakeScreen", ["duration": duration])
            
        case .shakeDialogBox(let duration):
            return siriusCombineReadableOutput("ShakeDialogBox", ["duration": duration])
            
        case .changeBackground(let path):
            return siriusCombineReadableOutput("ChangeBackground", ["path": path])
            
        case .changeBGM(let path):
            return siriusCombineReadableOutput("ChangeBGM", ["path": path])
            
        case .changeSE(let path):
            return siriusCombineReadableOutput("ChangeSE", ["path": path])
             
        case .blocking(let array):
            if allowClosures {
                return siriusCombineReadableOutput("Blocking", ["closure": siriusParseActions(array, depth: depth+1, allowClosures: true)], closureDepth: depth)
            } else {
                return siriusCombineReadableOutput("Blocking", ["array": array])
            }
            
        case .delay(let seconds):
            return siriusCombineReadableOutput("Delay", ["seconds": seconds])
            
        case .forkTask(let array):
            if allowClosures {
                return siriusCombineReadableOutput("ForkTask", ["closure": siriusParseActions(array, depth: depth+1, allowClosures: true)], closureDepth: depth)
            } else {
                return siriusCombineReadableOutput("ForkTask", ["array": array])
            }
           
        case .waitForTap:
            return siriusCombineReadableOutput("WaitForTap", [:])
            
        case .waitForAll:
            return siriusCombineReadableOutput("WaitForAll", [:])
        }
    }
     */
    
    private static func siriusGiveClosure(_ action: String, content: String, depth: Int = 0) -> String {
        var output = ""
        output.append("\(action)")
        
        if content.isEmpty {
            output.append(" {}")
        } else {
            output.append(" {\n\(content)\(String(repeating: "  ", count: depth))}")
        }
        
        return output
    }
    
    private static func siriusCombineReadableOutput(_ action: String, _ params: Dictionary<String, Any>, closureDepth: Int = 0) -> String {
        var output = ""
        
        output.append("\(action)")
        
        if !params.isEmpty {
            if params.keys.first == "closure" {
                if (params["closure"]! as? String)?.isEmpty ?? true {
                    output.append(" {}")
                } else {
                    output.append(" {\n\(params["closure"]!)\(String(repeating: "  ", count: closureDepth))}")
                }
            } else {
                output.append(" (")
                var sortedParams = params.sorted { $0.key < $1.key }
                
                for (key, value) in sortedParams {
                    if !key.isEmpty {
                        output.append("\(key): ")
                    }
                    output.append("\(value)")
                    if key != sortedParams.last!.key {
                        output.append(", ")
                    } else {
                        output.append(")")
                    }
                }
            }
        }
        
        return output
    }
}

fileprivate extension String {
    func siriusFormatted() -> String {
        guard !self.isEmpty else { return "" }
        var mutableSelf = self
        
        mutableSelf = mutableSelf.first!.uppercased() + mutableSelf.dropFirst()
        
        if let firstOpenBracket = mutableSelf.firstIndex(where: { $0 == "(" }) {
            mutableSelf.insert(" ", at: firstOpenBracket)
        }
        
        return mutableSelf
    }
}
