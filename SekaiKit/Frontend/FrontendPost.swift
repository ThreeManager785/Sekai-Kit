//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendPost.swift
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

#if HAS_BINARY_RESOURCE_BUNDLES

import Foundation

extension SekaiAPI.Posts.PagedPosts: AsyncSequence {
    public func makeAsyncIterator() -> AsyncIterator {
        if let request = self._source {
            .init(count: total, request: request, currentElements: content)
        } else {
            preconditionFailure()
        }
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        internal var position: Int
        internal var count: Int
        internal var request: SekaiAPI.Posts.ListRequest
        internal var buffer: [Element]
        
        internal init(count: Int, request: SekaiAPI.Posts.ListRequest, currentElements: [Element]) {
            self.position = request.offset % request.limit
            self.count = count
            self.request = request
            self.buffer = currentElements
        }
        
        public mutating func next() async throws -> SekaiAPI.Posts.Post? {
            defer {
                position += 1
                request.offset += 1
            }
            if position >= buffer.count {
                if request.offset <= request.limit {
                    if let newList = await SekaiAPI.Posts._list(request) {
                        buffer = newList.content
                        count = newList.total
                        position = 0
                    } else {
                        throw NSError(domain: "com.memz233.SekaiKit", code: 0x0809)
                    }
                } else {
                    return nil
                }
            }
            return buffer[position]
        }
    }
}

extension SekaiAPI.Posts.Post {
    public var parent: Parent? {
        get async {
            await provideParent(for: self)
        }
    }
    
    public enum Parent: Sendable, Hashable {
        case post(SekaiAPI.Posts.BasicData)
        case news(SekaiAPI.News.Item)
        case character(SekaiAPI.Characters.Character)
        case card(SekaiAPI.Cards.Card)
        case costume(SekaiAPI.Costumes.Costume)
        case event(SekaiAPI.Events.Event)
        case gacha(SekaiAPI.Gachas.Gacha)
        case song(SekaiAPI.Songs.Song)
        case loginCampaign(SekaiAPI.LoginCampaigns.Campaign)
        case comic(SekaiAPI.Comics.Comic)
        case eventTracker(SekaiAPI.Events.Event)
        case chartSimulator(SekaiAPI.Songs.Song)
        case live2d(URL)
        case story(SekaiAPI.Misc.StoryAsset)
    }
}

private func provideParent(for post: SekaiAPI.Posts.Post) async -> SekaiAPI.Posts.Post.Parent? {
    switch post.categoryName {
    case .selfPost:
        return nil
    case .postComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Posts.basicData(of: id) {
            return .post(data)
        } else {
            return nil
        }
    case .newsComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.News.detail(of: id) {
            return .news(data)
        } else {
            return nil
        }
    case .characterComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Characters.detail(of: id) {
            return .character(data)
        } else {
            return nil
        }
    case .cardComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Cards.detail(of: id) {
            return .card(data)
        } else {
            return nil
        }
    case .costumeComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Costumes.detail(of: id) {
            return .costume(data)
        } else {
            return nil
        }
    case .eventComment, .eventArchiveComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Events.detail(of: id) {
            return .event(data)
        } else {
            return nil
        }
    case .gachaComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Gachas.detail(of: id) {
            return .gacha(data)
        } else {
            return nil
        }
    case .songComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Songs.detail(of: id) {
            return .song(data)
        } else {
            return nil
        }
    case .loginCampaignComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.LoginCampaigns.detail(of: id) {
            return .loginCampaign(data)
        } else {
            return nil
        }
    case .comicComment:
        if let id = Int(post.categoryID),
           let allComics = await SekaiAPI.Comics.all(),
           let data = allComics.first(where: { $0.id == id }) {
            return .comic(data)
        } else {
            return nil
        }
    case .eventTrackerComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Events.detail(of: id) {
            return .eventTracker(data)
        } else {
            return nil
        }
    case .chartSimulatorComment:
        if let id = Int(post.categoryID),
           let data = await SekaiAPI.Songs.detail(of: id) {
            return .chartSimulator(data)
        } else {
            return nil
        }
    case .live2dComment:
        return .live2d(.init(string: "https://bestdori.com/assets/jp/\(post.categoryID)_rip/buildData.asset")!.respectOfflineAssetContext())
    case .storyComment:
        let request = await requestJSON("https://bestdori.com/assets/jp\(post.categoryID)")
        if case let .success(respJSON) = request {
            return .story(await SekaiAPI.Misc._parseStoryAsset(respJSON))
        } else {
            return nil
        }
    }
}

#endif // HAS_BINARY_RESOURCE_BUNDLES
