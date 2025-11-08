//===---*- Greatdori! -*---------------------------------------------------===//
//
// IRCoding.swift
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
internal import Compression

extension StoryIR {
    internal func binEncode() -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let plistEncodedData = try! encoder.encode(self._actions)
        
        let pageSize = 1024
        var compressedData = Data()
        let filter = try! OutputFilter(.compress, using: .lzfse) { data in
            if let data {
                compressedData.append(data)
            }
        }
        
        var index = 0
        let bufferSize = plistEncodedData.count
        while true {
            let rangeLength = min(pageSize, bufferSize - index)
            
            let subdata = plistEncodedData.subdata(
                in: index ..< index + rangeLength
            )
            index += rangeLength
            
            try! filter.write(subdata)
            
            if rangeLength == 0 {
                break
            }
        }
        
        var headerMagic: UInt32 = 0x52494c5a
        compressedData.replaceSubrange(
            0..<4,
            with: unsafe Data(bytes: &headerMagic,
                              count: MemoryLayout.size(ofValue: headerMagic))
        )
        
        var eofMagic: UInt32 = 0x2452495a
        compressedData.replaceSubrange(
            (compressedData.endIndex - 4)..<compressedData.endIndex,
            with: unsafe Data(bytes: &eofMagic,
                              count: MemoryLayout.size(ofValue: eofMagic))
        )
        
        return compressedData
    }
}
