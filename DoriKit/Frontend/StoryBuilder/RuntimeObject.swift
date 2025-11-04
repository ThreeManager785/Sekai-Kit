//===---*- Greatdori! -*---------------------------------------------------===//
//
// RuntimeObject.swift
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

internal struct ZeileRuntimeObject {
    internal var type: String
    internal var storages: [/*name*/String: Storage]
    
    internal enum Storage {
        case trivial(TrivialStorage)
        case nonTrivial(ZeileRuntimeObject)
        
        internal func asObject() -> ZeileRuntimeObject {
            switch self {
            case .trivial(let trivialStorage):
                trivialStorage.asObject()
            case .nonTrivial(let object):
                object
            }
        }
    }
    internal enum TrivialStorage {
        case int(Int)
        case bool(Bool)
        case float(Float)
        case string(String)
        
        internal func asObject() -> ZeileRuntimeObject {
            .init(type: "Int", storages: ["_value": .trivial(self)])
        }
    }
}

internal struct ZeileFunctionArguments {
    internal var implicitSelf: ZeileRuntimeObject?
    internal var buffer: [ZeileRuntimeObject]
}
