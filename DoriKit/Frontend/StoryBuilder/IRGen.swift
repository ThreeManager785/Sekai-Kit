//===---*- Greatdori! -*---------------------------------------------------===//
//
// IRGen.swift
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
internal import SwiftOperators

internal final class IRGenEvaluator {
    internal var ir: StoryIR
    internal var sema: SemaEvaluator
    internal var _symbolizer: ZeileSymbolizer
    internal var vtable: ZeileVTable!
    
    internal init(_ ir: StoryIR, semaResult: SemaEvaluator) {
        self.ir = ir
        self.sema = semaResult
        self._symbolizer = .init(semaResult: semaResult)
        self.vtable = .init(ctx: self)
        print(_symbolizer.symbolizeAll().joined(separator: "\n"))
    }
    
    internal func emitSemaResult(diags: inout [Diagnostic]) {
        for source in sema.sources {
            _emitCodeBlock(source.statements, diags: &diags)
        }
    }
    
    internal func _emitCodeBlock(_ statements: CodeBlockItemListSyntax, diags: inout [Diagnostic]) {
        for statement in statements {
            let item = statement.item
            if let expr = item.as(ExprSyntax.self) {
                _emitExpr(expr, diags: &diags)
            }
        }
    }
}

extension IRGenEvaluator {
    internal func _emitExpr(_ expr: ExprSyntax, diags: inout [Diagnostic]) {
        if let funcCallExpr = expr.as(FunctionCallExprSyntax.self) {
            _ = _emitFuncCallExpr(funcCallExpr, diags: &diags)
        }
    }
    
    internal func _emitFuncCallExpr(_ expr: FunctionCallExprSyntax, type: String? = nil, diags: inout [Diagnostic]) -> ZeileRuntimeObject? {
        guard let calledDecl = sema.resolvedFuncCalls[expr.hashValue] else {
            diags.append(.init(node: expr, message: .funcCallNotResolved))
            return nil
        }
        guard let calledValue = _evaluateExpr(expr.calledExpression, type: type, diags: &diags) else {
            return nil
        }
        guard calledValue.type == "Functions" || calledValue.type.hasSuffix(".Type") else {
            diags.append(.init(node: expr.calledExpression, message: .cannotCallNonFuncValue(ofType: calledValue.type)))
            return nil
        }
        
        var mangledNames: [String] = []
        if calledValue.type.hasSuffix(".Type") {
            let sourceTypeName = String(calledValue.type.dropLast(".Type".count))
            if let s = sema._resolvedStructs[sourceTypeName] {
                for i in s.initializers {
                    mangledNames.append(mangleFunction(i, parent: sourceTypeName, isStatic: true))
                }
            }
        } else {
            if case .trivial(let t) = calledValue.storages["_count"], case .int(let count) = t {
                for i in 0..<count {
                    if case .trivial(let t) = calledValue.storages["_\(i)"], case .string(let name) = t {
                        mangledNames.append(name)
                    }
                }
            }
        }
        
        // Retrieve parent info
        guard let decl = mangledNames.compactMap({ demangleFunction($0) }).first(where: { $0.decl == calledDecl }) else {
            return nil
        }
        let qualifiedMangledName = mangleFunction(decl.decl, parent: decl.parent, isStatic: decl.isStatic)
        
        var argBuffer: [ZeileRuntimeObject] = []
        for (index, argument) in expr.arguments.enumerated() {
            if let value = _evaluateExpr(argument.expression, type: decl.decl.parameters[index].typeName, diags: &diags) {
                argBuffer.append(value)
            }
        }
        var impSelf: ZeileRuntimeObject?
        if case .nonTrivial(let v) = calledValue.storages["_self"] {
            impSelf = v
        }
        
        let args = ZeileFunctionArguments(implicitSelf: impSelf, buffer: argBuffer)
        return vtable.callFunc(qualifiedMangledName, args: args)
    }
}

