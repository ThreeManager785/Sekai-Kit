//===---*- Greatdori! -*---------------------------------------------------===//
//
// DriverTitleDescribable.swift
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

// MARK: - TitleDescribable

public protocol TitleDescribable {
    var title: LocalizedData<String> { get }
}

extension Band: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.bandName
    }
}

extension PreviewCard: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.cardName
    }
}
extension Card: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.cardName
    }
}
extension ExtendedCard: TitleDescribable {
    public var title: DoriAPI.LocalizedData<String> {
        self.card.cardName
    }
}

extension PreviewCharacter: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.characterName
    }
}
extension BirthdayCharacter: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.characterName
    }
}
extension Character: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.characterName
    }
}
extension ExtendedCharacter: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.character.characterName
    }
}

extension Comic: TitleDescribable {}

extension PreviewCostume: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.description
    }
}
extension Costume: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.description
    }
}
extension ExtendedCostume: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.costume.description
    }
}

extension Degree: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.degreeName
    }
}

extension PreviewEvent: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.eventName
    }
}
extension Event: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.eventName
    }
}
extension ExtendedEvent: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.event.eventName
    }
}

extension PreviewGacha: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.gachaName
    }
}
extension Gacha: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.gachaName
    }
}
extension ExtendedGacha: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.gacha.gachaName
    }
}

extension PreviewLoginCampaign: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.caption
    }
}
extension LoginCampaign: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.caption
    }
}

extension Skill: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.simpleDescription
    }
}

extension PreviewSong: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.musicTitle
    }
}
extension Song: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.musicTitle
    }
}
extension ExtendedSong: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.song.musicTitle
    }
}

extension MiracleTicket: TitleDescribable {
    @inlinable
    public var title: DoriAPI.LocalizedData<String> {
        self.name
    }
}
