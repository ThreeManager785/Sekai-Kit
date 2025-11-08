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
            "$zp9Characterf4init2id3Int6live2d6StringesrV": zeile_characterInitByIDWithLive2D,
            "$zp9Characterf4init1_6String6live2d6StringesrV": zeile_characterInitByNameWithLive2D,
            "$zp9Characterf4init2id3Int4name6StringesrV": zeile_characterInitByIDWithName,
            "$zp9Characterf4init2id3Int4name6String6live2d6StringesrV": zeile_characterInitByIDWithNameAndLive2D,
            "$zp9Characterf4show2at8PositioneAr9Character": zeile_characterShowAtPosition,
            "$zp9Characterf4move2to8PositioneAr9Character": zeile_characterMoveToPosition,
            "$zp9Characterf4hideeAr9Character": zeile_characterHide,
            "$zp9Characterf3act1_6StringeAr9Character": zeile_characterActWithName,
            "$zp10Backgroundf6change2to6StringesrV": zeile_backgroundChangeToPath,
            "$zp3BGMf6change2to6StringesrV": zeile_BGMChangeToPath,
            "$zp2SEf6change2to6StringesrV": zeile_SEChangeToPath,
            "$zp4Taskf4init1_7ClosureesrV": zeile_taskInitWithClosure,
            "$zf3say1_6String7speaker9CharacterrV": zeile_sayWithTextFromSpeaker,
            "$zf3say1_6String7speaker9Character5voice5VoicerV": zeile_sayWithTextFromSpeakerAndVoice,
            "$zf5telop1_6StringrV": zeile_telopWithText,
            "$zf13waitUntilDonerV": zeile_waitUntilDone,
            "$zf5sleep1_5FloatrV": zeile_sleepForSeconds
        ]
    }
}

nonisolated(unsafe)
private let zeile_characterInitByID: ZeileVTable.Function = { vtable, args in
    return .init(type: "Character", storages: [
        "id": args.buffer[0].storages["_value"]!,
        "name": .trivial(.string(_characterName(
            byID: args.buffer[0].asTrivialInt(),
            in: vtable.ctx
        ))),
        "live2dPath": .trivial(.string(_characterLive2D(
            byID: args.buffer[0].asTrivialInt(),
            in: vtable.ctx
        )))
    ])
}

nonisolated(unsafe)
private let zeile_characterInitByIDWithLive2D: ZeileVTable.Function = { vtable, args in
    return .init(type: "Character", storages: [
        "id": args.buffer[0].storages["_value"]!,
        "name": .trivial(.string(_characterName(
            byID: args.buffer[0].asTrivialInt(),
            in: vtable.ctx
        ))),
        "live2dPath": .trivial(.string(_resolvePath(
            args.buffer[1].asTrivialString(),
            base: "\(vtable.ctx.sema.locale.rawValue)/live2d/chara/"
        )))
    ])
}

nonisolated(unsafe)
private let zeile_characterInitByNameWithLive2D: ZeileVTable.Function = { vtable, args in
    return .init(type: "Character", storages: [
        "id": .trivial(.int(.random(in: 10_000...10_000_000))),
        "name": args.buffer[0].storages["_value"]!,
        "live2dPath": .trivial(.string(_resolvePath(
            args.buffer[1].asTrivialString(),
            base: "\(vtable.ctx.sema.locale.rawValue)/live2d/chara/"
        )))
    ])
}

nonisolated(unsafe)
private let zeile_characterInitByIDWithName: ZeileVTable.Function = { vtable, args in
    return .init(type: "Character", storages: [
        "id": args.buffer[0].storages["_value"]!,
        "name": args.buffer[1].storages["_value"]!,
        "live2dPath": .trivial(.string(_characterLive2D(
            byID: args.buffer[0].asTrivialInt(),
            in: vtable.ctx
        )))
    ])
}

nonisolated(unsafe)
private let zeile_characterInitByIDWithNameAndLive2D: ZeileVTable.Function = { vtable, args in
    return .init(type: "Character", storages: [
        "id": args.buffer[0].storages["_value"]!,
        "name": args.buffer[1].storages["_value"]!,
        "live2dPath": .trivial(.string(_resolvePath(
            args.buffer[2].asTrivialString(),
            base: "\(vtable.ctx.sema.locale.rawValue)/live2d/chara/"
        )))
    ])
}

nonisolated(unsafe)
private let zeile_characterShowAtPosition: ZeileVTable.Function = { vtable, args in
    let charaStorages = args.implicitSelf!.storages
    vtable.ctx.ir.emitAction(.showModel(
        characterID: charaStorages["id"]!.castTrivial().asInt(),
        modelPath: charaStorages["live2dPath"]!.castTrivial().asString(),
        position: .init(
            base: .init(
                rawValue: args.buffer[0].storages["rawValue"]!
                    .castTrivial().asInt()
            )!,
            offsetX: 0
        )
    ))
    return args.implicitSelf!
}

nonisolated(unsafe)
private let zeile_characterMoveToPosition: ZeileVTable.Function = { vtable, args in
    let charaStorages = args.implicitSelf!.storages
    vtable.ctx.ir.emitAction(.moveModel(
        characterID: charaStorages["id"]!.castTrivial().asInt(),
        position: .init(
            base: .init(
                rawValue: args.buffer[0].storages["rawValue"]!
                    .castTrivial().asInt()
            )!,
            offsetX: 0
        )
    ))
    return args.implicitSelf!
}

