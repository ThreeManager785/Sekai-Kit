//===---*- Greatdori! -*---------------------------------------------------===//
//
// MatchedFilters.swift
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

extension SekaiFrontend {
    /// A type that can be filtered by ``SekaiFrontend/Filter``.
    public protocol Filterable {
        /// A group of ``SekaiFrontend/Filter/Key`` that can be used
        /// for filtering this type.
        static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] { get }
        
        // `matches` only handle single value.
        // Please keep in mind that it does handle values like any `Array` or `characterRequiresMatchAll`.
        // Unexpected value type or cache reading failure will lead to `nil` return.
        func _matches<ValueType>(_ value: ValueType, withCache: _FilterCache?) -> Bool?
    }
    
    public struct _FilterCache {
        fileprivate var cardsList: [SekaiAPI.Cards.PreviewCard]?
        fileprivate var cardsDict: [Int: SekaiAPI.Cards.PreviewCard] = [:]
        fileprivate var bandsList: [SekaiAPI.Bands.Band]?
        fileprivate var charactersList: [SekaiAPI.Characters.PreviewCharacter]?
    }
}

// MARK: - Supporting Types
private struct TimelineStatusWithServers {
    fileprivate let timelineStatus: SekaiFrontend.Filter.TimelineStatus
    fileprivate let servers: Set<SekaiFrontend.Filter.Server>
}

private struct AvailabilityWithServers: Equatable {
    fileprivate let releaseStatus: SekaiFrontend.Filter.ReleaseStatus
    fileprivate let servers: Set<SekaiFrontend.Filter.Server>
}

private func plainBandID(from bandID: Int) -> Int {
    if [1, 2, 3, 4, 5, 18, 21, 45].contains(bandID) {
        return bandID
    } else {
        return -1
    }
}

// MARK: - Filter Cache Manager
internal final class FilterCacheManager: Sendable {
    internal static let shared = FilterCacheManager()
    
    nonisolated(unsafe) private var allCache = SekaiFrontend._FilterCache()
    private let lock = NSLock()
    
    internal func writeCardCache(_ cardsList: [SekaiAPI.Cards.PreviewCard]?) {
        lock.lock()
        defer { lock.unlock() }
        if cardsList != nil {
            unsafe allCache.cardsList = cardsList
            unsafe allCache.cardsDict.removeAll()
            if let cards = cardsList {
                for card in cards {
                    unsafe allCache.cardsDict[card.id] = card
                }
            }
        }
    }
    
    internal func writeBandsList(_ bandsList: [SekaiAPI.Bands.Band]?) {
        lock.lock()
        defer { lock.unlock() }
        if bandsList != nil {
            unsafe allCache.bandsList = bandsList
        }
    }
    
    internal func writeCharactersList(_ charactersList: [SekaiAPI.Characters.PreviewCharacter]?) {
        lock.lock()
        defer { lock.unlock() }
        if charactersList != nil {
            unsafe allCache.charactersList = charactersList
        }
    }
    
    internal func read() -> SekaiFrontend._FilterCache {
        lock.lock()
        defer { lock.unlock() }
        return unsafe allCache
    }
    
    internal func erase() {
        lock.lock()
        defer { lock.unlock() }
        unsafe allCache = .init()
    }
}

// MARK: extension PreviewEvent
// Attribute, Character, Server, Timeline Status, Event Type
extension SekaiAPI.Events.PreviewEvent: SekaiFrontend.Filterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] {
        [.attribute, .character, .characterRequiresMatchAll, .server, .timelineStatus, .eventType]
    }
    
    public func _matches<ValueType>(_ value: ValueType, withCache: SekaiFrontend._FilterCache? = nil) -> Bool? {
        if let attribute = value as? SekaiFrontend.Filter.Attribute { // Attribute
            return self.attributes.contains { $0.attribute == attribute }
        } else if let character = value as? SekaiFrontend.Filter.Character { // Character
            return self.characters.contains { $0.characterID == character.rawValue }
        } else if let server = value as? SekaiFrontend.Filter.Server { // Server
            return self.startAt.availableInLocale(server)
        } else if let timelineStatusWithServers = value as? TimelineStatusWithServers { // Timeline Status with Servers
            switch timelineStatusWithServers.timelineStatus {
            case .ended:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.endAt.forLocale(singleLocale) ?? dateOfYear2100) < .now {
                        return true
                    }
                }
            case .ongoing:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.startAt.forLocale(singleLocale) ?? dateOfYear2100) < .now
                        && (self.endAt.forLocale(singleLocale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            case .upcoming:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.startAt.forLocale(singleLocale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            }
            return false
        } else if let eventType = value as? SekaiFrontend.Filter.EventType { // Event Type
            return self.eventType == eventType
        } else {
            return nil // Unexpected: unexpected value type
        }
    }
}

