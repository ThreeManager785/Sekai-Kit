//===---*- Greatdori! -*---------------------------------------------------===//
//
// OfflineAssetDispatch.swift
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

#if canImport(SekaiAssetShims)

/// Configures requests occuring in closure to match the provided offline asset behavior.
///
/// - Parameters:
///   - behavior: The offline asset behavior in `body`,
///       see ``OfflineAssetBehavior`` for more details.
///   - body: A closure with provided offline asset behavior.
/// - Returns: Result of provided closure.
///
/// This function let requests in provided closure match the `behavior`.
/// You use this function to allow downloaded local assets work with SekaiKit.
///
/// Simply wrap an expression that requests data to configure its offline asset behavior:
/// ```swift
/// let myFavoriteCharacter = await withOfflineAsset {
///     await SekaiAPI.Character.Character(id: 39)
/// }
/// ```
///
/// You can also wrap multiple expressions in a single closure:
/// ```swift
/// await withOfflineAsset {
///     let myFavoriteCharacter = await SekaiAPI.Character.Character(id: 39)
///     let myFavoriteCard = await SekaiAPI.Card.Card(id: 2125)
/// }
/// ```
///
/// Use this function with ``SekaiCache/withCache(id:trait:invocation:)``
/// to let them work together:
/// ```swift
/// SekaiCache.withCache(id: "CacheID") {
///     await withOfflineAsset {
///         await SekaiAPI.Card.Card(id: 2125)
///     }
/// }.onUpdate {
///     let myFavoriteCard = $0
/// }
/// ```
///
/// This function can be put outside of the `invocation` closure
/// of ``SekaiCache/withCache(id:trait:invocation:)``
/// to make it easier to request and cache multiple items:
/// ```swift
/// withOfflineAsset {
///     SekaiCache.withCache(id: "CacheID") {
///         await SekaiAPI.Card.Card(id: 2125)
///     }.onUpdate {
///         let myFavoriteCard = $0
///     }
///     SekaiCache.withCache(id: "AnotherCacheID") {
///         await SekaiAPI.Costume.Costume(id: 2120)
///     }.onUpdate {
///         let coolSoyo = $0
///     }
/// }
/// ```
///
/// If a new task is created in `body`, it inherits the behavior:
/// ```swift
/// await withOfflineAsset(.enabled) {
///     Task {
///         // Configuration is `.enabled`
///         let efficiency = await SekaiAPI.Song.Song(id: 325)
///     }
///     // Configuration is `.enabled`
///     let tanebi = await SekaiAPI.Song.Song(id: 684)
/// }
/// ```
///
/// - IMPORTANT:
///     If a **detached** task is created in `body`, it **drops** the behavior.
///     ```swift
///     await withOfflineAsset(.enabled) {
///         Task.detached {
///             // Configuration is default (`.disabled`)
///             let efficiency = await SekaiAPI.Song.Song(id: 325)
///         }
///         // Configuration is `.enabled`
///         let tanebi = await SekaiAPI.Song.Song(id: 684)
///     }
///     ```
///
/// Resource accesses in `body` also respects the configuration:
/// ```swift
/// await withOfflineAsset {
///     if let itsMyGO = await SekaiAPI.Event.Event(id: 235) {
///         let imageURL = itsMyGO.bannerImageURL
///         // imageURL refers to a local file if available.
///     }
/// }
/// ```
///
/// - SeeAlso:
///     Use ``Foundation/URL/withOfflineAsset(_:)``
///     to set offline asset behavior for URL inline.
public func withOfflineAsset<Result>(
    _ behavior: OfflineAssetBehavior = .enableIfAvailable,
    _ body: () throws -> Result
) rethrows -> Result {
    try SekaiOfflineAsset.$localBehavior.withValue(behavior, operation: body)
}

