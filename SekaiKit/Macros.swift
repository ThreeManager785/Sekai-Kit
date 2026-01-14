//===---*- Greatdori! -*---------------------------------------------------===//
//
// Macros.swift
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

// MARK: - Internal Macros

@attached(memberAttribute)
internal macro CopyOnWrite() = #externalMacro(module: "SekaiKitMacros", type: "CopyOnWriteMacro")
@attached(peer, names: arbitrary)
internal macro _CopyOnWriteVarPeerImpl() = #externalMacro(module: "SekaiKitMacros", type: "_CopyOnWriteVarPeerImplMacro")
@attached(accessor)
internal macro _CopyOnWriteVarAccessorImpl() = #externalMacro(module: "SekaiKitMacros", type: "_CopyOnWriteVarAccessorImplMacro")
@attached(body)
internal macro _CopyOnWriteInitializerImpl(_: String) = #externalMacro(module: "SekaiKitMacros", type: "_CopyOnWriteInitializerImplMacro")

// MARK: - Public Macros

#if canImport(SekaiAssetShims)

/// Make all resource URLs in a closure or function
/// respects the given offline asset behavior.
///
/// > Beta API:
/// >
/// > This API is currently in development and is unstable.
/// > It is subject to change, and software implemented with this API should be tested with its stable version.
@attached(body)
public macro OfflineAssetURL(_: OfflineAssetBehavior = .enableIfAvailable) = #externalMacro(module: "SekaiKitMacros", type: "OfflineAssetURLMacro")

#endif