// MARK: extension PreviewGacha
// Attribute, Character, Server, Timeline Status, Gacha Type
// Filter Cache Required
extension SekaiAPI.Gachas.PreviewGacha: SekaiFrontend.Filterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] {
        [.attribute, .character, .characterRequiresMatchAll, .server, .timelineStatus, .gachaType]
    }
    
    public func _matches<ValueType>(_ value: ValueType, withCache cache: SekaiFrontend._FilterCache?) -> Bool? {
        if let attribute = value as? SekaiFrontend.Filter.Attribute { // Attribute
            guard let cards = cache?.cardsDict else {
                unsafe os_log("[Filter][Gacha] Found `nil` while trying to read card cache.")
                return nil
            }
            let containingAttributes = self.newCards.compactMap { cards[$0]?.attribute }
            return containingAttributes.contains(attribute)
        } else if let character = value as? SekaiFrontend.Filter.Character { // Character
            guard let cards = cache?.cardsDict else {
                unsafe os_log("[Filter][Gacha] Found `nil` while trying to read card cache.")
                return nil
            }
            let containingCharacterIDs = self.newCards.compactMap { cards[$0]?.characterID }
            return containingCharacterIDs.contains(character.rawValue)
        } else if let server = value as? SekaiFrontend.Filter.Server { // Server
            return (self.publishedAt.forLocale(server) ?? dateOfYear2100) < .now
        } else if let timelineStatusWithServers = value as? TimelineStatusWithServers { // Timeline Status with Servers
            switch timelineStatusWithServers.timelineStatus {
            case .ended:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.closedAt.forLocale(singleLocale) ?? dateOfYear2100) < .now {
                        return true
                    }
                }
            case .ongoing:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.publishedAt.forLocale(singleLocale) ?? dateOfYear2100) < .now
                        && (self.closedAt.forLocale(singleLocale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            case .upcoming:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.publishedAt.forLocale(singleLocale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            }
            return false
        } else if let gachaType = value as? SekaiFrontend.Filter.GachaType { // Gacha Type
            return self.type == gachaType
        } else {
            return nil // Unexpected: unexpected value type
        }
    }
}

