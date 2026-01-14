//===---*- Greatdori! -*---------------------------------------------------===//
//
// InfoDetermination.swift
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

import SekaiKit
import Foundation

func readLastID(allowInitialization: Bool = true) async -> Int? {
    do {
        let outputString = try String(contentsOfFile: NSHomeDirectory() + "/Library/Containers/GreatdoriOfflineResBundleGen/LastID.txt", encoding: .utf8).replacingOccurrences(of: "\n", with: "")
        if let outputInt = Int(outputString) {
            return outputInt
        } else {
            print("[×][LastID] Failed to parse Bash output as an integer. Output string: \(outputString).")
        }
    } catch {
        print("[!][LastID] Encounted an error while reading LastID. Error: \(error).")
        if !FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Containers/GreatdoriOfflineResBundleGen") {
            if allowInitialization {
                print("[$][LastID] Last ID initialization requested.")
                return await writeLastID(id: await fetchNewestID())
            } else {
                print("[×][LastID] Last ID isn't initialized. Auto-initialization is disabled.")
            }
        } else {
            print("[×][LastID] Cannot read LastID . Error: \(error).")
        }
    }
    return nil
}

@discardableResult
func writeLastID(id: Int?) async -> Int? {
    guard id != nil else {
        print("[×][LastID] LastID cannot be written as `nil`.")
        return nil
    }
    do {
        if !FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Containers/GreatdoriOfflineResBundleGen") {
            try FileManager.default.createDirectory(atPath: NSHomeDirectory() + "/Library/Containers/GreatdoriOfflineResBundleGen", withIntermediateDirectories: true)
        }
        let data = "\(id!)".data(using: .utf8)!
        try data.write(to: URL(filePath: NSHomeDirectory() + "/Library/Containers/GreatdoriOfflineResBundleGen/LastID.txt"))
        print("[$][LastID] LastID written as #\(id!).")
    } catch {
        print("[×][LastID] Cannot write LastID due to a Bash command failure. Error: \(error).")
    }
    return id
}

func fetchNewestID() async -> Int? {
    return await getRecentAssetPatchNotes(lastID: 0)?.first?.relatedID
}


func analyzePathBranch(_ path: String) -> String {
    let unavailablePaths = [
        "characters/ingameresourceset",
        "live2d",
        "musicscore",
        "pickupsituation",
        "star3d",
        "additional_music",
        "ani_degree_aniver_8.5th_rip",
        "animationbg",
        "appeal",
        "bili",
        "bilispend_rip",
        "birthday",
        "birthdayintroduction",
        "birthdayintroduction2021_rip",
        "changedstamp",
        "character_name_rip",
        "character_profile_data_rip",
        "characterprofile",
        "commenthomebanner_rip",
        "effect",
        "eventcommon_rip",
        "friendinvite",
        "genericanimation",
        "graphicalinfo",
        "growthfund_mission",
        "homebanner_rip",
        "limitedmission",
        "limitedpage",
        "loading",
        "map",
        "memorial",
        "multiplay",
        "newsituationintroduction_rip",
        "newyearcard",
        "newyearholidays",
        "popipa_10th_rip",
        "speciallottery",
        "specialtraining",
        "starshop",
        "thumb/billinggoods",
        "thumb/characterrank_exp_rip",
        "thumb/costume3ddress",
        "thumb/costume3dhairstyle",
        "thumb/limiteditem_rip",
        "thumb/selfintroductionepisode_rip",
        "thumbnail",
        "title",
        "tutorial_rip",
        "worldmap_rip",
        "april",
        "button_",
        "bili_bottun",
    ]
    let sharedPaths = [
        "FIXME: SHARED PATH"
        /*
         - biography （需要核实)
         - bg
         - character（需要进一步研究，故事assets存在本地化）
         - deco
         - live2d
         - sdchara
         - stage_challenge所有
         - thumb/areaitem/group00000_rip
         - thumb/chara
         - thumb/common_rip
         - thumb/costume
         - thumb/eventbadge_rip
         - thumb/exchangeicon_rip
         - thumb/limitedskin_rip
         - thumb/liveskinlane_rip
         - thumb/material_rip
         - thumb/photostudio/bg_rip
         - thumb/parameter_rip
         - thumb/potential_level_rip
         - ui/character_kv_atlas_rip
         - ui/character_kv_image
         */
    ]
    
    if pathMatchesPrefix(path, prefixs: unavailablePaths) {
        return "unsupported"
    } else if pathMatchesPrefix(path, prefixs: sharedPaths) {
        return "shared"
    } else if path.hasPrefix("movie") {
        return "movie"
    } else if path.hasPrefix("sound") {
        return "sound"
    } else {
        return "basic"
    }
    
    func pathMatchesPrefix(_ path: String, prefixs: [String]) -> Bool {
        for unavailablePath in prefixs {
            if path.hasPrefix(unavailablePath) {
                return true
            }
        }
        return false
    }
}

func printCurrentTime() {
    var dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .full
    dateFormatter.timeStyle = .full
    print("[$][Time] It's now \(dateFormatter.string(from: Date.now))")
}
