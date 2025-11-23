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
internal import JavaScriptCore

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

internal final class FunctionEvaluator {
    internal let ir: StoryIR
    internal let jsVM: JSVirtualMachine
    internal let compilerContext: JSContext
    
    internal init(ir: StoryIR) {
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
    }
}
