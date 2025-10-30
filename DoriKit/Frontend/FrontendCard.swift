//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendCard.swift
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

extension _DoriFrontend {
    /// Request and fetch data about card in Bandori.
    ///
    /// *Cards* are character illustrations that can be got from Gacha,
    /// with a skill and some other information.
    ///
    /// ![A card illustration:
    /// Soyo Nagasaki - This Type of Relationship is Called…
    /// ](CardExampleImage)
    public enum Cards {
        /// List all cards with related information.
        ///
        /// - Returns: All cards with band information, nil if failed to fetch.
        public static func list() async -> [CardWithBand]? {
            let groupResult = await withTasksResult {
                await _DoriAPI.Cards.all()
            } _: {
                await _DoriAPI.Characters.all()
            } _: {
                await _DoriAPI.Bands.main()
            }
            guard let cards = groupResult.0 else { return nil }
            guard let characters = groupResult.1 else { return nil }
            guard let bands = groupResult.2 else { return nil }
            
            FilterCacheManager.shared.writeBandsList(bands)
            FilterCacheManager.shared.writeCharactersList(characters)
            
            return cards.compactMap { card in
                if let band = bands.first(where: { $0.id == characters.first { $0.id == card.characterID }?.bandID }) {
                    .init(card: card, band: band)
                } else {
                    nil
                }
            }
        }
        
        /// Get a detailed card with related information.
        ///
        /// - Parameter id: The ID of card.
        /// - Returns: The card of requested ID,
        ///     with related characters, bands, skill, costumes,
        ///     events and gacha information.
        public static func extendedInformation(of id: Int) async -> ExtendedCard? {
            let groupResult = await withTasksResult {
                await _DoriAPI.Cards.detail(of: id)
            } _: {
                await _DoriAPI.Characters.all()
            } _: {
                await _DoriAPI.Bands.main()
            } _: {
                await _DoriAPI.Skills.all()
            } _: {
                await _DoriAPI.Costumes.all()
            } _: {
                await _DoriAPI.Events.all()
            } _: {
                await _DoriAPI.Gachas.all()
            } _: {
                await _DoriAPI.LoginCampaigns.all()
            }
            guard let card = groupResult.0 else { return nil }
            guard let characters = groupResult.1 else { return nil }
            guard let bands = groupResult.2 else { return nil }
            guard let skills = groupResult.3 else { return nil }
            guard let costumes = groupResult.4 else { return nil }
            guard let events = groupResult.5 else { return nil }
            guard let gacha = groupResult.6 else { return nil }
            guard let campaigns = groupResult.7 else { return nil }
            
            let character = characters.first { $0.id == card.characterID }!
            var resultGacha = [_DoriAPI.Gachas.PreviewGacha]()
            if let source = card.source.forPreferredLocale() {
                for src in source {
                    guard case .gacha(let info) = src else { continue }
                    resultGacha = gacha.filter { info.keys.contains($0.id) }
                }
            }
            
            func relatedEvent(for locale: _DoriAPI.Locale) -> PreviewEvent? {
                events.first {
                    ($0.startAt.forLocale(locale)?.timeIntervalSince1970 ?? 0)...($0.endAt.forLocale(locale)?.timeIntervalSince1970 ?? 0)
                    ~= card.releasedAt.forLocale(locale)?.timeIntervalSince1970 ?? 0o527
                }
            }
            
            return .init(
                id: id,
                card: card,
                cardSource: card.source.map {
                    let mappedResult = $0?.map { (src: _DoriAPI.Cards.Card.CardSource) -> _DoriFrontend.Cards.ExtendedCard.Source in
                        switch src {
                        case .gacha(let dict): .gacha(dict.compactMap { key, value in
                            if let g = gacha.first(where: { $0.id == key }) {
                                (key: g, value: value)
                            } else {
                                nil
                            }
                        }.reduce(into: [:]) { (dict, pair: (key: _DoriAPI.Gachas.PreviewGacha, value: Double)) in
                            // Swift says the types are too complex
                            // so we have to annotate the type
                            // of `pair` explicitly.
                            dict.updateValue(pair.value, forKey: pair.key)
                        })
                        case .event(let dict): .event(dict.compactMap { key, value in
                            if let e = events.first(where: { $0.id == key }) {
                                (key: e, value: value)
                            } else {
                                nil
                            }
                        }.reduce(into: [:]) { (dict, pair: (key: _DoriAPI.Events.PreviewEvent, value: Int)) in
                            // Swift says the types are too complex
                            // so we have to annotate the type
                            // of `pair` explicitly.
                            dict.updateValue(pair.value, forKey: pair.key)
                        })
                        case .login(let ids): .login(ids.compactMap { id in
                            campaigns.first { $0.id == id }
                        })
                        }
                    }
                    return mappedResult != nil ? Set(mappedResult!) : nil
                },
                character: character,
                band: bands.first { character.bandID == $0.id }!,
                skill: skills.first { $0.id == card.skillID }!,
                costume: costumes.first { $0.id == card.costumeID }!,
                event: .init(
                    jp: relatedEvent(for: .jp),
                    en: relatedEvent(for: .en),
                    tw: relatedEvent(for: .tw),
                    cn: relatedEvent(for: .cn),
                    kr: relatedEvent(for: .kr)
                ),
                gacha: resultGacha
            )
        }
    }
}