// MARK: extension PreviewCard
// Attribute, Rarity, Character, Server, Availability, Card Type, Skill
extension SekaiFrontend.Cards.PreviewCard: SekaiFrontend.Filterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] {
        [.attribute, .rarity, .character, .server, .released, .cardType, .skill]
    }
    
    public func _matches<ValueType>(_ value: ValueType, withCache cache: SekaiFrontend._FilterCache?) -> Bool? { // Band
        if let attribute = value as? SekaiFrontend.Filter.Attribute { // Attribute
            return self.attribute.rawValue.contains(attribute.rawValue)
        } else if let rarity = value as? SekaiFrontend.Filter.Rarity { // Rarity
            return self.rarity == rarity
        } else if let character = value as? SekaiFrontend.Filter.Character { // Character
            return self.characterID == character.rawValue
        } else if let server = value as? SekaiFrontend.Filter.Server { // Server
            return self.title.availableInLocale(server)
        } else if let availabilityWithServers = value as? AvailabilityWithServers { // Availability
            for locale in availabilityWithServers.servers {
                if availabilityWithServers.releaseStatus.boolValue {
                    if (self.releasedAt.forLocale(locale) ?? dateOfYear2100) < .now {
                        return true
                    }
                } else {
                    if (self.releasedAt.forLocale(locale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            }
            return false
        } else if let cardType = value as? SekaiFrontend.Filter.CardType { // Card Type
            return self.type == cardType
        } else if let skill = value as? SekaiFrontend.Filter.Skill { // Skill
            return self.skillID == skill.id
        } else {
            return nil // Unexpected: unexpected value type
        }
    }
}

// MARK: extension CardWithBand
// Band, Attribute, Rarity, Character, Server, Availability, Card Type, Skill
extension SekaiFrontend.Cards.CardWithBand: SekaiFrontend.Filterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] {
        [.band, .attribute, .rarity, .character, .server, .released, .cardType, .skill]
    }
    
    public func _matches<ValueType>(_ value: ValueType, withCache cache: SekaiFrontend._FilterCache?) -> Bool? { // Band
        if let band = value as? SekaiFrontend.Filter.FullBand { // Band - Full
            return plainBandID(from: self.band.id) == band.rawValue
        } else if let attribute = value as? SekaiFrontend.Filter.Attribute { // Attribute
            return self.card.attribute.rawValue.contains(attribute.rawValue)
        } else if let rarity = value as? SekaiFrontend.Filter.Rarity { // Rarity
            return self.card.rarity == rarity
        } else if let character = value as? SekaiFrontend.Filter.Character { // Character
            return self.card.characterID == character.rawValue
        } else if let server = value as? SekaiFrontend.Filter.Server { // Server
            return self.card.title.availableInLocale(server)
        } else if let availabilityWithServers = value as? AvailabilityWithServers { // Availability
            for locale in availabilityWithServers.servers {
                if availabilityWithServers.releaseStatus.boolValue {
                    if (self.card.releasedAt.forLocale(locale) ?? dateOfYear2100) < .now {
                        return true
                    }
                } else {
                    if (self.card.releasedAt.forLocale(locale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            }
            return false
        } else if let cardType = value as? SekaiFrontend.Filter.CardType { // Card Type
            return self.card.type == cardType
        } else if let skill = value as? SekaiFrontend.Filter.Skill { // Skill
            return self.card.skillID == skill.id
        } else {
            return nil // Unexpected: unexpected value type
        }
    }
}

// MARK: extension PreviewSong
// Band, Server, Timeline Status, Song Type, Level
extension SekaiAPI.Songs.PreviewSong: SekaiFrontend.Filterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] {
        [.band, .bandMatchesOthers, .server, .songAvailability, .songType, .level]
    }
    
    public func _matches<ValueType>(_ value: ValueType, withCache cache: SekaiFrontend._FilterCache?) -> Bool? {
        if let band = value as? SekaiFrontend.Filter.FullBand { // Band - Full
            return plainBandID(from: self.bandID) == band.rawValue
        } else if let server = value as? SekaiFrontend.Filter.Server { // Server
            return (self.publishedAt.forLocale(server) ?? dateOfYear2100) < .now
        } else if let timelineStatusWithServers = value as? TimelineStatusWithServers { // Timeline Status
            switch timelineStatusWithServers.timelineStatus {
            case .ended:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.closedAt.forLocale(singleLocale) ?? dateOfYear2100) < .now {
                        return true
                    }
                }
            case .ongoing:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.publishedAt.forLocale(singleLocale) ?? dateOfYear2100) < .now
                        && (self.closedAt.forLocale(singleLocale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            case .upcoming:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.publishedAt.forLocale(singleLocale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            }
            return false
        } else if let songType = value as? SekaiFrontend.Filter.SongType { // Song Type
            return self.tag == songType
        } else if let level = value as? SekaiFrontend.Filter.Level { // Level
            return self.difficulty.contains(where: { $0.value.playLevel == level })
        } else {
            return nil // Unexpected: unexpected value type
        }
    }
}

// MARK: extension PreivewCampaign
// Server, Timeline Status, Login Campaign Type
extension SekaiAPI.LoginCampaigns.PreviewCampaign: SekaiFrontend.Filterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] {
        [.server, .timelineStatus, .loginCampaignType]
    }
    
    public func _matches<ValueType>(_ value: ValueType, withCache: SekaiFrontend._FilterCache?) -> Bool? {
        if let server = value as? SekaiFrontend.Filter.Server { // Server
            return self.publishedAt.availableInLocale(server)
        } else if let timelineStatusWithServers = value as? TimelineStatusWithServers { // Timeline Status with Servers
            switch timelineStatusWithServers.timelineStatus {
            case .ended:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.closedAt.forLocale(singleLocale) ?? dateOfYear2100) < .now {
                        return true
                    }
                }
            case .ongoing:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.publishedAt.forLocale(singleLocale) ?? dateOfYear2100) < .now
                        && (self.closedAt.forLocale(singleLocale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            case .upcoming:
                for singleLocale in timelineStatusWithServers.servers {
                    if (self.publishedAt.forLocale(singleLocale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            }
            return false
        } else if let campaignType = value as? SekaiFrontend.Filter.LoginCampaignType { // Login Campaign Type
            return self.loginBonusType.rawValue == campaignType.rawValue
        } else {
            return nil 
        }
    }
}

// MARK: extension Comic
// Character, Server, Comic Type
extension SekaiAPI.Comics.Comic: SekaiFrontend.Filterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] {
        [.character, .characterRequiresMatchAll, .server, .comicType]
    }
    
    public func _matches<ValueType>(_ value: ValueType, withCache: SekaiFrontend._FilterCache?) -> Bool? {
        if let character = value as? SekaiFrontend.Filter.Character { // Character
            return self.characterIDs.contains(character.rawValue)
        } else if let server = value as? SekaiFrontend.Filter.Server { // Server
            return self.publicStartAt.availableInLocale(server)
        } else if let comicType = value as? SekaiFrontend.Filter.ComicType { // Comic Type
            return self.type == comicType
        } else {
            return nil // Unexpected: unexpected value type
        }
    }
}

