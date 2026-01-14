//===---*- Greatdori! -*---------------------------------------------------===//
//
// Duration+Overflow.swift
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

extension Duration {
    @usableFromInline
    internal static func &+ (lhs: Self, rhs: Self) -> Self {
        let low = lhs._low &+ rhs._low
        let carry: Int64 = low < lhs._low ? 1 : 0
        let high = lhs._high &+ rhs._high &+ carry
        return .init(_high: high, low: low)
    }
    
    @usableFromInline
    internal static func &* (lhs: Self, rhs: Self) -> Self {
        let p0 = lhs._low.multipliedFullWidth(by: rhs._low)
        let p1 = UInt64(bitPattern: lhs._high) &* rhs._low
        let p2 = lhs._low &* UInt64(bitPattern: rhs._high)
        return .init(_high: Int64(bitPattern: p0.high &+ p1 &+ p2), low: p0.low)
    }
    
    @usableFromInline
    internal static func &* (lhs: Self, rhs: Int) -> Self {
        return lhs &* Duration(
            _high: rhs < 0 ? -1 : 0,
            low: .init(bitPattern: Int64(rhs))
        )
    }
}
