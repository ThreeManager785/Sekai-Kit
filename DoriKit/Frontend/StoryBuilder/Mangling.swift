//===---*- Greatdori! -*---------------------------------------------------===//
//
// Mangling.swift
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

internal import SwiftSyntax

// mangling-prefix ::= '$z'

// mangled-func ::= mangling-prefix parent-spec? signature
// parent-spec ::= 'p' name-spec
// signature ::= 'f' name-spec arguments effect? return-type
// arguments ::= argument+
// argument ::= arg-label arg-type
// arg-label ::= name-spec
// arg-type ::= name-spec
// effect ::= 'e' effect-type+
// effect-type ::= 'A' // async
// effect-type ::= 's' // static
// return-type ::= 'r' name-spec
// return-type ::= 'r' 'V' // Void
// name-spec ::= name-length name
// name-length ::= [0-9]+
// name ::= [A-Za-z_0-9]+
internal func mangleFunction(_ decl: SemaEvaluator.FunctionDeclaration, parent: String?, isStatic: Bool) -> String {
    var result = "$z"
    
    if let parent {
        result += "p"
        result += nameSpec(for: parent)
    }
    
    result += "f"
    result += nameSpec(for: decl.name)
    
    var arguments = ""
    for param in decl.parameters {
        var arg = ""
        arg += nameSpec(for: param.name)
        arg += nameSpec(for: param.typeName)
        arguments += arg
    }
    result += arguments
    
    if decl.isAsync || isStatic {
        result += "e"
        if decl.isAsync {
            result += "A"
        }
        if isStatic {
            result += "s"
        }
    }
    
    result += "r"
    if !decl.returnType.isEmpty {
        result += nameSpec(for: decl.returnType)
    } else {
        result += "V"
    }
    
    return result
}
internal func demangleFunction(_ mangled: String) -> (decl: SemaEvaluator.FunctionDeclaration, parent: String?, isStatic: Bool)? {
    var mangled = mangled
    guard mangled.hasPrefix("$z") else {
        return nil
    }
    mangled.removeFirst(2)
    
    var parent: String?
    
    var spec = mangled.removeFirst()
    if spec == "p" {
        parent = prefixSourceName(inSpec: &mangled)
        spec = mangled.removeFirst()
    }
    
    guard spec == "f" else {
        return nil
    }
    
    guard let funcName = prefixSourceName(inSpec: &mangled) else {
        return nil
    }
    
    var argDefs: [String] = []
    while let name = prefixSourceName(inSpec: &mangled) {
        argDefs.append(name)
    }
    guard argDefs.count % 2 == 0 else {
        return nil
    }
    
    var params: [SemaEvaluator.FunctionDeclaration.Parameter] = []
    for (index, name) in argDefs.enumerated() {
        if index % 2 == 0 {
            params.append(.init(name: name, typeName: ""))
        } else {
            params[params.endIndex - 1].typeName = name
        }
    }
    
    var isAsync = false
    var isStatic = false
    
    spec = mangled.removeFirst()
    if spec == "e" {
        if mangled.hasPrefix("As") {
            isAsync = true
            isStatic = true
            mangled.removeFirst(2)
        } else if mangled.hasPrefix("s") {
            isStatic = true
            mangled.removeFirst()
        } else if mangled.hasPrefix("A") {
            isAsync = true
            mangled.removeFirst()
        } else {
            return nil
        }
        spec = mangled.removeFirst()
    }
    
    var returnType = ""
    
    guard spec == "r" else {
        return nil
    }
    
    if !mangled.hasPrefix("V") {
        if let type = prefixSourceName(inSpec: &mangled) {
            returnType = type
        } else {
            return nil
        }
    } else {
        mangled.removeFirst()
    }
    
    guard mangled.isEmpty else {
        return nil
    }
    
    return (.init(name: funcName, parameters: params, returnType: returnType, isAsync: isAsync), parent, isStatic)
}

private func nameSpec(for name: String) -> String {
    return "\(name.count)\(name)"
}
private func prefixSourceName(inSpec spec: inout String) -> String? {
    var countStr = ""
    for c in spec {
        if Int(String(c)) != nil {
            countStr += String(c)
        } else {
            break
        }
    }
    
    guard var count = Int(countStr) else {
        return nil
    }
    var cpySpec = copy spec
    cpySpec.removeFirst(countStr.count)
    guard cpySpec.count >= count else {
        return nil
    }
    
    var result = ""
    while count > 0 {
        result.append(cpySpec.removeFirst())
        count -= 1
    }
    
    spec = cpySpec
    return result
}