// MARK: extension PreviewCostume
// Band, Character, Server, Availability
// Filter Cache Required
extension SekaiFrontend.Costumes.PreviewCostume: SekaiFrontend.Filterable {
    @inlinable
    public static var applicableFilteringKeys: [SekaiFrontend.Filter.Key] {
        [.band, .character, .server, .released]
    }
    
    public func _matches<ValueType>(_ value: ValueType, withCache cache: SekaiFrontend._FilterCache?) -> Bool? {
        if let band = value as? SekaiFrontend.Filter.FullBand { // Band - Full
            guard let characters = cache?.charactersList else {
                unsafe os_log("[Filter][Costume] Found `nil` while trying to read characters cache.")
                return nil
            }
            return band.rawValue == characters.first(where: { $0.id == self.characterID })?.bandID
        } else if let character = value as? SekaiFrontend.Filter.Character { // Character
            return self.characterID == character.rawValue
        } else if let server = value as? SekaiFrontend.Filter.Server { // Server
            return self.description.availableInLocale(server)
        } else if let availabilityWithServers = value as? AvailabilityWithServers { // Availability
            for locale in availabilityWithServers.servers {
                if availabilityWithServers.releaseStatus.boolValue {
                    if (self.publishedAt.forLocale(locale) ?? dateOfYear2100) < .now {
                        return true
                    }
                } else {
                    if (self.publishedAt.forLocale(locale) ?? .init(timeIntervalSince1970: 0)) > .now {
                        return true
                    }
                }
            }
            return false
        } else {
            return nil 
        }
    }
}

