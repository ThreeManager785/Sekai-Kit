//===---*- Greatdori! -*---------------------------------------------------===//
//
// VTable.swift
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

internal final class ZeileVTable {
    internal typealias Function = (ZeileVTable, ZeileFunctionArguments) -> ZeileRuntimeObject
    
    internal var ctx: IRGenEvaluator
    internal var table: [String: Function]
    
    internal init(ctx: IRGenEvaluator) {
        self.ctx = ctx
        self.table = [:]
    }
    
    internal func callFunc(_ rawName: String, args: ZeileFunctionArguments) -> ZeileRuntimeObject? {
        table[rawName]?(self, args)
    }
}

extension ZeileVTable {
//    internal static var _stdlibTable: [String: Function] {
//        [
//            
//        ]
//    }
    
    
}
