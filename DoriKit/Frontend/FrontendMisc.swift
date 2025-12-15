//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendMisc.swift
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
private import Builtin

extension _DoriFrontend {
    /// Other uncatogorized requests in Bandori.
    public enum Misc {
        /// Returns a list of items with related information from given items.
        ///
        /// - Parameter items: A collection of items.
        /// - Returns: Items with related information from given items, nil if failed to fetch.
        public static func extendedItems<T>(
            from items: T
        ) async -> [ExtendedItem]? where T: RandomAccessCollection, T.Element == Item {
            guard let texts = await _DoriAPI.Misc.itemTexts() else { return nil }
            
            // These data may or may not be used, we fetch them on demand
            var failureFlag: UInt8 = 0 // If something failed,
                                       // we don't try it anymore
            var degrees: [_DoriAPI.Degrees.Degree]?
            var decoFrames: [_DoriAPI.Misc.DecoFrame]?
            var decoPins: [_DoriAPI.Misc.DecoPin]?
            var decoPinSets: [_DoriAPI.Misc.DecoPinSet]?
            var gameLaneSkins: [_DoriAPI.Misc.GameLaneSkin]?
            var stamps: [_DoriAPI.Misc.Stamp]?
            var cards: [_DoriAPI.Cards.PreviewCard]?
            
            var result = [ExtendedItem]()
            for item in items {
                var text: _DoriAPI.Misc.ItemText?
                var iconImageURL: URL?
                var relatedItemSource: ExtendedItem.ItemSource?
                
                switch item.type {
                case .item, .practiceTicket, .liveBoostRecoveryItem,
                        .gachaTicket, .miracleTicket:
                    // These types of items are included in itemTexts result,
                    // we get it directly.
                    if let id = item.itemID,
                       let t = texts["\(item.type.rawValue)_\(id)"] {
                        text = t
                        
                        let locale = t.name.availableLocale() ?? .jp
                        switch item.type {
                        case .item:
                            iconImageURL = .init(string: "https://bestdori.com/assets/\(locale.rawValue)/thumb/material_rip/material\(unsafe String(format: "%03d", t.resourceID)).png")
                        case .practiceTicket:
                            switch t.type {
                            case .practice:
                                iconImageURL = .init(string: "https://bestdori.com/assets/\(locale.rawValue)/thumb/common_rip/practiceTicket\(t.resourceID).png")
                            case .skillPractice:
                                iconImageURL = .init(string: "https://bestdori.com/assets/\(locale.rawValue)/thumb/common_rip/skillticket_\(t.resourceID).png")
                            default: break
                            }
                        case .liveBoostRecoveryItem:
                            iconImageURL = .init(string: "https://bestdori.com/assets/\(locale.rawValue)/thumb/common_rip/boostdrink_\(t.resourceID).png")
                        case .gachaTicket:
                            iconImageURL = .init(string: "https://bestdori.com/assets/\(locale.rawValue)/thumb/common_rip/gachaTicket\(id).png")
                        case .miracleTicket:
                            iconImageURL = .init(string: "https://bestdori.com/assets/\(locale.rawValue)/thumb/common_rip/miracleTicket\(t.resourceID).png")
                        default:
                            // cases in this `switch` statement are matched to
                            // the outer case matching list
                            Builtin.unreachable()
                        }
                    }
                case .star:
                    if [0, nil].contains(item.itemID) {
                        text = .init(
                            name: .init(
                                jp: "スター (無償)",
                                en: "Star (Free)",
                                tw: "Star (免費)",
                                cn: "星石 (免费)",
                                kr: "스타 (무료)"
                            ),
                            type: nil,
                            resourceID: -1
                        )
                    } else {
                        text = .init(
                            name: .init(
                                jp: "スター (有償)",
                                en: "Star (Paid)",
                                tw: "Star (付費)",
                                cn: "星石 (付费)",
                                kr: "스타 (유료)"
                            ),
                            type: nil,
                            resourceID: -1
                        )
                    }
                    iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/common_rip/star.png")
                case .coin:
                    text = .init(
                        name: .init(
                            jp: "コイン",
                            en: "Coin",
                            tw: "金幣",
                            cn: "金币",
                            kr: "골드"
                        ),
                        type: nil,
                        resourceID: -1
                    )
                    iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/common_rip/coin.png")
                case .stamp:
                    text = .init(
                        name: .init(
                            jp: "レアスタンプ",
                            en: "Rare Stamp",
                            tw: "稀有貼圖",
                            cn: "稀有表情",
                            kr: "레어 스탬프"
                        ),
                        type: nil,
                        resourceID: -1
                    )
                    if stamps == nil && failureFlag & 1 << 5 == 0 {
                        let list = await _DoriAPI.Misc.stamps()
                        if let list {
                            stamps = list
                        } else {
                            failureFlag |= 1 << 5
                        }
                    }
                    if let stamps,
                       let stamp = stamps.first(where: { $0.id == item.itemID }) {
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/stamp/01_rip/\(stamp.imageName).png")
                    }
                case .degree:
                    if degrees == nil && failureFlag & 1 == 0 {
                        let list = await _DoriAPI.Degrees.all()
                        if list != nil {
                            degrees = list
                        } else {
                            failureFlag |= 1
                        }
                    }
                    if let degrees,
                       let degree = degrees.first(where: { $0.id == item.itemID }) {
                        text = .init(
                            name: degree.degreeName,
                            type: nil,
                            resourceID: -1
                        )
                    } else {
                        text = .init(
                            name: .init(
                                jp: "称号",
                                en: "Title",
                                tw: "稱號",
                                cn: "称号",
                                kr: "제목"
                            ),
                            type: nil,
                            resourceID: -1
                        )
                    }
                    iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/common_rip/degree.png")
                case .michelleSeal:
                    text = .init(
                        name: .init(
                            jp: "ミッシェルシール",
                            en: "Michelle Sticker",
                            tw: "米歇爾貼紙",
                            cn: "米歇尔贴纸",
                            kr: "미라클 스티커"
                        ),
                        type: nil,
                        resourceID: -1
                    )
                    iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/common_rip/michelle_seal.png")
                case .decoFrame:
                    if decoFrames == nil && failureFlag & 1 << 1 == 0 {
                        let list = await _DoriAPI.Misc.decoFrames()
                        if list != nil {
                            decoFrames = list
                        } else {
                            failureFlag |= 1 << 1
                        }
                    }
                    if let decoFrames,
                       let frame = decoFrames.first(where: { $0.id == item.itemID }) {
                        text = .init(
                            name: frame.decoFrameName,
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/deco/frame_rip/\(frame.assetBundleName).png")
                    } else {
                        text = .init(
                            name: .init(
                                jp: "フレーム",
                                en: "Frame",
                                tw: "外框",
                                cn: "名片框",
                                kr: "액자"
                            ),
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/deco/frame_rip/deco_frame007.png")
                    }
                case .decoPins:
                    if decoPins == nil && failureFlag & 1 << 2 == 0 {
                        let list = await _DoriAPI.Misc.decoPins()
                        if list != nil {
                            decoPins = list
                        } else {
                            failureFlag |= 1 << 2
                        }
                    }
                    if let decoPins,
                       let pin = decoPins.first(where: { $0.id == item.itemID }) {
                        text = .init(
                            name: pin.decoPinName,
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/deco/pins_rip/\(pin.assetBundleName).png")
                    } else {
                        text = .init(
                            name: .init(
                                jp: "ピンズ",
                                en: "Pins",
                                tw: "別針",
                                cn: "装饰",
                                kr: "핀즈"
                            ),
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/deco/pins_rip/deco_pins_single.png")
                    }
                case .decoPinsSet:
                    if decoPinSets == nil && failureFlag & 1 << 3 == 0 {
                        let list = await _DoriAPI.Misc.decoPinSets()
                        if list != nil {
                            decoPinSets = list
                        } else {
                            failureFlag |= 1 << 3
                        }
                    }
                    if let decoPinSets,
                       let pinSet = decoPinSets.first(where: { $0.id == item.itemID }) {
                        text = .init(
                            name: pinSet.decoPinSetName,
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/deco/pins_rip/\(pinSet.assetBundleName).png")
                    } else {
                        text = .init(
                            name: .init(
                                jp: "ピンズセット",
                                en: "Pins",
                                tw: "別針套組",
                                cn: "装饰组合",
                                kr: "핀즈 세트"
                            ),
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/deco/pins_rip/deco_pins_shuffle.png")
                    }
                case .inGameSkinLane:
                    if gameLaneSkins == nil && failureFlag & 1 << 4 == 0 {
                        let list = await _DoriAPI.Misc.gameLaneSkins()
                        if list != nil {
                            gameLaneSkins = list
                        } else {
                            failureFlag |= 1 << 4
                        }
                    }
                    if let gameLaneSkins,
                       let skin = gameLaneSkins.first(where: { $0.id == item.itemID }) {
                        text = .init(
                            name: skin.skinName,
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/liveskinlane_rip/\(skin.assetBundleName).png")
                    } else {
                        text = .init(
                            name: .init(
                                jp: "レーンスキン",
                                en: "Lane",
                                tw: "軌跡外觀",
                                cn: "按键条皮肤",
                                kr: "레인 스킨"
                            ),
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/liveskinlane_rip/skin05.png")
                    }
                case .situation:
                    if cards == nil && failureFlag & 1 << 6 == 0 {
                        let list = await _DoriAPI.Cards.all()
                        if list != nil {
                            cards = list
                        } else {
                            failureFlag |= 1 << 6
                        }
                    }
                    if let cards,
                       let card = cards.first(where: { $0.id == item.itemID }) {
                        text = .init(
                            name: card.prefix,
                            type: nil,
                            resourceID: -1
                        )
                        iconImageURL = card.coverNormalImageURL
                        relatedItemSource = .card(card)
                    } else {
                        text = .init(
                            name: .init(
                                jp: "カード",
                                en: "Card",
                                tw: "卡片",
                                cn: "卡牌",
                                kr: "카드"
                            ),
                            type: nil,
                            resourceID: -1
                        )
                    }
                case .costume3DMakingItem:
                    text = .init(
                        name: .init(
                            jp: "裁縫セット",
                            en: "Sewing Set",
                            tw: "裁縫工具組",
                            cn: "裁缝套装",
                            kr: "재봉 세트"
                        ),
                        type: nil,
                        resourceID: -1
                    )
                    iconImageURL = .init(string: "https://bestdori.com/assets/\(_DoriAPI.preferredLocale.rawValue)/thumb/material_rip/costume3dmakingitem001.png")
                default: break
                }
                result.append(.init(
                    item: item,
                    text: text,
                    iconImageURL: iconImageURL,
                    relatedItemSource: relatedItemSource
                ))
            }
            return result
        }
        
        public static func extendedPlayerProfile(of id: Int, in locale: _DoriAPI.Locale) async -> ExtendedPlayerProfile? {
            let groupResult = await withTasksResult {
                await _DoriAPI.Misc.playerProfile(of: id, in: locale)
            } _: {
                await _DoriAPI.Degrees.all()
            } _: {
                await _DoriAPI.Cards.all()
            } _: {
                await _DoriAPI.Songs.all()
            }
            guard let profile = groupResult.0 else { return nil }
            guard let degrees = groupResult.1 else { return nil }
            guard let cards = groupResult.2 else { return nil }
            guard let songs = groupResult.3 else { return nil }
            
            return .init(
                profile: profile,
                degrees: degrees.filter { profile.userProfileDegree.compactMap { $0 }.contains($0.id)
                },
                keyVisualCard: cards.first { $0.id == profile.userProfileSituation.situationID } ?? .init( // dummy
                    id: -1,
                    characterID: -1,
                    rarity: -1,
                    attribute: .powerful,
                    levelLimit: -1,
                    resourceSetName: "",
                    prefix: .init(jp: nil, en: nil, tw: nil, cn: nil, kr: nil),
                    releasedAt: .init(jp: nil, en: nil, tw: nil, cn: nil, kr: nil),
                    skillID: -1,
                    type: .others,
                    stat: .init()
                ),
                mainDeckCards: cards.filter {
                    [profile.mainUserDeck.leader,
                     profile.mainUserDeck.member1,
                     profile.mainUserDeck.member2,
                     profile.mainUserDeck.member3,
                     profile.mainUserDeck.member4].contains($0.id)
                },
                songs: songs.filter {
                    (profile.userHighScoreRating.poppinParty.map(\.musicID)
                     + profile.userHighScoreRating.afterglow.map(\.musicID)
                     + profile.userHighScoreRating.pastelPalettes.map(\.musicID)
                     + profile.userHighScoreRating.helloHappyWorld.map(\.musicID)
                     + profile.userHighScoreRating.roselia.map(\.musicID)
                     + profile.userHighScoreRating.others.map(\.musicID)
                     + profile.userHighScoreRating.morfonica.map(\.musicID)
                     + profile.userHighScoreRating.raiseASuilen.map(\.musicID)
                     + profile.userHighScoreRating.myGO.map(\.musicID)).contains($0.id)
                }
            )
        }
    }
}

extension _DoriFrontend {
    public typealias Item = _DoriAPI.Item
    
    public struct ExtendedItem: Sendable, Identifiable, Hashable, DoriCache.Cacheable {
        public var item: Item
        public var text: _DoriAPI.Misc.ItemText?
        public var _iconImageURL: URL?
        public var relatedItemSource: ItemSource?
        
        @inlinable
        public var id: String {
            item.id
        }
        
        @inlinable
        public var iconImageURL: URL? {
            _iconImageURL?.respectOfflineAssetContext()
        }
        
        internal init(
            item: Item,
            text: _DoriAPI.Misc.ItemText?,
            iconImageURL: URL?,
            relatedItemSource: ItemSource?
        ) {
            self.item = item
            self.text = text
            self._iconImageURL = iconImageURL
            self.relatedItemSource = relatedItemSource
        }
        
        public enum ItemSource: Sendable, Hashable, DoriCache.Cacheable {
            case card(_DoriAPI.Cards.PreviewCard)
        }
    }
}

extension _DoriFrontend.Misc {
    public struct ExtendedPlayerProfile: Sendable, Hashable, DoriCache.Cacheable {
        public var profile: _DoriAPI.Misc.PlayerProfile
        public var degrees: [_DoriAPI.Degrees.Degree]
        public var keyVisualCard: _DoriAPI.Cards.PreviewCard
        public var mainDeckCards: [_DoriAPI.Cards.PreviewCard]
        public var songs: [_DoriAPI.Songs.PreviewSong]
    }
}

extension _DoriAPI.Misc.StoryAsset {
    /// Textual transcript of story.
    public var transcript: [Transcript] {
        var result = [Transcript]()
        for snippet in self.snippets {
            switch snippet.actionType {
            case .talk:
                let ref = self.talkData[snippet.referenceIndex]
                result.append(.talk(.init(
                    _characterID: ref.talkCharacters.count > 0 ? ref.talkCharacters[0].characterID : 0,
                    characterName: ref.windowDisplayName,
                    text: ref.body,
                    voiceID: ref.voices.count > 0 ? ref.voices[0].voiceID : nil
                )))
            case .effect:
                let ref = self.specialEffectData[snippet.referenceIndex]
                if ref.effectType == .telop {
                    result.append(.notation(ref.stringVal))
                }
            default: break
            }
        }
        return result
    }
    
    public enum Transcript: Sendable, Hashable {
        case talk(Talk)
        case notation(String)
        
        public struct Talk: Sendable, Hashable {
            public var _characterID: Int
            public var characterName: String
            public var text: String
            public var voiceID: String?
            
            internal init(_characterID: Int, characterName: String, text: String, voiceID: String?) {
                self._characterID = _characterID
                self.characterName = characterName
                self.text = text
                self.voiceID = voiceID
            }
            
            @inlinable
            public var characterIconImageURL: URL? {
                if _characterID > 0 {
                    .init(string: "https://bestdori.com/res/icon/chara_icon_\(_characterID).png")!
                } else {
                    nil
                }
            }
        }
    }
}
