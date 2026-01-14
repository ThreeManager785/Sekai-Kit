//===---*- Greatdori! -*---------------------------------------------------===//
//
// FunctionEvaluator.swift
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
internal import SwiftSyntax
#if !os(watchOS)
internal import JavaScriptCore
#endif

#if !os(watchOS)
private let _tsCompilerSource = {
    try! String(
        contentsOf: #bundle.url(
            forResource: "TypeScriptCompiler",
            withExtension: "js"
        )!,
        encoding: .utf8
    )
}()
private let _tsCompilerUtilsSource = {
    try! String(
        contentsOf: #bundle.url(
            forResource: "TSCompilerUtils",
            withExtension: "js"
        )!,
        encoding: .utf8
    )
}()
private let _tsLibrarySource = {
    try! String(
        contentsOf: #bundle.url(
            forResource: "TSLibrary.d",
            withExtension: "ts"
        )!,
        encoding: .utf8
    )
}()
#endif // !os(watchOS)

internal final class FunctionEvaluator {
    #if !os(watchOS)
    internal let ir: StoryIR
    internal let jsVM: JSVirtualMachine
    internal let compilerContext: JSContext
    #endif
    
    internal init(ir: StoryIR) {
        #if !os(watchOS)
        self.ir = ir
        
        self.jsVM = .init()
        self.compilerContext = .init(virtualMachine: jsVM)
        compilerContext.isInspectable = true
        
        compilerContext.evaluateScript(_tsCompilerSource)
        compilerContext.evaluateScript(_tsCompilerUtilsSource)
        compilerContext.setObject(
            _tsLibrarySource,
            forKeyedSubscript: "_tsLibrary" as NSString
        )
        #endif
    }
    
    internal var sourceMap: [
        String /* mangled Zeile function name */
        : String /* JavaScript source */
    ] = [:]
    
    internal func addFunction(
        mangledName: String,
        node: StringLiteralExprSyntax,
        sourceCode: String
    ) -> [Diagnostic] {
        #if !os(watchOS)
        
        if sourceMap[mangledName] != nil {
            return []
        }
        
        var diags: [Diagnostic] = []
        
        compilerContext.setObject(
            sourceCode,
            forKeyedSubscript: "currentSource" as NSString
        )
        let result = compilerContext
            .evaluateScript("compileTS(currentSource)")
            .toDictionary()!
        
        for diag in result["diagnostics"] as! [[String: Any]] {
            diags.append(.init(
                node: node,
                message: .typeScriptError("\(diag["line"]!):\(diag["column"]!): \(diag["message"]!)")
            ))
        }
        
        sourceMap.updateValue(result["jsCode"] as! String, forKey: mangledName)
        
        return diags
        
        #else
        return []
        #endif
    }
}
