//===---*- Greatdori! -*---------------------------------------------------===//
//
// RichContentMarkdown.swift
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
internal import Alamofire

#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

extension RichContentGroup {
    public func toMarkdown() -> String {
        self.map { compileRichContent($0) }.joined()
    }
}

#if canImport(SwiftUI)

import SwiftUI

extension RichContentGroup {
    public static func resolveMarkdownImage(
        url: URL,
        label: String,
        emojiIdealSize: CGSize
    ) async -> Image {
        if label == "%%DoriKit_Resolve_Emoji%%" {
            let encodedData = String(url.absoluteString.dropFirst("greatdori://".count))
            if let data = Data(base64Encoded: encodedData) {
                #if canImport(AppKit)
                if let image = NSImage(data: data) {
                    guard let bitmapRep = NSBitmapImageRep(
                        bitmapDataPlanes: nil,
                        pixelsWide: Int(emojiIdealSize.width),
                        pixelsHigh: Int(emojiIdealSize.height),
                        bitsPerSample: 8,
                        samplesPerPixel: 4,
                        hasAlpha: true,
                        isPlanar: false,
                        colorSpaceName: .deviceRGB,
                        bytesPerRow: 0,
                        bitsPerPixel: 0
                    ) else {
                        return .init(nsImage: .init())
                    }
                    let aspectWidth = emojiIdealSize.width / image.size.width
                    let aspectHeight = emojiIdealSize.height / image.size.height
                    let scaleFactor = Swift.min(aspectWidth, aspectHeight)
                    let scaledImageSize = CGSize(
                        width: image.size.width * scaleFactor,
                        height: image.size.height * scaleFactor
                    )
                    let origin = CGPoint(
                        x: (emojiIdealSize.width - scaledImageSize.width) / 2,
                        y: (emojiIdealSize.height - scaledImageSize.height) / 2
                    )
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
                    image.draw(
                        in: CGRect(origin: origin, size: scaledImageSize),
                        from: .zero,
                        operation: .copy,
                        fraction: 1.0
                    )
                    NSGraphicsContext.restoreGraphicsState()
                    let result = NSImage(size: emojiIdealSize)
                    result.addRepresentation(bitmapRep)
                    return .init(nsImage: result)
                } else {
                    return .init(nsImage: .init())
                }
                #else
                if let image = UIImage(data: data) {
                    let aspectWidth = emojiIdealSize.width / image.size.width
                    let aspectHeight = emojiIdealSize.height / image.size.height
                    let scaleFactor = Swift.min(aspectWidth, aspectHeight)
                    let scaledImageSize = CGSize(
                        width: image.size.width * scaleFactor,
                        height: image.size.height * scaleFactor
                    )
                    let origin = CGPoint(
                        x: (emojiIdealSize.width - scaledImageSize.width) / 2,
                        y: (emojiIdealSize.height - scaledImageSize.height) / 2
                    )
                    UIGraphicsBeginImageContextWithOptions(emojiIdealSize, false, 0.0)
                    defer { UIGraphicsEndImageContext() }
                    image.draw(in: CGRect(origin: origin, size: scaledImageSize))
                    let result = UIGraphicsGetImageFromCurrentImageContext() ?? image
                    return .init(uiImage: result)
                } else {
                    return .init(uiImage: .init())
                }
                #endif
            } else {
                #if canImport(AppKit)
                return .init(nsImage: .init())
                #else
                return .init(uiImage: .init())
                #endif
            }
        } else {
            let data = await withCheckedContinuation { continuation in
                AF.request(url).response { response in
                    continuation.resume(returning: response.data)
                }
            }
            if let data {
                #if canImport(AppKit)
                return .init(nsImage: .init(data: data) ?? .init())
                #else
                return .init(uiImage: .init(data: data) ?? .init())
                #endif
            } else {
                #if canImport(AppKit)
                return .init(nsImage: .init())
                #else
                return .init(uiImage: .init())
                #endif
            }
        }
    }
}

#endif // canImport(SwiftUI)

private func compileRichContent(_ content: RichContent) -> String {
    switch content {
    case .br: "\n\n"
    case .text(let string):
        "\(string)"
    case .heading(let string):
        "## \(string)\n"
    case .bullet(let string):
        "- \(string)\n"
    case .image(let urls):
        urls.map {
            " ![Alt](\($0.absoluteString)) "
        }.joined()
    case .link(let url):
        " [\(url.absoluteString)](\(url.absoluteString)) "
    case .emoji(let emoji):
        #if canImport(AppKit)
        " ![%%DoriKit_Resolve_Emoji%%](greatdori://\(emoji.image.tiffRepresentation?.base64EncodedString() ?? "")) "
        #else
        " ![%%DoriKit_Resolve_Emoji%%](greatdori://\(emoji.image.pngData()?.base64EncodedString() ?? "")) "
        #endif
    }
}

#endif // HAS_BINARY_RESOURCE_BUNDLES
