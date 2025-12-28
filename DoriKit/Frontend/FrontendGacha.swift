//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendGacha.swift
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

extension DoriFrontend {
    /// Request and fetch data about gacha in Bandori.
    ///
    /// *Gacha* allow you to get random cards from it
    /// by consuming Stars or tickets in GBP.
    ///
    /// ![Banner image of gacha:
    /// Pure White Light That Dispels Dardness Gacha](GachaExampleImage)
    public enum Gachas {
        /// List all gacha.
        ///
        /// - Returns: All gacha, nil if failed to fetch.
        public static func list() async -> [PreviewGacha]? {
            let groupResult = await withTasksResult {
                await DoriAPI.Gachas.all()
            } _: {
                await DoriAPI.Cards.all()
            }
            guard let gacha = groupResult.0 else { return nil }
            guard let cards = groupResult.1 else { return nil }
            
            FilterCacheManager.shared.writeCardCache(cards)
            
            return gacha
        }
        
        /// Get detailed gacha with related information.
        ///
        /// - Parameter id: The ID of gacha.
        /// - Returns: The gacha of requested ID,
        ///     with related events and cards information.
        public static func extendedInformation(of id: Int) async -> ExtendedGacha? {
            let groupResult = await withTasksResult {
                await DoriAPI.Gachas.detail(of: id)
            } _: {
                await DoriAPI.Events.all()
            } _: {
                await DoriAPI.Cards.all()
            }
            guard let gacha = groupResult.0 else { return nil }
            guard let events = groupResult.1 else { return nil }
            guard let cards = groupResult.2 else { return nil }
            
            if let pickupCardIDs = gacha.details.forPreferredLocale()?.filter({ $0.value.pickup }).keys {
                let cardDetails = gacha.details.map { dic in
                    if let dic {
                        return dic.compactMap { pair in
                            if let card = cards.first(where: { pair.key == $0.id }) {
                                (key: pair.value.rarityIndex, value: card)
                            } else {
                                nil
                            }
                        }.reduce(into: [Int: [DoriAPI.Cards.PreviewCard]]()) { partialResult, pair in
                            if var value = partialResult[pair.key] {
                                value.append(pair.value)
                                partialResult.updateValue(value, forKey: pair.key)
                            } else {
                                partialResult.updateValue([pair.value], forKey: pair.key)
                            }
                        }
                    }
                    return nil
                }
                return .init(
                    id: id,
                    gacha: gacha,
                    events: events.reduce(into: DoriAPI.LocalizedData(jp: nil, en: nil, tw: nil, cn: nil, kr: nil)) {
                        for locale in DoriAPI.Locale.allCases {
                            if let startAt = $1.startAt.forLocale(locale),
                               let endAt = $1.endAt.forLocale(locale),
                               let publishedAt = gacha.publishedAt.forLocale(locale),
                               startAt...endAt ~= publishedAt {
                                $0._set(($0.forLocale(locale) ?? []) + [$1], forLocale: locale)
                            }
                        }
                    },
                    pickupCards: cards.filter { pickupCardIDs.contains($0.id) },
                    cardDetails: cardDetails.forPreferredLocale() ?? [:]
                )
            }
            return nil
        }
    }
}

extension DoriFrontend.Gachas {
    public typealias PreviewGacha = DoriAPI.Gachas.PreviewGacha
    public typealias Gacha = DoriAPI.Gachas.Gacha
    
    /// Represent extended gacha.
    public struct ExtendedGacha: Sendable, Identifiable, Hashable, DoriCache.Cacheable {
        /// A unique ID of gacha.
        public var id: Int
        /// The base gacha information.
        public var gacha: Gacha
        /// The events that introduces this gacha.
        public var events: DoriAPI.LocalizedData<[DoriAPI.Events.PreviewEvent]>
        /// The pick-up cards in this gacha.
        public var pickupCards: [DoriAPI.Cards.PreviewCard]
        /// All cards in this gacha.
        ///
        /// This dictionary has a type of `[Int: [PreviewCard]]`,
        /// which means `[Rarity: [CardInfo]]`.
        public var cardDetails: [Int: [DoriAPI.Cards.PreviewCard]]
    }
}

extension DoriFrontend.Gachas.ExtendedGacha {
    @inlinable
    public init?(id: Int) async {
        if let gacha = await DoriFrontend.Gachas.extendedInformation(of: id) {
            self = gacha
        } else {
            return nil
        }
    }
}