nonisolated(unsafe)
private let zeile_characterHide: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.hideModel(
        characterID: args.implicitSelf!.storages["id"]!.castTrivial().asInt()
    ))
    return args.implicitSelf!
}

nonisolated(unsafe)
private let zeile_characterActWithName: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.act(
        characterID: args.implicitSelf!.storages["id"]!.castTrivial().asInt(),
        motionName: args.buffer[0].asTrivialString()
    ))
    return args.implicitSelf!
}

nonisolated(unsafe)
private let zeile_characterEmoteWithName: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.express(
        characterID: args.implicitSelf!.storages["id"]!.castTrivial().asInt(),
        expressionName: args.buffer[0].asTrivialString()
    ))
    return args.implicitSelf!
}

nonisolated(unsafe)
private let zeile_backgroundChangeToPath: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.changeBackground(path: _resolvePath(
        args.buffer[0].asTrivialString(),
        base: "\(vtable.ctx.sema.locale.rawValue)/bg/"
    )))
    return .init(type: "", storages: [:])
}

nonisolated(unsafe)
private let zeile_BGMChangeToPath: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.changeBGM(path: _resolvePath(
        args.buffer[0].asTrivialString(),
        base: "\(vtable.ctx.sema.locale.rawValue)/sound/scenario/bgm/"
    )))
    return .init(type: "", storages: [:])
}

nonisolated(unsafe)
private let zeile_SEChangeToPath: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.changeSE(path: _resolvePath(
        args.buffer[0].asTrivialString(),
        base: "\(vtable.ctx.sema.locale.rawValue)/sound/se/"
    )))
    return .init(type: "", storages: [:])
}

nonisolated(unsafe)
private let zeile_taskInitWithClosure: ZeileVTable.Function = { vtable, args in
    let retainedActionsAddress = args.buffer[0].storages["_unsafeAddress"]!
        .castTrivial().asInt()
    let retainedActions = unsafe UnsafeMutablePointer<[StoryIR.StepAction]>
        .init(bitPattern: retainedActionsAddress)!
    defer {
        unsafe retainedActions.deinitialize(count: 1)
        unsafe retainedActions.deallocate()
    }
    
    vtable.ctx.ir.emitAction(.forkTask(unsafe retainedActions.pointee))
    
    return .init(type: "Task", storages: [:])
}

nonisolated(unsafe)
private let zeile_sayWithTextFromSpeaker: ZeileVTable.Function = { vtable, args in
    let buffer = args.buffer
    vtable.ctx.ir.emitAction(.talk(
        buffer[0].asTrivialString(),
        characterIDs: [buffer[1].storages["id"]!.castTrivial().asInt()],
        characterNames: [buffer[1].storages["name"]!.castTrivial().asString()],
        voicePath: nil
    ))
    return .init(type: "", storages: [:])
}

nonisolated(unsafe)
private let zeile_sayWithTextFromSpeakerAndVoice: ZeileVTable.Function = { vtable, args in
    let buffer = args.buffer
    vtable.ctx.ir.emitAction(.talk(
        buffer[0].asTrivialString(),
        characterIDs: [buffer[1].storages["id"]!.castTrivial().asInt()],
        characterNames: [buffer[1].storages["name"]!.castTrivial().asString()],
        voicePath: buffer[2].storages["_path"]!.castTrivial().asString()
    ))
    return .init(type: "", storages: [:])
}

nonisolated(unsafe)
private let zeile_telopWithText: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.telop(args.buffer[0].asTrivialString()))
    return .init(type: "", storages: [:])
}

nonisolated(unsafe)
private let zeile_waitUntilDone: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.waitForAll)
    return .init(type: "", storages: [:])
}

nonisolated(unsafe)
private let zeile_sleepForSeconds: ZeileVTable.Function = { vtable, args in
    vtable.ctx.ir.emitAction(.delay(
        seconds: .init(args.buffer[0].asTrivialFloat())
    ))
    return .init(type: "", storages: [:])
}

// MARK: - Helpers
private func _characterName(byID id: Int, in ctx: IRGenEvaluator) -> String {
    if let character = DoriCache.preCache.characters.first(
        where: { $0.id == id }
    ) {
        return (character.characterName
            .forLocale(character.characterName.availableLocale(
                prefer: ctx.sema.locale
            ) ?? .jp) ?? "")
            .replacing(" ", with: "")
    } else {
        return ""
    }
}

private func _characterLive2D(byID id: Int, in ctx: IRGenEvaluator) -> String {
    if let character = DoriCache.preCache.characters.first(
        where: { $0.id == id }
    ), let costume = character.seasonCostumeList?.flatMap({ $0 }).first {
        return "\(ctx.sema.locale.rawValue)/live2d/chara/\(costume.live2dAssetBundleName)"
    } else {
        return ""
    }
}

private func _resolvePath(_ path: String, base: String) -> String {
    if path.hasPrefix("jp/")
        || path.hasPrefix("en/")
        || path.hasPrefix("tw/")
        || path.hasPrefix("cn/")
        || path.hasPrefix("kr/") {
        return path
    } else if path.hasPrefix("http://") || path.hasPrefix("https://") {
        return path
    } else {
        return base + path
    }
}
