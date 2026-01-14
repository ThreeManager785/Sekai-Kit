//===---*- Greatdori! -*---------------------------------------------------===//
//
// Asset.swift
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
internal import SwiftyJSON

extension SekaiAPI {
    /// Request and fetch data about assets in Bandori.
    ///
    /// *Assets* are source files which GBP downloads to every players' devices.
    ///
    /// In the most cases, you don't find or parse data from assets,
    /// instead, use other methods in ``SekaiAPI`` or ``SekaiFrontend``
    /// to get specific data which is ready-to-use.
    ///
    /// - SeeAlso:
    ///     [](https://bestdori.com/tool/explorer/asset)
    public enum Assets {
        /// Get asset information of locale.
        /// - Parameter locale: Target locale.
        /// - Returns: Asset information of requested locale, nil if failed to fetch.
        public static func info(in locale: Locale) async -> AssetList? {
            let request = await requestJSON("https://bestdori.com/api/explorer/\(locale.rawValue)/assets/_info.json")
            if case let .success(respJSON) = request {
                let task = Task.detached(priority: .userInitiated) {
                    func resolveList(_ json: JSON) -> AssetList {
                        var result = AssetList()
                        for (key, value) in json {
                            if let count = value.int {
                                result.updateValue(.files(count), forKey: key)
                            } else {
                                result.updateValue(.list(resolveList(value)), forKey: key)
                            }
                        }
                        return result
                    }
                    return resolveList(respJSON)
                }
                return await task.value
            }
            return nil
        }
        
        /// Get contents of a ``Child/files(_:)`` by path.
        /// - Parameter path: Path descriptor.
        /// - Returns: Contents, nil if failed to fetch.
        @inlinable
        public static func contentsOf(_ path: PathDescriptor) async -> [String]? {
            await _contentsOf(String(path._path.dropLast()), in: path.locale)
        }
        public static func _contentsOf(_ path: String, in locale: Locale) async -> [String]? {
            let request = await requestJSON("https://bestdori.com/api/explorer/\(locale.rawValue)/assets\(path).json")
            if case let .success(respJSON) = request {
                let task = Task.detached(priority: .userInitiated) {
                    respJSON.map { $0.1.stringValue }
                }
                return await task.value
            }
            return nil
        }
    }
}

extension SekaiAPI.Assets {
    /// A type that represents a list of assets.
    public typealias AssetList = [String: Child]
    
    /// A type that represents a child in asset lists.
    ///
    /// The ``files(_:)`` means this child is a group of files
    /// (generally, they are end with `_rip`). The associated `Int`
    /// represents file count in this group.
    /// You use ``contentsOf(_:)`` to get contents in this group.
    ///
    /// The ``list(_:)`` means this child is a normal folder.
    @frozen
    public enum Child: Sendable {
        case files(Int) // Int -> file count
        case list(AssetList)
    }
    
    /// A type that represents a path for assets.
    public struct PathDescriptor: Sendable, Hashable {
        @usableFromInline
        internal var _path: String
        
        public var locale: SekaiAPI.Locale
        
        public init(locale: SekaiAPI.Locale) {
            self._path = "/"
            self.locale = locale
        }
        
        @inlinable
        public var componments: [String] {
            [locale.rawValue] + _path.split(separator: "/").map {
                if $0.hasSuffix("_rip") {
                    String($0.dropLast("_rip".count))
                } else {
                    String($0)
                }
            }
        }
        
        @inlinable
        public func resourceURL(name: String) -> URL {
            var separatedPath = _path.split(separator: "/")
            if !separatedPath.isEmpty {
                separatedPath[separatedPath.count - 1] += "_rip"
            }
            return .init(string: "https://bestdori.com/assets/\(locale.rawValue)/\(separatedPath.joined(separator: "/"))/\(name)")!
        }
    }
}

extension SekaiAPI.Assets.AssetList {
    @inlinable
    public func access(_ key: String) -> SekaiAPI.Assets.Child? {
        self[key]
    }
    @inlinable
    public func access(_ key: String, updatingPath descriptor: inout SekaiAPI.Assets.PathDescriptor) -> SekaiAPI.Assets.Child? {
        descriptor._path += "\(key)/"
        return self[key]
    }
}