/// Configures requests occuring in closure to match the provided offline asset behavior.
///
/// - Parameters:
///   - behavior: The offline asset behavior in `body`,
///       see ``OfflineAssetBehavior`` for more details.
///   - body: A closure with provided offline asset behavior.
/// - Returns: Result of provided closure.
///
/// This function let requests in provided closure match the `behavior`.
/// You use this function to allow downloaded local assets work with SekaiKit.
///
/// Simply wrap an expression that requests data to configure its offline asset behavior:
/// ```swift
/// let myFavoriteCharacter = await withOfflineAsset {
///     await SekaiAPI.Character.Character(id: 39)
/// }
/// ```
///
/// You can also wrap multiple expressions in a single closure:
/// ```swift
/// await withOfflineAsset {
///     let myFavoriteCharacter = await SekaiAPI.Character.Character(id: 39)
///     let myFavoriteCard = await SekaiAPI.Card.Card(id: 2125)
/// }
/// ```
///
/// Use this function with ``SekaiCache/withCache(id:trait:invocation:)``
/// to let them work together:
/// ```swift
/// SekaiCache.withCache(id: "CacheID") {
///     await withOfflineAsset {
///         await SekaiAPI.Card.Card(id: 2125)
///     }
/// }.onUpdate {
///     let myFavoriteCard = $0
/// }
/// ```
///
/// This function can be put outside of the `invocation` closure
/// of ``SekaiCache/withCache(id:trait:invocation:)``
/// to make it easier to request and cache multiple items:
/// ```swift
/// withOfflineAsset {
///     SekaiCache.withCache(id: "CacheID") {
///         await SekaiAPI.Card.Card(id: 2125)
///     }.onUpdate {
///         let myFavoriteCard = $0
///     }
///     SekaiCache.withCache(id: "AnotherCacheID") {
///         await SekaiAPI.Costume.Costume(id: 2120)
///     }.onUpdate {
///         let coolSoyo = $0
///     }
/// }
/// ```
///
/// If a new task is created in `body`, it inherits the behavior:
/// ```swift
/// await withOfflineAsset(.enabled) {
///     Task {
///         // Configuration is `.enabled`
///         let efficiency = await SekaiAPI.Song.Song(id: 325)
///     }
///     // Configuration is `.enabled`
///     let tanebi = await SekaiAPI.Song.Song(id: 684)
/// }
/// ```
///
/// - IMPORTANT:
///     If a **detached** task is created in `body`, it **drops** the behavior.
///     ```swift
///     await withOfflineAsset(.enabled) {
///         Task.detached {
///             // Configuration is default (`.disabled`)
///             let efficiency = await SekaiAPI.Song.Song(id: 325)
///         }
///         // Configuration is `.enabled`
///         let tanebi = await SekaiAPI.Song.Song(id: 684)
///     }
///     ```
///
/// Resource accesses in `body` also respects the configuration:
/// ```swift
/// await withOfflineAsset {
///     if let itsMyGO = await SekaiAPI.Event.Event(id: 235) {
///         let imageURL = itsMyGO.bannerImageURL
///         // imageURL refers to a local file if available.
///     }
/// }
/// ```
///
/// - SeeAlso:
///     Use ``Foundation/URL/withOfflineAsset(_:)``
///     to set offline asset behavior for URL inline.
public func withOfflineAsset<Result>(
    _ behavior: OfflineAssetBehavior = .enableIfAvailable,
    isolation: isolated (any Actor)? = #isolation,
    _ body: () async throws -> Result
) async rethrows -> Result {
    try await SekaiOfflineAsset.$localBehavior.withValue(behavior, operation: body, isolation: isolation)
}

/// Behavior of using offline asset in SekaiKit.
///
/// The default behavior is `disabled`, unless you use ``withOfflineAsset(_:_:)``
/// or ``Foundation/URL/withOfflineAsset(_:)`` to change it.
///
/// - IMPORTANT:
///     ``enabled`` implies "**never** use online asset",
///     if requested asset isn't available in local, you'll get nil.
///     Use ``enableIfAvailable`` to make it flexible.
@frozen
public enum OfflineAssetBehavior: Sendable {
    /// Never use offline asset.
    case disabled
    /// Use offline asset if available.
    case enableIfAvailable
    /// Always use offline asset.
    ///
    /// - IMPORTANT:
    ///     `enabled` implies "**never** use online asset",
    ///     if requested asset isn't available in local, you'll get nil.
    ///     Use ``enableIfAvailable`` to make it flexible.
    case enabled
}

extension SekaiOfflineAsset {
    @TaskLocal
    internal static var localBehavior: OfflineAssetBehavior = .disabled
}

#endif