// MARK: extension Array
extension Array where Element: SekaiFrontend.Filterable {
    // Terms of Art... --@ThreeManager785
    /// Returns an array containing, in order, the elements of the array
    /// that satisfy constraints from the given ``SekaiFrontend/Filter``.
    ///
    /// - Parameter filter: A filter that used for filtering the array.
    /// - Returns: An array of the elements that `filter` allowed.
    public func filter(withSekaiFilter filter: SekaiFrontend.Filter) -> [Element] {
        var result: [Element] = self
        guard filter.isFiltered else { return result }
        let cacheCopy: SekaiFrontend._FilterCache = FilterCacheManager.shared.read()
        
        // Breaking them up for type-check. Annoying. --@ThreeManager785
        result = result.filter { element in // Band
            guard (filter.band != Set(SekaiFrontend.Filter.Band.allCases) || filter.bandMatchesOthers == .excludeOthers) else { return true }
            var allBands: Set<SekaiFrontend.Filter.FullBand> = Set(filter.band.map({$0.asFullBand()}))
            if filter.bandMatchesOthers == .includeOthers {
                allBands.insert(.others)
            }
            return allBands.contains { band in
                element._matches(band, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Attribute
            guard filter.attribute != Set(SekaiFrontend.Filter.Attribute.allCases) else { return true }
            return filter.attribute.contains { attribute in
                element._matches(attribute, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Rarity
            guard filter.rarity != Set([1, 2, 3, 4, 5]) else { return true }
            return filter.rarity.contains { rarity in
                element._matches(rarity, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Character
            if filter.characterRequiresMatchAll {
                return filter.character.allSatisfy { character in
                    element._matches(character, withCache: cacheCopy) ?? true
                }
            } else {
                guard filter.character != Set(SekaiFrontend.Filter.Character.allCases) else { return true }
                return filter.character.contains { character in
                    element._matches(character, withCache: cacheCopy) ?? true
                }
            }
        }
        result = result.filter { element in // Timeline Status with Servers
            guard filter.timelineStatus != Set(SekaiFrontend.Filter.TimelineStatus.allCases) else { return true }
            return filter.timelineStatus.contains { timelineStatus in
                element._matches(TimelineStatusWithServers(timelineStatus: timelineStatus, servers: filter.server), withCache: cacheCopy) ?? true
            }
        }.filter { element in // Availability with Servers
            guard filter.released != Set([true, false]) else { return true }
            return filter.released.contains { releaseStatus in
                element._matches(AvailabilityWithServers(releaseStatus: releaseStatus, servers: filter.server), withCache: cacheCopy) ?? true
            }
        }
        result = result.filter { element in // Server
            guard filter.server != Set(SekaiFrontend.Filter.Server.allCases) else { return true }
            return filter.server.contains { server in
                element._matches(server, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Event Types
            guard filter.eventType != Set(SekaiFrontend.Filter.EventType.allCases) else { return true }
            return filter.eventType.contains { eventType in
                element._matches(eventType, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Gacha Types
            guard filter.gachaType != Set(SekaiFrontend.Filter.GachaType.allCases) else { return true }
            return filter.gachaType.contains { gachaType in
                element._matches(gachaType, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Card Types
            guard filter.cardType != Set(SekaiFrontend.Filter.CardType.allCases) else { return true }
            return filter.cardType.contains { cardType in
                element._matches(cardType, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Song Types
            guard filter.songType != Set(SekaiFrontend.Filter.SongType.allCases) else { return true }
            return filter.songType.contains { songType in
                element._matches(songType, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Login Campaign Types
            guard filter.loginCampaignType != Set(SekaiFrontend.Filter.LoginCampaignType.allCases) else { return true }
            return filter.loginCampaignType.contains { loginCampaignType in
                element._matches(loginCampaignType, withCache: cacheCopy) ?? true
            }
        }.filter { element in // Comic Types
            guard filter.comicType != Set(SekaiFrontend.Filter.ComicType.allCases) else { return true }
            return filter.comicType.contains { comicType in
                element._matches(comicType, withCache: cacheCopy) ?? true
            }
        }
        result = result.filter { element in // Skill
            guard filter.skill != nil else { return true }
            return element._matches(filter.skill, withCache: cacheCopy) ?? true
        }.filter { element in // Level
            guard filter.level != nil else { return true }
            return element._matches(filter.level, withCache: cacheCopy) ?? true
        }
        return result
    }
    
    mutating func filter(withSekaiFilter filter: SekaiFrontend.Filter) {
        self = self.filter(withSekaiFilter: filter)
    }
}
