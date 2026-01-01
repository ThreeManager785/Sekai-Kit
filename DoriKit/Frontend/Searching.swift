//===---*- Greatdori! -*---------------------------------------------------===//
//
// Searching.swift
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

extension DoriFrontend {
    /// A type that can be searched when in a collection.
    public protocol Searchable: Identifiable {
        var _searchStrings: [String] { get }
        var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] { get }
        var _searchIntegers: [Int] { get }
        var _searchLocales: [DoriAPI.Locale] { get }
        var _searchBands: [DoriAPI.Bands.Band] { get }
        var _searchAttributes: [DoriAPI.Attribute] { get }
    }
}

extension DoriFrontend.Searchable {
    public var _searchStrings: [String] { [] }
    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] { [] }
    public var _searchIntegers: [Int] { [] }
    public var _searchLocales: [DoriAPI.Locale] { [] }
    public var _searchBands: [DoriAPI.Bands.Band] { [] }
    public var _searchAttributes: [DoriAPI.Attribute] { [] }
}

extension Array where Element: DoriFrontend.Searchable {
    /// Returns a new array which is filtered by given keyword.
    ///
    /// - Parameters:
    ///   - keyword: Keyword for searching.
    ///   - locales:
    ///     Locales used to improve searching, sorted by priority.
    ///
    ///     When it's set to an empty array, DoriKit doesn't apply
    ///     locale-specific improments to searching.
    ///     When it's set to `nil`, DoriKit determines
    ///     a locale list automatically.
    /// - Returns: A new array which is filtered by given keyword.
    ///
    /// This function performs a "smart search" like the one on Bestdori! website.
    public func search(for keyword: String, with locales: [Locale]? = []) -> Self {
        let tokens = keyword.split(separator: " ").map { $0.lowercased() }
        guard !tokens.isEmpty else { return self }
        
        let locales = locales ?? Locale.preferredLanguages.compactMap {
            Locale(languageCode: .init($0))
        }
        
        var result = self
        var removes = IndexSet()
        var jpLangTokenizer: CFStringTokenizer!
        var cnLangTokenizer: CFStringTokenizer!
        let keyPattern = keyword.replacing(" ", with: "")
        itemLoop: for (index, item) in result.enumerated() {
            for localizedString in item._searchLocalizedStrings {
                if locales.contains(where: {
                    $0.language.languageCode?.identifier.hasPrefix("ja") == true
                }), let string = localizedString[.jp] {
                    let cfString = string as CFString
                    let range = CFRange(
                        location: 0,
                        length: CFStringGetLength(cfString)
                    )
                    if _fastPath(jpLangTokenizer != nil) {
                        CFStringTokenizerSetString(
                            jpLangTokenizer,
                            cfString,
                            range
                        )
                    } else {
                        jpLangTokenizer = CFStringTokenizerCreate(
                            kCFAllocatorDefault,
                            cfString,
                            range,
                            kCFStringTokenizerUnitWordBoundary,
                            CFLocaleCreate(
                                kCFAllocatorDefault,
                                CFLocaleIdentifier("ja_JP" as CFString)
                            )
                        )
                    }
                    
                    var partialResult = ""
                    var tokenType = CFStringTokenizerAdvanceToNextToken(jpLangTokenizer)
                    while tokenType != [] {
                        if let latin = CFStringTokenizerCopyCurrentTokenAttribute(
                            jpLangTokenizer,
                            kCFStringTokenizerAttributeLatinTranscription
                        ) as? String {
                            partialResult += latin + " "
                        }
                        tokenType = CFStringTokenizerAdvanceToNextToken(jpLangTokenizer)
                    }
                    if !partialResult.isEmpty {
                        partialResult.removeLast()
                    }
                    partialResult = partialResult.applyingTransform(.stripDiacritics, reverse: false) ?? partialResult
                    
//                    if partialResult.replacing(" ", with: "").contains(keyPattern) {
//                        continue itemLoop
//                    }
                    if let hiragana = partialResult.applyingTransform(
                        .latinToHiragana,
                        reverse: false
                    ), hiragana.replacing(" ", with: "").contains(keyPattern) {
                        continue itemLoop
                    }
                }
                if locales.contains(where: {
                    $0.language.languageCode?.identifier.hasPrefix("zh") == true
                }), let string = localizedString[.cn] {
                    let cfString = string as CFString
                    let range = CFRange(
                        location: 0,
                        length: CFStringGetLength(cfString)
                    )
                    if _fastPath(cnLangTokenizer != nil) {
                        CFStringTokenizerSetString(
                            cnLangTokenizer,
                            cfString,
                            range
                        )
                    } else {
                        cnLangTokenizer = CFStringTokenizerCreate(
                            kCFAllocatorDefault,
                            cfString,
                            range,
                            kCFStringTokenizerUnitWord,
                            CFLocaleCreate(
                                kCFAllocatorDefault,
                                CFLocaleIdentifier("zh_CN" as CFString)
                            )
                        )
                    }
                    
                    var partialResult = ""
                    var tokenType = CFStringTokenizerAdvanceToNextToken(cnLangTokenizer)
                    while tokenType != [] {
                        if let latin = CFStringTokenizerCopyCurrentTokenAttribute(
                            cnLangTokenizer,
                            kCFStringTokenizerAttributeLatinTranscription
                        ) as? String {
                            partialResult += latin
                        }
                        tokenType = CFStringTokenizerAdvanceToNextToken(cnLangTokenizer)
                    }
                    partialResult = partialResult.applyingTransform(.stripDiacritics, reverse: false) ?? partialResult
                    
                    if partialResult.contains(keyPattern) {
                        continue itemLoop
                    }
                }
            }
            
            tokenLoop: for token in tokens {
                // We always do early exit for performance
                for string in item._searchStrings {
                    if string.lowercased().contains(token) {
                        continue tokenLoop
                    }
                }
                for localizedString in item._searchLocalizedStrings {
                    for locale in DoriAPI.Locale.allCases {
                        if localizedString.forLocale(locale)?.lowercased().contains(token) == true {
                            continue tokenLoop
                        }
                    }
                }
                for integer in item._searchIntegers {
                    // like 4 for rarity of 4
                    if let intToken = Int(token), integer == intToken {
                        continue tokenLoop
                    }
                    // like 4* for rarity of 4
                    if let intToken = Int(token.dropLast()), integer == intToken {
                        continue tokenLoop
                    }
                    // like 4+, 4*+
                    if token.hasSuffix("+") {
                        var token = token
                        while !token.isEmpty {
                            token.removeLast()
                            if let intToken = Int(token), integer >= intToken {
                                continue tokenLoop
                            }
                        }
                    }
                    // like 4-, 4*-
                    if token.hasSuffix("-") {
                        var token = token
                        while !token.isEmpty {
                            token.removeLast()
                            if let intToken = Int(token), integer <= intToken {
                                continue tokenLoop
                            }
                        }
                    }
                    // like >4, >4*, <4, ...
                    if token.hasPrefix(">") || token.hasPrefix("<") {
                        var token = token
                        while let l = token.last, Int(String(l)) != nil {
                            token.removeLast()
                        }
                        if token.hasPrefix(">") {
                            while !token.isEmpty {
                                token.removeFirst()
                                if let intToken = Int(token), integer >= intToken {
                                    continue tokenLoop
                                }
                            }
                        } else {
                            while !token.isEmpty {
                                token.removeFirst()
                                if let intToken = Int(token), integer <= intToken {
                                    continue tokenLoop
                                }
                            }
                        }
                    }
                }
                let server: DoriAPI.Locale? = switch token {
                case "japan", "japanese", "jp": .jp
                case "worldwide", "english", "ww", "en": .en
                case "taiwan", "tw": .tw
                case "china", "chinese", "cn": .cn
                case "korea", "korean", "kr": .kr
                default: nil
                }
                if let server {
                    if item._searchLocales.contains(server) {
                        continue tokenLoop
                    }
                }
                let band: String? = switch token {
                case "popipa", "poppin", "poppin'party", "party", "ppp":
                    "Poppin'Party"
                case "afterglow", "ag", "after", "glow":
                    "Afterglow"
                case "hhw", "hello", "happy", "world", "ハロー、ハッピーワールド",
                    "ハロー", "ハッピーワールド", "ハロー、ハッピーワールド！",
                    "hello，happyworld", "hello，happyworld！",
                    "hello,happyworld!":
                    "ハロー、ハッピーワールド！"
                case "pastel＊palettes", "pastel", "palettes", "pp",
                    "＊", "*", "pastel*palettes":
                    "Pastel＊Palettes"
                case "roselia", "rose", "r":
                    "Roselia"
                case "raiseasuilen", "ras", "raise", "suilen":
                    "RAISE A SUILEN"
                case "morfonica", "mor", "foni":
                    "Morfonica"
                case "mygo!!!!!", "mygo", "my", "go", "!!!!!":
                    "MyGO!!!!!"
                default: nil
                }
                if let band {
                    if item._searchBands.contains(where: { $0.bandName.forLocale(.jp) == band }) {
                        continue tokenLoop
                    }
                }
                let attribute: DoriAPI.Attribute? = switch token {
                case "powerful", "power", "red", "パワフル", "红", "紅": .powerful
                case "pure", "green", "ピュア", "绿", "綠": .pure
                case "cool", "blue", "クール", "蓝", "藍": .cool
                case "happy", "orange", "ハッピー", "橙": .happy
                default: nil
                }
                if let attribute {
                    if item._searchAttributes.contains(attribute) {
                        continue tokenLoop
                    }
                }
                if token.hasPrefix("#"), let intToken = Int(String(token.dropFirst())) {
                    if (item.id as? Int) == intToken {
                        continue tokenLoop
                    }
                }
                removes.insert(index)
            }
        }
        result.remove(atOffsets: removes)
        
        return result
    }
}

