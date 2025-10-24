//===---*- Greatdori! -*---------------------------------------------------===//
//
// InMemoryCaches.swift
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

internal class InMemoryCache {
    private init() {}
    
    @safe
    nonisolated(unsafe) internal static var skills: [DoriAPI.Skills.Skill]?
    
    internal static func updateAll() {
        Task.detached {
            for _ in 1...5 {
                let skills = await DoriAPI.Skills.all()
                
                if let skills {
                    self.skills = skills
                    break
                } else {
                    try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                }
            }
        }
    }
}