extension _DoriFrontend.Cards {
    public typealias PreviewCard = _DoriAPI.Cards.PreviewCard
    public typealias Card = _DoriAPI.Cards.Card
    
    /// Represent a ``PreviewCard`` with a related ``DoriAPI/Band/Band``.
    public struct CardWithBand: Sendable, Hashable, DoriCache.Cacheable {
        public var card: PreviewCard
        public var band: _DoriAPI.Bands.Band
    }
    /// Represent an extended card.
    public struct ExtendedCard: Sendable, Identifiable, Hashable, DoriCache.Cacheable {
        /// A unique ID of card.
        public var id: Int
        /// The base card information.
        public var card: Card
        /// Extended sources of this card.
        public var cardSource: _DoriAPI.LocalizedData<Set<Source>>
        /// The related character of this card.
        public var character: _DoriAPI.Characters.PreviewCharacter
        /// The band of the related character of this card.
        public var band: _DoriAPI.Bands.Band
        /// The skill of this card.
        public var skill: _DoriAPI.Skills.Skill
        /// The costume of this card.
        public var costume: _DoriAPI.Costumes.PreviewCostume
        /// The event which introduces this card.
        ///
        /// If no events introduce this card, all locales' data is `nil`.
        public var event: _DoriAPI.LocalizedData<_DoriAPI.Events.PreviewEvent>
        /// Gacha that contain this card.
        public var gacha: [_DoriAPI.Gachas.PreviewGacha]
        
        /// Represent a part of extended sources of a card.
        public enum Source: Sendable, Hashable, DoriCache.Cacheable {
            /// Information about a card can be got from gacha.
            ///
            /// This case is associated an `[PreviewGacha: Double]` dictionary,
            /// which represents `[gacha: probability]`.
            case gacha([_DoriAPI.Gachas.PreviewGacha: Double])
            /// Information about a card can be got from events.
            ///
            /// This case is associated an `[PreviewEvent: Int]` dictionary,
            /// which represents `[event: point]`.
            case event([_DoriAPI.Events.PreviewEvent: Int])
            /// Information about a card can be got from login campaigns.
            case login([_DoriAPI.LoginCampaigns.PreviewCampaign])
        }
    }
}
extension _DoriFrontend.Cards.CardWithBand: _DoriFrontend.Searchable {
    public var id: Int { self.card.id }
    public var _searchLocalizedStrings: [_DoriAPI.LocalizedData<String>] {
        self.card._searchLocalizedStrings
    }
    public var _searchIntegers: [Int] {
        self.card._searchIntegers
    }
    public var _searchLocales: [_DoriAPI.Locale] {
        self.card._searchLocales
    }
    public var _searchBands: [_DoriAPI.Bands.Band] {
        [self.band]
    }
    public var _searchAttributes: [_DoriAPI.Attribute] {
        self.card._searchAttributes
    }
}

extension _DoriFrontend.Cards.ExtendedCard {
    @inlinable
    public init?(id: Int) async {
        if let card = await _DoriFrontend.Cards.extendedInformation(of: id) {
            self = card
        } else {
            return nil
        }
    }
}
