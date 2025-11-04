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
        self.table.merge(Self._stdlibTable) { $1 }
    }
    
    internal func callFunc(_ rawName: String, args: ZeileFunctionArguments) -> ZeileRuntimeObject? {
        table[rawName]?(self, args)
    }
}

extension ZeileVTable {
    internal static var _stdlibTable: [String: Function] {
        unsafe [
            "$zp9Characterf4init2id3IntesrV": zeile_characterInitByID,
            "$zf3say1_6String7speaker9CharacterrV": zeile_sayWithTextFromSpeaker
        ]
    }
}

nonisolated(unsafe)
private let zeile_characterInitByID: ZeileVTable.Function = { vtable, args in
    let idObj = args.buffer[0].storages["_value"]!
    if case .trivial(let t) = idObj, case .int(let id) = t {
        return .init(type: "Character", storages: [
            "id": idObj,
            "name": .trivial(.string(_characterName(byID: id, in: vtable.ctx)))
        ])
    } else {
        preconditionFailure()
    }
}

nonisolated(unsafe)
private let zeile_sayWithTextFromSpeaker: ZeileVTable.Function = { vtable, args in
    dump(args)
    return .init(type: "", storages: [:])
}

private func _characterName(byID id: Int, in ctx: IRGenEvaluator) -> String {
    if let character = DoriCache.preCache.characters.first(where: { $0.id == id }) {
        return (character.characterName
            .forLocale(character.characterName.availableLocale(prefer: ctx.sema.locale) ?? .jp) ?? "")
            .replacing(" ", with: "")
    } else {
        return ""
    }
}
