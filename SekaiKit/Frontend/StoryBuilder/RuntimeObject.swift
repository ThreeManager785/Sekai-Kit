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

extension ZeileRuntimeObject.Storage {
    internal func castTrivial() -> ZeileRuntimeObject.TrivialStorage {
        if case .trivial(let trivialStorage) = self {
            return trivialStorage
        } else {
            preconditionFailure("Casting a non-trivial storage to trivial")
        }
    }
}
extension ZeileRuntimeObject.TrivialStorage {
    internal func asInt() -> Int {
        if case .int(let int) = self {
            return int
        } else {
            preconditionFailure("Casting a trivial storage to different type")
        }
    }
    
    internal func asBool() -> Bool {
        if case .bool(let bool) = self {
            return bool
        } else {
            preconditionFailure("Casting a trivial storage to different type")
        }
    }
    
    internal func asFloat() -> Float {
        if case .float(let float) = self {
            return float
        } else {
            preconditionFailure("Casting a trivial storage to different type")
        }
    }
    
    internal func asString() -> String {
        if case .string(let string) = self {
            return string
        } else {
            preconditionFailure("Casting a trivial storage to different type")
        }
    }
}
extension ZeileRuntimeObject {
    internal func asTrivialInt() -> Int {
        storages["_value"]!.castTrivial().asInt()
    }
    
    internal func asTrivialBool() -> Bool {
        storages["_value"]!.castTrivial().asBool()
    }
    
    internal func asTrivialFloat() -> Float {
        storages["_value"]!.castTrivial().asFloat()
    }
    
    internal func asTrivialString() -> String {
        storages["_value"]!.castTrivial().asString()
    }
}
