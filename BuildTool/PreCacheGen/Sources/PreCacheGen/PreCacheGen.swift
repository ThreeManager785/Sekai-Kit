//===---*- Greatdori! -*---------------------------------------------------===//
//
// PreCacheGen.swift
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

import DoriKit
import Foundation

@main
struct PreCacheGen {
    static func main() async throws {
        // We use stderr for all outputs because logs in Xcode show everything in stderr in real-time but stdout delayed.
        var stderr = StandardError()
        
        guard let outputPath = ProcessInfo.processInfo.environment["CODESIGNING_FOLDER_PATH"] else {
            print("error: CODESIGNING_FOLDER_PATH is unavailable", to: &stderr)
            exit(EXIT_FAILURE)
        }
        guard let targetPlatform = ProcessInfo.processInfo.environment["SWIFT_PLATFORM_TARGET_PREFIX"] else {
            print("error: SWIFT_PLATFORM_TARGET_PREFIX is unavailable", to: &stderr)
            exit(EXIT_FAILURE)
        }
        
        var bands: [DoriAPI.Bands.Band]!
        LimitedTaskQueue.shared.addTask {
            DispatchQueue.main.async {
                print("Fetching bands...", to: &stderr)
            }
            bands = await retryUntilNonNil(perform: DoriAPI.Bands.all)
        }
        var mainBands: [DoriAPI.Bands.Band]!
        LimitedTaskQueue.shared.addTask {
            DispatchQueue.main.async {
                print("Fetching main bands...", to: &stderr)
            }
            mainBands = await retryUntilNonNil(perform: DoriAPI.Bands.main)
        }
        var characters: [DoriAPI.Characters.PreviewCharacter]!
        LimitedTaskQueue.shared.addTask {
            DispatchQueue.main.async {
                print("Fetching characters...", to: &stderr)
            }
            characters = await retryUntilNonNil(perform: DoriAPI.Characters.all)
        }
        var birthdayCharacters: [DoriAPI.Characters.BirthdayCharacter]!
        LimitedTaskQueue.shared.addTask {
            DispatchQueue.main.async {
                print("Fetching birthday characters...", to: &stderr)
            }
            birthdayCharacters = await retryUntilNonNil(perform: DoriAPI.Characters.allBirthday)
        }
        var categorizedCharacters: DoriFrontend.Characters.CategorizedCharacters!
        LimitedTaskQueue.shared.addTask {
            DispatchQueue.main.async {
                print("Fetching categorized characters...", to: &stderr)
            }
            categorizedCharacters = await retryUntilNonNil(perform: DoriFrontend.Characters.categorizedCharacters)
        }
        
        await LimitedTaskQueue.shared.waitUntilAllFinished()
        
        var characterDetails = [Int: DoriAPI.Characters.Character]()
        for (index, character) in characters.enumerated() {
            LimitedTaskQueue.shared.addTask {
                DispatchQueue.main.async {
                    print("Fetching character detail for \(character.characterName.jp ?? "\(character.id)")... [\(index + 1)/\(characters.count)]", to: &stderr)
                }
                let detail = await retryUntilNonNil { await DoriAPI.Characters.detail(of: character.id) }
                DispatchQueue.main.async {
                    characterDetails.updateValue(detail, forKey: character.id)
                }
            }
        }
        
        await LimitedTaskQueue.shared.waitUntilAllFinished()
        try await Task.sleep(for: .seconds(0.5))
        
        let result = CacheResult(
            bands: bands,
            mainBands: mainBands,
            characters: characters,
            birthdayCharacters: birthdayCharacters,
            categorizedCharacters: categorizedCharacters,
            characterDetails: characterDetails
        )
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(result)
        if targetPlatform.hasPrefix("mac") {
            try data.write(to: URL(filePath: outputPath + "/Resources/PreCache.cache"))
        } else {
            try data.write(to: URL(filePath: outputPath + "/PreCache.cache"))
        }
        
        exit(EXIT_SUCCESS)
    }
}

struct CacheResult: Codable {
    var bands: [DoriAPI.Bands.Band]
    var mainBands: [DoriAPI.Bands.Band]
    var characters: [DoriAPI.Characters.PreviewCharacter]
    var birthdayCharacters: [DoriAPI.Characters.BirthdayCharacter]
    var categorizedCharacters: DoriFrontend.Characters.CategorizedCharacters
    var characterDetails: [Int: DoriAPI.Characters.Character] // [CharacterID: Detail]
}

func retryUntilNonNil<T>(maxRetry: Int = 5, perform: () async -> T?) async -> T {
    for _ in 0..<maxRetry {
        if let result = await perform() {
            return result
        }
    }
    var stderr = StandardError()
    print("error: Failed to fetch: \(T.self)", to: &stderr)
    print("note: Switch to 'Without Pre-Cache' schemes to disable pre-cache for DoriKit", to: &stderr)
    exit(EXIT_FAILURE)
}

struct StandardError: TextOutputStream, Sendable {
    private static let handle = FileHandle.standardError
    
    public func write(_ string: String) {
        Self.handle.write(Data(string.utf8))
    }
}