extension DoriAPI.Cards.PreviewCard: DoriFrontend.Searchable {
    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
        [
            self.cardName,
            _character?.characterName,
            _character?.nickname.isEmpty == false ? _character?.nickname : nil
        ].compactMap { $0 }
    }
    public var _searchIntegers: [Int] {
        [self.rarity]
    }
    public var _searchLocales: [DoriAPI.Locale] {
        var result = [DoriAPI.Locale]()
        for locale in DoriAPI.Locale.allCases {
            if self.releasedAt.availableInLocale(locale) {
                result.append(locale)
            }
        }
        return result
    }
    public var _searchBands: [DoriAPI.Bands.Band] {
        if let bandID = _character?.bandID {
            PreCache.current.mainBands.filter {
                bandID == $0.id
            }
        } else {
            []
        }
    }
    public var _searchAttributes: [DoriAPI.Attribute] {
        [self.attribute]
    }
    
    private var _character: DoriAPI.Characters.PreviewCharacter? {
        PreCache.current.characters.first {
            $0.id == self.characterID
        }
    }
}
extension DoriAPI.Comics.Comic: DoriFrontend.Searchable {
    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
        [self.title, self.subTitle]
    }
    public var _searchLocales: [DoriAPI.Locale] {
        var result = [DoriAPI.Locale]()
        for locale in DoriAPI.Locale.allCases {
            if self.title.availableInLocale(locale) {
                result.append(locale)
            }
        }
        return result
    }
    public var _searchBands: [DoriAPI.Bands.Band] {
        PreCache.current.mainBands.filter {
            _characters.compactMap { $0.bandID }.contains($0.id)
        }
    }
    
    private var _characters: [DoriAPI.Characters.PreviewCharacter] {
        PreCache.current.characters.filter {
            self.characterIDs.contains($0.id)
        }
    }
}
extension DoriAPI.Costumes.PreviewCostume: DoriFrontend.Searchable {
    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
        [
            self.description,
            _character?.characterName,
            _character?.nickname.isEmpty == false ? _character?.nickname : nil
        ].compactMap { $0 }
    }
    public var _searchLocales: [DoriAPI.Locale] {
        var result = [DoriAPI.Locale]()
        for locale in DoriAPI.Locale.allCases {
            if self.publishedAt.availableInLocale(locale) {
                result.append(locale)
            }
        }
        return result
    }
    public var _searchBands: [DoriAPI.Bands.Band] {
        if let bandID = _character?.bandID {
            PreCache.current.mainBands.filter {
                bandID == $0.id
            }
        } else {
            []
        }
    }
    
    public var _character: DoriAPI.Characters.PreviewCharacter? {
        PreCache.current.characters.first {
            $0.id == self.characterID
        }
    }
}
extension DoriAPI.Events.PreviewEvent: DoriFrontend.Searchable {
    public var _searchStrings: [String] {
        [self.eventType.localizedString]
    }
    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
        [self.eventName]
    }
    public var _searchLocales: [DoriAPI.Locale] {
        var result = [DoriAPI.Locale]()
        for locale in DoriAPI.Locale.allCases {
            if self.startAt.availableInLocale(locale) {
                result.append(locale)
            }
        }
        return result
    }
    public var _searchAttributes: [DoriAPI.Attribute] {
        self.attributes.map { $0.attribute }
    }
}
extension DoriAPI.Gachas.PreviewGacha: DoriFrontend.Searchable {
    public var _searchStrings: [String] {
        [self.type.localizedString]
    }
    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
        [self.gachaName]
    }
    public var _searchLocales: [DoriAPI.Locale] {
        var result = [DoriAPI.Locale]()
        for locale in DoriAPI.Locale.allCases {
            if self.publishedAt.availableInLocale(locale) {
                result.append(locale)
            }
        }
        return result
    }
}
extension DoriAPI.LoginCampaigns.PreviewCampaign: DoriFrontend.Searchable {
    public var _searchStrings: [String] {
        [self.loginBonusType.localizedString]
    }
    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
        [self.caption]
    }
    public var _searchLocales: [DoriAPI.Locale] {
        var result = [DoriAPI.Locale]()
        for locale in DoriAPI.Locale.allCases {
            if self.publishedAt.availableInLocale(locale) {
                result.append(locale)
            }
        }
        return result
    }
}
extension DoriAPI.Songs.PreviewSong: DoriFrontend.Searchable {
    public var _searchStrings: [String] {
        [self.tag.localizedString]
    }
    public var _searchLocalizedStrings: [DoriAPI.LocalizedData<String>] {
        [self.musicTitle]
    }
    public var _searchLocales: [DoriAPI.Locale] {
        var result = [DoriAPI.Locale]()
        for locale in DoriAPI.Locale.allCases {
            if self.publishedAt.availableInLocale(locale) {
                result.append(locale)
            }
        }
        return result
    }
}