extension IRGenEvaluator {
    internal func _evaluateExpr(_ expr: ExprSyntax, type: String? = nil, diags: inout [Diagnostic]) -> ZeileRuntimeObject? {
        if let awaitExpr = expr.as(AwaitExprSyntax.self) {
            return _evaluateExpr(awaitExpr.expression, diags: &diags)
        } else if let boolLiteralExpr = expr.as(BooleanLiteralExprSyntax.self) {
            return .init(type: "Bool", storages: ["_value": .trivial(.bool(boolLiteralExpr.literal.text == "true"))])
        } else if let closureExpr = expr.as(ClosureExprSyntax.self) {
            _emitCodeBlock(closureExpr.statements, diags: &diags)
            return .init(type: "Closure", storages: [:])
        } else if let declRefExpr = expr.as(DeclReferenceExprSyntax.self) {
            return _evaluateDeclRefExpr(declRefExpr, diags: &diags)
        } else if let floatLiteralExpr = expr.as(FloatLiteralExprSyntax.self) {
            return .init(type: "Float", storages: ["_value": .trivial(.float(.init(floatLiteralExpr.literal.text)!))])
        } else if let funcCallExpr = expr.as(FunctionCallExprSyntax.self) {
            return _emitFuncCallExpr(funcCallExpr, type: type, diags: &diags)
        } else if let infixOperatorExpr = expr.as(InfixOperatorExprSyntax.self) {
            return .init(type: "", storages: [:])
        } else if let intLiteralExpr = expr.as(IntegerLiteralExprSyntax.self) {
            return .init(type: "Int", storages: ["_value": .trivial(.int(Int(intLiteralExpr.literal.text)!))])
        } else if let memberAccessExpr = expr.as(MemberAccessExprSyntax.self) {
            return _evaluateMemberAccessExpr(memberAccessExpr, type: type, diags: &diags)
        } else if let seqExpr = expr.as(SequenceExprSyntax.self) {
            // We have to use SwiftOperators to fold this expr
            // then resolve the folded expr
            let precedence = OperatorTable.standardOperators
            if let foldedExpr = try? precedence.foldSingle(seqExpr) {
                return _evaluateExpr(foldedExpr, diags: &diags)
            } else {
                // The Sema should emit a diagnostic here
                return nil
            }
        } else if let stringLiteralExpr = expr.as(StringLiteralExprSyntax.self) {
            return _evaluateStringLiteralExpr(stringLiteralExpr, diags: &diags)
        } else {
            return nil
        }
    }
    
    internal func _evaluateDeclRefExpr(_ expr: DeclReferenceExprSyntax, diags: inout [Diagnostic]) -> ZeileRuntimeObject? {
        let baseName = expr.baseName.text
        if let parent = expr.parent,
           let memberAccessExpr = parent.as(MemberAccessExprSyntax.self),
           expr != memberAccessExpr.base?.as(DeclReferenceExprSyntax.self) {
            return _evaluateMemberAccessExpr(memberAccessExpr, diags: &diags)
        } else {
            // It should be a single identifier
            if let result = _evaluateRef(baseName, at: expr, diags: &diags) {
                return result
            } else {
                diags.append(.init(node: expr.baseName, message: .cannotFindRefInScope(baseName)))
                return nil
            }
        }
    }
    
    internal func _evaluateMemberAccessExpr(_ expr: MemberAccessExprSyntax, type: String? = nil, diags: inout [Diagnostic])
    -> ZeileRuntimeObject? {
        let declName = expr.declName.baseName.text
        if let base = expr.base {
            if let baseValue = _evaluateExpr(base, diags: &diags),
               let result = _evaluateMember(declName, of: baseValue, diags: &diags) {
                return result
            } else {
                return nil
            }
        } else if let type {
            if let result = _evaluateMember(declName, of: .init(type: "\(type).Type", storages: [:]), diags: &diags) {
                return result
            } else {
                return nil
            }
        } else {
            
            return nil
        }
    }
    
    internal func _evaluateStringLiteralExpr(_ expr: StringLiteralExprSyntax, diags: inout [Diagnostic]) -> ZeileRuntimeObject? {
        var _result = ""
        
        for segment in expr.segments {
            if let str = segment.as(StringSegmentSyntax.self) {
                _result += str.content.text
            } else {
                diags.append(.init(node: segment, message: .stringInterpolationNotSupported))
            }
        }
        
        return .init(type: "String", storages: ["_value": .trivial(.string(_result))])
    }
    
