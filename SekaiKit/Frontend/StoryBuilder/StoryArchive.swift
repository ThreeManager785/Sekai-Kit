//===---*- Greatdori! -*---------------------------------------------------===//
//
// StoryArchive.swift
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
internal import System
internal import AppleArchive

public enum StoryArchive {
    public static func archive(ir: StoryIR, assetFolder: URL) async -> Data? {
        await withCheckedContinuation { continuation in
            let tmpFolderURL = URL(
                filePath: NSTemporaryDirectory() + "/_SekaiKit_StoryArchive_Intermediate"
            )
            try? FileManager.default.removeItem(at: tmpFolderURL)
            try? FileManager.default.createDirectory(
                at: tmpFolderURL,
                withIntermediateDirectories: true
            )
            let tmpFileURL = URL(
                filePath: NSTemporaryDirectory() + "/_SekaiKit_StoryArchive_Intermediate.aar"
            )
            if FileManager.default.fileExists(atPath: tmpFileURL.path) {
                try? FileManager.default.removeItem(at: tmpFileURL)
            }
            
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(tmpFileURL.path),
                mode: .writeOnly,
                options: .create,
                permissions: .init(rawValue: 0o644)
            ) else {
                return continuation.resume(returning: nil)
            }
            defer { try? fileStream.close() }
            
            guard let compressStream = ArchiveByteStream.compressionStream(
                using: .lzfse,
                writingTo: fileStream
            ) else {
                return continuation.resume(returning: nil)
            }
            defer { try? compressStream.close() }
            
            guard let encodeStream = ArchiveStream.encodeStream(
                writingTo: compressStream
            ) else {
                return continuation.resume(returning: nil)
            }
            defer { try? encodeStream.close() }
            
            guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,DEV,DAT,FLG,MTM,CTM,SIZ,SH5") else {
                return continuation.resume(returning: nil)
            }
            
            do {
                try FileManager.default.copyItem(
                    at: assetFolder,
                    to: tmpFolderURL.appending(path: "Assets")
                )
                
                let encodedIR = ir.binaryEncoded()
                try encodedIR.write(to: tmpFolderURL.appending(path: "Story.zir"))
                
                let source = FilePath(tmpFolderURL.path)
                try encodeStream.writeDirectoryContents(
                    archiveFrom: source,
                    keySet: keySet
                )
                
                // Although we have defers to close the streams,
                // we have to close them before reading file data
                // to make sure all data have been written into the file.
                // The calls to `close` in defers has an optional try
                // so this action is safe
                try encodeStream.close()
                try compressStream.close()
                try fileStream.close()
                
                if let result = try? Data(contentsOf: tmpFileURL) {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: nil)
                }
            } catch {
                continuation.resume(returning: nil)
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: tmpFolderURL)
            try? FileManager.default.removeItem(at: tmpFileURL)
        }
    }
    
    public static func extract(from data: Data, to destination: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            let tmpFileURL = URL(
                filePath: NSTemporaryDirectory() + "/_SekaiKit_StoryArchive_Intermediate.aar"
            )
            if FileManager.default.fileExists(atPath: tmpFileURL.path) {
                try? FileManager.default.removeItem(at: tmpFileURL)
            }
            guard (try? data.write(to: tmpFileURL)) != nil else {
                return continuation.resume(returning: false)
            }
            
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(tmpFileURL.path),
                mode: .readOnly,
                options: [],
                permissions: .init(rawValue: 0o644)
            ) else {
                return continuation.resume(returning: false)
            }
            defer { try? fileStream.close() }
            
            guard let decompressStream = ArchiveByteStream.decompressionStream(
                readingFrom: fileStream
            ) else {
                return continuation.resume(returning: false)
            }
            defer { try? decompressStream.close() }
            
            guard let decodeStream = ArchiveStream.decodeStream(
                readingFrom: decompressStream
            ) else {
                return continuation.resume(returning: false)
            }
            defer { try? decodeStream.close() }
            
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.createDirectory(
                    at: destination,
                    withIntermediateDirectories: true
                )
                
                guard let extractStream = ArchiveStream.extractStream(
                    extractingTo: .init(destination.path),
                    flags: .ignoreOperationNotPermitted
                ) else {
                    return continuation.resume(returning: false)
                }
                defer { try? extractStream.close() }
                
                _ = try ArchiveStream.process(
                    readingFrom: decodeStream,
                    writingTo: extractStream
                )
                
                // Although we have defers to close the streams,
                // we have to close them before reading file data
                // to make sure all data have been written into the file.
                // The calls to `close` in defers has an optional try
                // so this action is safe
                try extractStream.close()
                try decodeStream.close()
                try decompressStream.close()
                try fileStream.close()
                
                continuation.resume(returning: true)
            } catch {
                return continuation.resume(returning: false)
            }
        }
    }
}
