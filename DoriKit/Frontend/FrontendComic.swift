//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendComic.swift
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

extension DoriFrontend {
    /// Request and fetch data about comics in Bandori.
    ///
    /// *Comics* appear randomly in the loading page of GBP.
    /// They can also be viewed in the menu of GBP.
    ///
    /// A comic is either single-frame or four-frame,
    /// use ``DoriAPI/Comics/Comic/type`` to get its type.
    ///
    /// You can only get all comics in one request,
    /// to find a comic with a specific ID, use `Array.first(where:)`
    /// to find the comic by ID.
    ///
    /// ![Comic: Misaki & Arisa #1 "Becoming Closer"](ComicExampleImage)
    public enum Comics {
        /// List all comics.
        ///
        /// - Returns: All comics, nil if failed to fetch.
        public static func list() async -> [Comic]? {
            guard let comics = await DoriAPI.Comics.all() else { return nil }
            return comics
        }
    }
}

extension DoriFrontend.Comics {
    public typealias Comic = DoriAPI.Comics.Comic
}

extension DoriAPI.Comics.Comic {
    @inlinable
    public init?(id: Int) async {
        guard let all = await DoriAPI.Comics.all() else { return nil }
        if let comic = all.first(where: { $0.id == id }) {
            self = comic
        } else {
            return nil
        }
    }
}

extension DoriAPI.Comics.Comic {
    /// Type of a ``DoriAPI/Comic/Comic``.
    @frozen
    public enum ComicType: String, CaseIterable, Hashable, Codable {
        case singleFrame
        case fourFrame
        
        /// A localized string for the type.
        @inline(never)
        public var localizedString: String {
            NSLocalizedString(rawValue, bundle: #bundle, comment: "")
        }
    }
    
    /// Type of this comic, if can be determined.
    @inlinable
    public var type: ComicType? {
        self.id > 0 && self.id <= 1000 ? .singleFrame : self.id > 1000 ? .fourFrame : nil
    }
}
