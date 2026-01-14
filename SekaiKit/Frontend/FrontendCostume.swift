//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendCostume.swift
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

#if !os(watchOS)
import WebKit
#endif

extension SekaiFrontend {
    /// Request and fetch data about costume in Bandori.
    ///
    /// *Costumes* are 2D and/or 3D costumes
    /// that related to cards and characters.
    /// A character can put on a costume in GBP
    /// if you have the corresponding card.
    ///
    /// To view the Live2D of a costume, use ``Live2DView``.
    ///
    /// - NOTE:
    ///     *Seasonal costumes* are not provided by methods in this namespace,
    ///     use ``SekaiAPI/Characters/detail(of:)`` to get character details,
    ///     which contains all seaonal costumes for the character.
    ///
    /// ![Costume: This Type of Relationship is Called...](CostumeExampleImage)
    public enum Costumes {
        /// List all costumes.
        ///
        /// - Returns: All costumes, nil if failed to fetch.
        public static func list(filter: Filter = .init()) async -> [PreviewCostume]? {
            let groupResult = await withTasksResult {
                await SekaiAPI.Costumes.all()
            } _: {
                await SekaiAPI.Characters.all()
            }
            guard let costumes = groupResult.0 else { return nil }
            guard let characters = groupResult.1 else { return nil }
            
            FilterCacheManager.shared.writeCharactersList(characters)
            
            return costumes
        }
        
        /// Get a detailed costume with related information.
        ///
        /// - Parameter id: The ID of costume.
        /// - Returns: The costume of requested ID,
        ///     with related character and band.
        public static func extendedInformation(of id: Int) async -> ExtendedCostume? {
            let groupResult = await withTasksResult {
                await SekaiAPI.Costumes.detail(of: id)
            } _: {
                await SekaiAPI.Characters.all()
            } _: {
                await SekaiAPI.Bands.all()
            } _: {
                await SekaiAPI.Cards.all()
            }
            guard let costume = groupResult.0 else { return nil }
            guard let characters = groupResult.1 else { return nil }
            guard let bands = groupResult.2 else { return nil }
            guard let cards = groupResult.3 else { return nil }
            
            let character = characters.first { $0.id == costume.characterID } ?? .init( // dummy
                id: -1,
                characterType: .common,
                characterName: .init(jp: nil, en: nil, tw: nil, cn: nil, kr: nil),
                nickname: .init(jp: nil, en: nil, tw: nil, cn: nil, kr: nil),
                bandID: nil,
                color: nil,
                seasonCostumeList: nil
            )
            return .init(
                costume: costume,
                character: character,
                band: bands.first { $0.id == character.bandID } ?? .init( // dummy
                    id: -1,
                    bandName: .init(jp: nil, en: nil, tw: nil, cn: nil, kr: nil)
                ),
                cards: cards.filter { costume.cards.contains($0.id) }
            )
        }
        
        #if os(watchOS)
        public static func live2dViewer(for id: Int) -> NSObject {
            dlopen("/System/Library/Frameworks/WebKit.framework/WebKit", RTLD_NOW)
            let webView = (NSClassFromString("WKWebView") as! NSObject.Type).init()
            webView.perform(
                NSSelectorFromString("loadRequest:"),
                with: URLRequest(url: URL(string: "https://bestdori.com/tool/live2d/costume/\(id)")!)
            )
            let _userScript = (NSClassFromString("WKUserScript") as! NSObject.Type).init()
            defer { _fixLifetime(_userScript) }
            let _userScriptMethod = _userScript.method(for: NSSelectorFromString("initWithSource:injectionTime:forMainFrameOnly:"))!
            let userScript = unsafeBitCast(_userScriptMethod, to: (@convention(c) (NSObject, Selector, NSString, Int, Bool) -> AnyObject).self)(_userScript, NSSelectorFromString("initWithSource:injectionTime:forMainFrameOnly:"), """
            for (let e of document.getElementsByClassName("columns is-gapless is-mobile is-marginless has-background-primary sticky sticky-nav")) { e.remove() }
            for (let e of document.getElementsByClassName("nav-main")) { e.remove() }
            document.getElementById("Community").remove()
            document.getElementById("comments").remove()
            for (let e of document.getElementsByClassName("max-width-40")) { e.remove() }
            for (let e of document.getElementsByClassName("columns is-mobile")) { e.remove() }
            """, 1, true) as! NSObject
            (webView.value(forKeyPath: "configuration.userContentController") as! NSObject).perform(NSSelectorFromString("addUserScript:"), with: userScript)
            return webView
        }
        #endif
    }
}

extension SekaiFrontend.Costumes {
    public typealias PreviewCostume = SekaiAPI.Costumes.PreviewCostume
    public typealias Costume = SekaiAPI.Costumes.Costume
    
    /// Represent an extended costume.
    public struct ExtendedCostume: Sendable, Identifiable, Hashable, SekaiCache.Cacheable {
        /// The base costume information.
        public var costume: Costume
        /// The character who takes this costume.
        public var character: SekaiAPI.Characters.PreviewCharacter
        /// The band that the character taking this costume belongs to.
        public var band: SekaiAPI.Bands.Band
        /// The cards of the character who takes this costume.
        public var cards: [SekaiAPI.Cards.PreviewCard]
        
        /// A unique ID of costume.
        @inlinable
        public var id: Int {
            costume.id
        }
    }
}

extension SekaiFrontend.Costumes.ExtendedCostume {
    @inlinable
    public init?(id: Int) async {
        if let costume = await SekaiFrontend.Costumes.extendedInformation(of: id) {
            self = costume
        } else {
            return nil
        }
    }
}
