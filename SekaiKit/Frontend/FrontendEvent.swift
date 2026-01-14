//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendEvent.swift
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
    /// Request and fetch data about events in Bandori.
    ///
    /// *Events* are periodic activities with new stories in GBP.
    ///
    /// ![Banner image of event:
    /// Hopeful Spring Chocolate Roll Cake](EventExampleImage)
    public enum Events {
        /// Returns latest events for each locales.
        ///
        /// - Returns: Latest events for each locales, nil if failed to fetch.
        public static func localizedLatestEvent() async -> SekaiAPI.LocalizedData<PreviewEvent>? {
            guard let allEvents = await SekaiAPI.Events.all() else { return nil }
            var result = SekaiAPI.LocalizedData<PreviewEvent>(jp: nil, en: nil, tw: nil, cn: nil, kr: nil)
            // Find from latest to earliest.
            let reversedEvents = allEvents.filter { $0.id <= 5000 }.reversed()
            for locale in SekaiAPI.Locale.allCases {
                let availableEvents = reversedEvents.filter { $0.startAt.availableInLocale(locale) }
                if let ongoingEvent = availableEvents.first(where: {
                    $0.startAt.forLocale(locale)! <= .now
                    && $0.endAt.forLocale(locale)!.timeIntervalSinceNow > 0
                }) {
                    // Use ongoing locale firstly
                    result.set(ongoingEvent, forLocale: locale)
                } else {
                    // Otherwise find the event where `startAt` is closest to now
                    result.set(
                        availableEvents.min(by: {
                            abs($0.startAt.forLocale(locale)!.timeIntervalSinceNow)
                            < abs($1.startAt.forLocale(locale)!.timeIntervalSinceNow)
                        }),
                        forLocale: locale
                    )
                }
                if let event = result.forLocale(locale), let endDate = event.endAt.forLocale(locale), endDate < .now {
                    // latest event has ended, but next event is null
                    if let nextEvent = allEvents.first(where: { $0.id == event.id + 1 }) {
                        result.set(nextEvent, forLocale: locale)
                    }
                }
            }
            for locale in SekaiAPI.Locale.allCases where !result.availableInLocale(locale) {
                return nil
            }
            return result
        }
        
        /// List all events.
        ///
        /// - Returns: All events, nil if failed to fetch.
        public static func list() async -> [PreviewEvent]? {
            guard let events = await SekaiAPI.Events.all() else { return nil }
            return events
        }
        
        /// Get a detailed event with related information.
        ///
        /// - Parameter id: The ID of event.
        /// - Returns: The event of requested ID,
        ///     with related bands, characters, cards, gacha, songs and degrees.
        public static func extendedInformation(of id: Int) async -> ExtendedEvent? {
            let groupResult = await withTasksResult {
                await SekaiAPI.Events.detail(of: id)
            } _: {
                await SekaiAPI.Bands.all()
            } _: {
                await SekaiAPI.Characters.all()
            } _: {
                await SekaiAPI.Cards.all()
            } _: {
                await SekaiAPI.Gachas.all()
            } _: {
                await SekaiAPI.Songs.all()
            } _: {
                await SekaiAPI.Degrees.all()
            }
            guard let event = groupResult.0 else { return nil }
            guard let bands = groupResult.1 else { return nil }
            guard let characters = groupResult.2 else { return nil }
            guard let cards = groupResult.3 else { return nil }
            guard let gacha = groupResult.4 else { return nil }
            guard let songs = groupResult.5 else { return nil }
            guard let degrees = groupResult.6 else { return nil }
            
            let resultCharacters = characters.filter { character in event.characters.contains { $0.characterID == character.id } }
            
            guard let eventLocale = event.startAt.availableLocale() else {
                return nil
            }
            
            var groupedDegrees: [[SekaiAPI.Degrees.Degree]] = []
            if let rewards = event.rankingRewards.forLocale(
                event.rankingRewards.availableLocale(prefer: .jp) ?? .jp
            ) {
                var partialResult: [SekaiAPI.Degrees.Degree] = []
                for reward in rewards where reward.reward.type == .degree {
                    if let degree = degrees.first(where: { $0.id == reward.reward.itemID }) {
                        _onFastPath()
                        partialResult.append(degree)
                    } else {
                        logger.fault("""
                        Event info has declared a degree as reward, \
                        but the degree doesn't appear in the list. \
                        Please file a bug report.
                        """)
                    }
                }
                if !partialResult.isEmpty {
                    groupedDegrees.append(partialResult)
                }
            }
            if let musics = event.musics?.forLocale(
                event.musics?.availableLocale(prefer: .jp) ?? .jp
            ) {
                for music in musics {
                    var partialResult: [SekaiAPI.Degrees.Degree] = []
                    for reward in music.rankingRewards where reward.reward.type == .degree {
                        if let degree = degrees.first(where: { $0.id == reward.reward.itemID }) {
                            _onFastPath()
                            partialResult.append(degree)
                        } else {
                            logger.fault("""
                            Event info has declared a degree as reward, \
                            but the degree doesn't appear in the list. \
                            Please file a bug report.
                            """)
                        }
                    }
                    if !partialResult.isEmpty {
                        groupedDegrees.append(partialResult)
                    }
                }
            }
            
            return .init(
                id: id,
                event: event,
                bands: bands.filter { band in resultCharacters.contains { $0.bandID == band.id } },
                characters: resultCharacters,
                cards: cards.filter { card in event.rewardCards.contains(card.id) || event.members.contains { $0.situationID == card.id } },
                gacha: gacha.filter {
                    event.startAt.forLocale(eventLocale)!...event.endAt.forLocale(eventLocale)!
                    ~= ($0.publishedAt.forLocale(eventLocale) ?? .init(timeIntervalSince1970: 0))
                },
                songs: songs.filter {
                    event.startAt.forLocale(eventLocale)!...event.endAt.forLocale(eventLocale)!
                    ~= ($0.publishedAt.forLocale(eventLocale) ?? .init(timeIntervalSince1970: 0))
                },
                eventSongs: event.musics?.map { musics in
                    if let musics {
                        let musicIDs = musics.map { $0.id }
                        return songs.filter { musicIDs.contains($0.id) }
                    } else {
                        return nil
                    }
                },
                degrees: groupedDegrees
            )
        }
        
        /// Returns top 10 data of an event.
        ///
        /// - Parameters:
        ///   - id: ID of the event.
        ///   - locale: Locale for event data.
        ///   - interval: Interval of each data, the default value is 0.
        /// - Returns: Top 10 data of requested event, nil if failed to fetch.
        ///
        /// - SeeAlso:
        ///     See ``trackerData(for:in:tier:smooth:)-(PreviewEvent,_,_,_)``
        ///     for cutoff data of tier *20, 30, 40, 50, 100, 200, 300, 400, 500, 1000, 2000, 3000, 4000, 5000, 10000, 20000 and 30000*.
        public static func topData(of id: Int, in locale: SekaiAPI.Locale, interval: TimeInterval = 0) async -> [TopData]? {
            let groupResult = await withTasksResult {
                await SekaiAPI.Events.topData(of: id, in: locale, interval: interval)
            } _: {
                await SekaiAPI.Cards.all()
            } _: {
                await SekaiAPI.Degrees.all()
            }
            guard let data = groupResult.0 else { return nil }
            guard let cards = groupResult.1 else { return nil }
            guard let degrees = groupResult.2 else { return nil }
            
            var result = [TopData]()
            for user in data.users {
                result.append(.init(
                    uid: user.uid,
                    name: user.name,
                    introduction: user.introduction,
                    rank: user.rank,
                    card: cards.first { $0.id == user.sid
                    } ?? .init( // dummy
                        id: -1,
                        characterID: -1,
                        rarity: -1,
                        attribute: .powerful,
                        levelLimit: -1,
                        resourceSetName: "",
                        cardName: .init(jp: nil, en: nil, tw: nil, cn: nil, kr: nil),
                        releasedAt: .init(jp: nil, en: nil, tw: nil, cn: nil, kr: nil),
                        skillID: -1,
                        type: .others,
                        stat: .init()
                              ),
                    trained: user.strained,
                    degrees: degrees.filter { user.degrees.contains($0.id) },
                    points: data.points.filter {
                        $0.uid == user.uid
                    }.map {
                        .init(time: $0.time, value: $0.value)
                    }.sorted {
                        $0.time < $1.time
                    }
                ))
            }
            
            return result.sorted { ($0.points.last?.value ?? 0) > ($1.points.last?.value ?? 0) }
        }
        
        /// Returns event tracker data.
        ///
        /// - Parameters:
        ///   - event: The event for tracking.
        ///   - locale: Tracking locale of event.
        ///   - tier: Tracking tier.
        ///   - smooth: Whether smooth the results.
        /// - Returns: The event tracker data for requested event, nil if failed to fetch or arguments are invalid.
        ///
        /// - Note:
        ///     Valid tiers are *20, 30, 40, 50, 100, 200, 300, 400, 500, 1000, 2000, 3000, 4000, 5000, 10000, 20000 and 30000*.
        ///     For data of tier 10, see ``topData(of:in:interval:)``.
        @inlinable
        public static func trackerData(
            for event: PreviewEvent,
            in locale: SekaiAPI.Locale,
            tier: Int,
            smooth: Bool = true
        ) async -> TrackerData? {
            guard let startAt = event.startAt.forLocale(locale) else { return nil }
            guard let endAt = event.endAt.forLocale(locale) else { return nil }
            return await _trackerData(
                of: event.id,
                eventType: event.eventType,
                eventStartDate: startAt,
                eventEndDate: endAt,
                in: locale,
                tier: tier,
                smooth: smooth
            )
        }
        /// Returns event tracker data.
        ///
        /// - Parameters:
        ///   - event: The event for tracking.
        ///   - locale: Tracking locale of event.
        ///   - tier: Tracking tier.
        ///   - smooth: Whether smooth the results.
        /// - Returns: The event tracker data for requested event, nil if failed to fetch or arguments are invalid.
        ///
        /// - Note:
        ///     Valid tiers are *20, 30, 40, 50, 100, 200, 300, 400, 500, 1000, 2000, 3000, 4000, 5000, 10000, 20000 and 30000*.
        ///     For data of tier 10, see ``topData(of:in:interval:)``.
        @inlinable
        public static func trackerData(
            for event: Event,
            in locale: SekaiAPI.Locale,
            tier: Int,
            smooth: Bool = true
        ) async -> TrackerData? {
            guard let startAt = event.startAt.forLocale(locale) else { return nil }
            guard let endAt = event.endAt.forLocale(locale) else { return nil }
            return await _trackerData(
                of: event.id,
                eventType: event.eventType,
                eventStartDate: startAt,
                eventEndDate: endAt,
                in: locale,
                tier: tier,
                smooth: smooth
            )
        }
        public static func _trackerData(
            of id: Int,
            eventType: SekaiAPI.Events.EventType,
            eventStartDate: Date,
            eventEndDate: Date,
            in locale: SekaiAPI.Locale,
            tier: Int,
            smooth: Bool
        ) async -> TrackerData? {
            struct TrackerDataPoint {
                let time: TimeInterval // epoch milliseconds
                let ep: Double
            }
            struct ChartPoint {
                var x: Date
                var y: Double
                var epph: Double? = nil
                var xn: Double? = nil
            }
            func withPrediction(
                _ trackerData: [TrackerDataPoint],
                start: TimeInterval,
                end: TimeInterval,
                rate: Double,
                smooth: Bool
            ) -> (actual: [ChartPoint], predicted: [ChartPoint])? {
                func regression(_ e: [(Double, Double)]) -> (a: Double, b: Double, r2: Double) {
                    var t = 0, a = 0.0, n = 0.0, i = e.count
                    while t < i {
                        a += e[t].0
                        n += e[t].1
                        t += 1
                    }
                    a /= Double(i)
                    n /= Double(i)
                    var r = 0.0, s = 0.0, o = 0.0, l = 0.0
                    t = 0
                    while t < i {
                        o += (e[t].0 - a) * (e[t].1 - n)
                        l += (e[t].0 - a) * (e[t].0 - a)
                        r += (e[t].0 - a) * (e[t].0 - a)
                        s += (e[t].1 - n) * (e[t].1 - n)
                        t += 1
                    }
                    r = sqrt(r / Double(i))
                    s = sqrt(s / Double(i))
                    let d = o / l, u = n - d * a, c = d * r / s
                    return (u, d, c * c)
                }
                
                var actual: [ChartPoint] = []
                var predicted: [ChartPoint] = []
                actual.append(ChartPoint(x: Date(timeIntervalSince1970: TimeInterval(start / 1000)), y: 0))
                predicted.append(ChartPoint(x: Date(timeIntervalSince1970: TimeInterval(start / 1000)), y: Double.infinity))
                var regressionData: [(Double, Double)] = []
                for point in trackerData {
                    let time = point.time
                    let normTime = Double(time - start) / Double(end - start)
                    let last = actual.last!
                    let epph = last.x.timeIntervalSince1970 == TimeInterval(time / 1000) ? nil :
                    Double(point.ep - last.y) / ((Double(time - last.x.timeIntervalSince1970 * 1000)) / 3600000)
                    actual.append(ChartPoint(
                        x: Date(timeIntervalSince1970: TimeInterval(time / 1000)),
                        y: point.ep,
                        epph: epph
                    ))
                    if time - start >= 432_00000 {
                        regressionData.append((normTime, point.ep))
                    }
                    var predictedPoint = ChartPoint(
                        x: Date(timeIntervalSince1970: TimeInterval(time / 1000)),
                        y: Double.infinity,
                        xn: normTime
                    )
                    if time - start >= 864_00000,
                       end - time >= 864_00000,
                       regressionData.count >= 5 {
                        let reg = regression(regressionData)
                        predictedPoint.y = reg.a + reg.b + reg.b * rate
                    }
                    if end - time < 864_00000,
                       let lastPredicted = predicted.last {
                        predictedPoint.y = lastPredicted.y
                    }
                    predicted.append(predictedPoint)
                }
                if smooth {
                    var smoothed: [ChartPoint] = []
                    for (i, pt) in predicted.enumerated() {
                        if pt.y == Double.infinity {
                            smoothed.append(pt)
                        } else {
                            var a = 0.0, b = 0.0
                            for j in 0...i {
                                let p = predicted[j]
                                if p.y != Double.infinity, let xn = p.xn {
                                    let weight = xn * xn
                                    a += p.y * weight
                                    b += weight
                                }
                            }
                            smoothed.append(ChartPoint(x: pt.x, y: a / b))
                        }
                    }
                    predicted = smoothed
                }
                if let lastPred = predicted.last,
                   lastPred.x.timeIntervalSince1970 < TimeInterval(end / 1000),
                   lastPred.y != Double.infinity {
                    predicted.append(ChartPoint(x: Date(timeIntervalSince1970: TimeInterval(end / 1000)), y: lastPred.y))
                }
                return (actual, predicted)
            }
            
            let groupResult = await withTasksResult {
                await SekaiAPI.Events.trackerRates()
            } _: {
                await SekaiAPI.Events.trackerData(of: id, in: locale, tier: tier)
            }
            guard let rates = groupResult.0 else { return nil }
            guard let trackerData = groupResult.1 else { return nil }
            
            guard let rate = rates.first(where: { $0.type == eventType && $0.server == locale && $0.tier == tier }) else { return nil }
            guard let raw = withPrediction(
                trackerData.cutoffs.map { TrackerDataPoint(time: $0.time.timeIntervalSince1970 * 1000, ep: Double($0.ep)) },
                start: eventStartDate.timeIntervalSince1970 * 1000,
                end: eventEndDate.timeIntervalSince1970 * 1000,
                rate: rate.rate,
                smooth: smooth
            ) else { return nil }
            let cutoffs = raw.actual.map { TrackerData.DataPoint(time: $0.x, ep: Int($0.y), epph: $0.xn != nil ? Int($0.xn!) : nil) }
            let predictions = raw.predicted.map { TrackerData.DataPoint(time: $0.x, ep: $0.y.isFinite ? Int($0.y) : nil, epph: $0.xn != nil ? Int($0.xn!) : nil) }
            return .init(cutoffs: cutoffs, predictions: predictions)
        }
    }
}