    internal func _evaluateRef(_ name: String, at syntax: some SyntaxProtocol, diags: inout [Diagnostic]) -> ZeileRuntimeObject? {
        guard let enclosingBlock = findCodeBlock(of: syntax) else {
            diags.append(.init(node: syntax, message: .exprNoEnclosingBlock))
            return nil
        }
        let position = syntax.position
        for statement in enclosingBlock {
            let item = statement.item
            if let varDecl = item.as(VariableDeclSyntax.self) {
                for binding in varDecl.bindings where binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == name {
                    let pos = binding.position
                    guard pos < position else {
                        diags.append(.init(node: syntax, message: .constUsedBeforeInit(name)))
                        return nil
                    }
                    guard let _init = binding.initializer,
                          let value = _evaluateExpr(_init.value, diags: &diags) else {
                        return nil
                    }
                    return value
                }
            } else if let structDecl = item.as(StructDeclSyntax.self),
                      structDecl.name.text == name {
                return .init(type: "\(name).Type", storages: [:])
            }
        }
        
        var funcResults: [String] = []
        for function in sema._resolvedTopFunctions where function.name == name {
            funcResults.append(mangleFunction(function, parent: nil, isStatic: false))
        }
        
        if !funcResults.isEmpty {
            var result = ZeileRuntimeObject(type: "Functions", storages: [
                "_count": .trivial(.int(funcResults.count))
            ])
            for (index, name) in funcResults.enumerated() {
                result.storages.updateValue(.trivial(.string(name)), forKey: "_\(index)")
            }
            return result
        } else {
            return nil
        }
    }
    
    internal func _evaluateMember(_ name: String, of value: ZeileRuntimeObject, diags: inout [Diagnostic]) -> ZeileRuntimeObject? {
        if let member = value.storages[name] {
            return member.asObject()
        }
        var type = value.type
        var isStatic = false
        if type.hasSuffix(".Type") {
            isStatic = true
            type.removeLast(".Type".count)
        }
        
        if let s = sema._resolvedStructs[type] {
            let functions: [SemaEvaluator.FunctionDeclaration]
            if isStatic {
                functions = (s.initializers + s.staticMethods).filter { $0.name == name }
            } else {
                functions = s.instanceMethods.filter { $0.name == name }
            }
            if !functions.isEmpty {
                let mangledNames = functions.map {
                    mangleFunction($0, parent: type, isStatic: isStatic)
                }
                var result = ZeileRuntimeObject(type: "Functions", storages: [
                    "_count": .trivial(.int(mangledNames.count))
                ])
                if !isStatic {
                    result.storages.updateValue(.nonTrivial(value), forKey: "_self")
                }
                for (index, name) in mangledNames.enumerated() {
                    result.storages.updateValue(.trivial(.string(name)), forKey: "_\(index)")
                }
                return result
            }
        }
        
        if let e = sema._resolvedEnums[type] {
            for (index, n) in e.cases.enumerated() where n == name {
                return .init(type: type, storages: [
                    "rawValue": .trivial(.int(index)),
                    "_name": .trivial(.string(n))
                ])
            }
        }
        
        // Find static property of struct
        if isStatic {
            for source in sema.sources {
                for statement in source.statements {
                    if let structDecl = statement.item.as(StructDeclSyntax.self),
                       structDecl.name.text == type {
                        for member in structDecl.memberBlock.members {
                            if let decl = member.decl.as(VariableDeclSyntax.self),
                               decl.modifiers.contains(where: { $0.name.text == "static" }) {
                                for binding in decl.bindings where binding.pattern.cast(IdentifierPatternSyntax.self).identifier.text == name {
                                    return _evaluateExpr(binding.initializer!.value, diags: &diags)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
}

private func findCodeBlock(of syntax: some SyntaxProtocol) -> CodeBlockItemListSyntax? {
    if let list = syntax.as(CodeBlockItemListSyntax.self) {
        return list
    } else if let parent = syntax.parent {
        return findCodeBlock(of: parent)
    } else {
        return nil
    }
}
