//===---*- Greatdori! -*---------------------------------------------------===//
//
// ImageMatching.swift
//
// This source file is part of the Greatdori! open source project
//
// Copyright (c) 2026 the Greatdori! project authors
// Licensed under Apache License v2.0
//
// See https://greatdori.com/LICENSE.txt for license information
// See https://greatdori.com/CONTRIBUTORS.txt for the list of Greatdori! project authors
//
//===----------------------------------------------------------------------===//

import CoreImage
import Foundation
internal import os
internal import Alamofire
internal import Accelerate

extension DoriFrontend {
    public enum ImageMatching {
        public func matchCard(byThumbImage image: CIImage) async -> [ImageMatchingResult]? {
            let groupResult = await withTasksResult {
                await DoriAPI.Cards.all()
            } _: {
                await withCheckedContinuation { (continuation: CheckedContinuation<[FeaturePair]?, Never>) in
                    AF.request("https://fakeapi.greatdori.com/CardThumbFeature1.plist")
                        .response { response in
                            let decoder = PropertyListDecoder()
                            if let data = response.data,
                               let pairs = try? decoder.decode([FeaturePair].self, from: data) {
                                continuation.resume(returning: pairs)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                }
            }
            guard let cards = groupResult.0 else { return nil }
            guard let featurePairs = groupResult.1 else { return nil }
            
            // Hash computing may take some time, we wrap it into a continuation
            return await withCheckedContinuation { continuation in
                // Args here should be matched with the generator's config.
                // See Greatdori/ImageFeatGen/ImageFeatGen/Generation.swift
                let hasher = PHash(16, 4)
                
                let thisHash = hasher.compute(image)
                var partialResult: [(Float, FeaturePair)] = []
                for pair in featurePairs {
                    if let distance = PHash.distance(from: pair.feature, to: thisHash) {
                        partialResult.append((distance, pair))
                    } else {
                        logger.fault("""
                    DoriKit encountered an error while matching cards, \
                    please file a bug report.
                    """)
                    }
                }
                
                var results: [ImageMatchingResult] = []
                
                partialResult.sort { $0.0 < $1.0 }
                for result in partialResult.prefix(10) {
                    if let card = cards.first(where: { $0.id == result.1.cardID }) {
                        results.append(.init(
                            confidence: 1 - result.0,
                            card: card,
                            trained: result.1.trained
                        ))
                    }
                }
                
                continuation.resume(returning: results)
            }
        }
    }
}

private class PHash {
    internal let hashSize: Int
    internal let highFreqFactor: Int
    internal let freqShift: Int
    
    internal init(_ hashSize: Int, _ highFreqFactor: Int, freqShift: Int = 0) {
        self.hashSize = hashSize
        self.highFreqFactor = highFreqFactor
        self.freqShift = freqShift
    }
    
    private let coreImageContext = CIContext()
    
    internal static func distance(from data1: Data, to data2: Data) -> Float? {
        guard data1.count == data2.count else { return nil }
        var distance = 0
        for (byte1, byte2) in zip(data1, data2) {
            distance += (byte1 ^ byte2).nonzeroBitCount
        }
        return Float(distance) / Float(data1.count * 8)
    }
    
    internal func compute(_ image: CIImage) -> Data {
        let dct = _compute_dct(image).flatMap { $0 }
        let median = median(of: dct)
        let bits = dct.map { $0 > median }
        return bitsToData(bits)
    }
    
    internal func _compute_dct(_ image: CIImage) -> [[Float]] {
        let imgSize = hashSize * highFreqFactor
        var image = rgb2Gray(image)
        image = image.transformed(
            by: .init(
                scaleX: CGFloat(imgSize) / image.extent.width,
                y: CGFloat(imgSize) / image.extent.height
            ),
            highQualityDownsample: true
        )
        let dct = dct(image, imgSize)
        return sliceDCT(dct, originalSize: imgSize)
    }
    
    private func rgb2Gray(_ image: CIImage) -> CIImage {
        return image.applyingFilter("CIPhotoEffectMono")
    }
    
    private func dct(_ image: CIImage, _ size: Int) -> [Float] {
        var pixels = Array<Float>(repeating: 0, count: size * size)
        
        unsafe coreImageContext.render(
            image,
            toBitmap: &pixels,
            rowBytes: size * MemoryLayout<Float>.size,
            bounds: .init(x: 0, y: 0, width: size, height: size),
            format: .Rf,
            colorSpace: nil
        )
        
        let dctSetup = unsafe vDSP_DCT_CreateSetup(nil, .init(size), .II)!
        
        var intermediate = Array<Float>(repeating: 0, count: size * size)
        var result = Array<Float>(repeating: 0, count: size * size)
        
        for i in 0..<size {
            let rowStart = i * size
            unsafe vDSP_DCT_Execute(
                dctSetup,
                Array(pixels[rowStart..<(rowStart + size)]),
                &intermediate[rowStart]
            )
        }
        
        var transposed = Array<Float>(repeating: 0, count: size * size)
        unsafe vDSP_mtrans(intermediate, 1, &transposed, 1, .init(size), .init(size))
        
        for i in 0..<size {
            let rowStart = i * size
            unsafe vDSP_DCT_Execute(
                dctSetup,
                Array(transposed[rowStart..<(rowStart + size)]),
                &result[rowStart]
            )
        }
        
        unsafe vDSP_mtrans(result, 1, &intermediate, 1, .init(size), .init(size))
        return intermediate
    }
    
    private func sliceDCT(
        _ dct: [Float],
        originalSize: Int
    ) -> [[Float]] {
        var subMatrix = [[Float]]()
        
        for r in freqShift..<(hashSize + freqShift) {
            var currentRow = [Float]()
            for c in freqShift..<(hashSize + freqShift) {
                let index = r * originalSize + c
                currentRow.append(dct[index])
            }
            subMatrix.append(currentRow)
        }
        
        return subMatrix
    }
    
    private func median(of array: [Float]) -> Float {
        guard !array.isEmpty else { return 0 }
        let sorted = array.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }
    
    private func bitsToData(_ bits: [Bool]) -> Data {
        let byteCount = (bits.count + 7) / 8
        var bytes = [UInt8](repeating: 0, count: byteCount)
        
        for (index, bit) in bits.enumerated() {
            if bit {
                let byteIndex = index / 8
                let bitPosition = 7 - (index % 8)
                bytes[byteIndex] |= (1 << bitPosition)
            }
        }
        
        return Data(bytes)
    }
}

extension DoriFrontend.ImageMatching {
    internal struct FeaturePair: Codable {
        internal var feature: Data
        internal var cardID: Int
        internal var trained: Bool
    }
    
    public struct ImageMatchingResult: Sendable, Hashable {
        public var confidence: Float
        public var card: DoriAPI.Cards.PreviewCard
        public var trained: Bool
    }
}