extension SekaiFrontend.Events {
    public typealias PreviewEvent = SekaiAPI.Events.PreviewEvent
    public typealias Event = SekaiAPI.Events.Event
    
    /// Represent an extended event.
    public struct ExtendedEvent: Sendable, Identifiable, Hashable, SekaiCache.Cacheable {
        /// A unique ID of event.
        public var id: Int
        /// The base event information.
        public var event: Event
        /// The bands that participate in this event.
        public var bands: [SekaiAPI.Bands.Band]
        /// The characters that participate in this event.
        public var characters: [SekaiAPI.Characters.PreviewCharacter]
        /// The cards that related to this event.
        public var cards: [SekaiAPI.Cards.PreviewCard]
        /// The gacha that related to relating cards to this event.
        public var gacha: [SekaiAPI.Gachas.PreviewGacha]
        /// The songs that were released during this event.
        public var songs: [SekaiAPI.Songs.PreviewSong]
        /// The songs that presents in the `musics` property in the event.
        public var eventSongs: SekaiAPI.LocalizedData<[SekaiAPI.Songs.PreviewSong]>?
        /// The degrees that related to this event.
        ///
        /// The degrees are grouped into several arrays.
        /// Degrees in the same inner array are related.
        public var degrees: [[SekaiAPI.Degrees.Degree]]
    }
    
