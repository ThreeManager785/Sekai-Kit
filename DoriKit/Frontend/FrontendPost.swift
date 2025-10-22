//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendPost.swift
//
// This source file is part of the Greatdori! open source project
//
// Copyright (c) 2025 the Greatdori! project authors
// Licensed under Apache License v2.0
//
// See https://greatdori.memz.top/LICENSE.txt for license information
// See https://greatdori.memz.top/CONTRIBUTORS.txt for the list of Greatdori! project authors
//
//===----------------------------------------------------------------------===//

#if HAS_BINARY_RESOURCE_BUNDLES

import Foundation

extension DoriAPI.Post.Post {
    public var parent: Parent? {
        get async {
            await provideParent(for: self)
        }
    }
    
    public enum Parent: Sendable, Hashable {
        case post(DoriAPI.Post.BasicData)
        case news(DoriAPI.News.Item)
        case character(DoriAPI.Character.Character)
        case card(DoriAPI.Card.Card)
        case costume(DoriAPI.Costume.Costume)
        case event(DoriAPI.Event.Event)
        case gacha(DoriAPI.Gacha.Gacha)
        case song(DoriAPI.Song.Song)
        case loginCampaign(DoriAPI.LoginCampaign.Campaign)
        case comic(DoriAPI.Comic.Comic)
        case eventTracker(DoriAPI.Event.Event)
        case chartSimulator(DoriAPI.Song.Song)
        case live2d(URL)
        case story(DoriAPI.Misc.StoryAsset)
    }
}

private func provideParent(for post: DoriAPI.Post.Post) async -> DoriAPI.Post.Post.Parent? {
    switch post.categoryName {
    case .selfPost:
        return nil
    case .postComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Post.basicData(of: id) {
            return .post(data)
        } else {
            return nil
        }
    case .newsComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.News.detail(of: id) {
            return .news(data)
        } else {
            return nil
        }
    case .characterComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Character.detail(of: id) {
            return .character(data)
        } else {
            return nil
        }
    case .cardComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Card.detail(of: id) {
            return .card(data)
        } else {
            return nil
        }
    case .costumeComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Costume.detail(of: id) {
            return .costume(data)
        } else {
            return nil
        }
    case .eventComment, .eventArchiveComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Event.detail(of: id) {
            return .event(data)
        } else {
            return nil
        }
    case .gachaComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Gacha.detail(of: id) {
            return .gacha(data)
        } else {
            return nil
        }
    case .songComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Song.detail(of: id) {
            return .song(data)
        } else {
            return nil
        }
    case .loginCampaignComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.LoginCampaign.detail(of: id) {
            return .loginCampaign(data)
        } else {
            return nil
        }
    case .comicComment:
        if let id = Int(post.categoryID),
           let allComics = await DoriAPI.Comic.all(),
           let data = allComics.first(where: { $0.id == id }) {
            return .comic(data)
        } else {
            return nil
        }
    case .eventTrackerComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Event.detail(of: id) {
            return .eventTracker(data)
        } else {
            return nil
        }
    case .chartSimulatorComment:
        if let id = Int(post.categoryID),
           let data = await DoriAPI.Song.detail(of: id) {
            return .chartSimulator(data)
        } else {
            return nil
        }
    case .live2dComment:
        return .live2d(.init(string: "https://bestdori.com/assets/jp/\(post.categoryID)_rip/buildData.asset")!.respectOfflineAssetContext())
    case .storyComment:
        let request = await requestJSON("https://bestdori.com/assets/jp\(post.categoryID)")
        if case let .success(respJSON) = request {
            return .story(await DoriAPI.Misc._parseStoryAsset(respJSON))
        } else {
            return nil
        }
    }
}

#endif // HAS_BINARY_RESOURCE_BUNDLES
