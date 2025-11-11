//===---*- Greatdori! -*---------------------------------------------------===//
//
// Constructor.swift
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

// __attribute__((constructor))
@_section("__DATA,__mod_init_func")
private let __constructor: @convention(c) () -> Void = {
    InMemoryCache.updateAll()
    _prepareAssetListForZeileCompletion()
}