    /// Represent data of a user of top 10 in an event.
    public struct TopData: Sendable, Hashable, SekaiCache.Cacheable {
        /// A unique ID of user.
        public var uid: Int
        /// The name of user.
        public var name: String
        /// The custom introduction text of user.
        public var introduction: String
        /// The rank of user.
        public var rank: Int
        /// The card that is set to main by the user.
        public var card: SekaiAPI.Cards.PreviewCard
        /// A boolean value that indicates whether the ``card`` is trained.
        public var trained: Bool
        /// The degrees that the user displaying.
        public var degrees: [SekaiAPI.Degrees.Degree]
        /// Time-related points data in an event of the user.
        public var points: [Point]
        
        /// Represent a time-related event point data.
        public struct Point: Sendable, Hashable, SekaiCache.Cacheable {
            /// The time that binded to ``value``
            public var time: Date
            /// The event point value.
            public var value: Int
        }
    }
    
    /// Represent tracking data of an event.
    public struct TrackerData: Sendable, Hashable, SekaiCache.Cacheable {
        /// An array that contains all cutoff information in different time.
        public var cutoffs: [DataPoint]
        /// An array that contains all prediction information in different time.
        public var predictions: [DataPoint]
        
        /// Represent an event tracking data in some time.
        public struct DataPoint: Sendable, Hashable, SekaiCache.Cacheable {
            /// The time that binded to this data.
            public var time: Date
            /// The event point value.
            public var ep: Int?
            /// The event point increased in an hour.
            public var epph: Int?
        }
    }
}

extension SekaiFrontend.Events.ExtendedEvent {
    @inlinable
    public init?(id: Int) async {
        if let event = await SekaiFrontend.Events.extendedInformation(of: id) {
            self = event
        } else {
            return nil
        }
    }
}

extension SekaiAPI.Events.EventStory {
    @inlinable
    public func availability(in locale: SekaiAPI.Locale) -> Bool {
        stories.first?.title.availableInLocale(locale) ?? false
    }
}
