//===---*- Greatdori! -*---------------------------------------------------===//
//
// Sema.swift
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

internal final class SemaEvaluator {
    internal let sources: [SourceFileSyntax]
    
    internal init(_ sources: [SourceFileSyntax]) {
        self.sources = sources
    }
    
    internal var resolvedTypeInfo: [/*hashValue*/Int: /*typeName*/String] = [:]
    
    internal var _resolvedStructs: [/*name*/String: ResolvedStruct] = [:]
    internal var _resolvedEnums: [/*name*/String: ResolvedEnum] = [:]
    internal var _resolvedTopFunctions: [FunctionDeclaration] = []
    
    internal func performSema() -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        
        _performTypeCheck(diags: &diagnostics)
        
        return diagnostics
    }
    
    internal func _performTypeCheck(diags: inout [Diagnostic]) {
        for source in sources {
            _typeCheckSingle(source, diags: &diags)
        }
    }
    
    internal func _typeCheckSingle(_ source: SourceFileSyntax, diags: inout [Diagnostic]) {
        for statement in source.statements {
            let item = statement.item
            if let decl = item.as(DeclSyntax.self) {
                _typeCheckDecl(decl, diags: &diags)
            } else if let stmt = item.as(StmtSyntax.self) {
                _typeCheckStmt(stmt, diags: &diags)
            } else if let expr = item.as(ExprSyntax.self) {
                _typeCheckExpr(expr, diags: &diags)
            } else {
                diags.append(.init(node: item, message: .unrecognizedTopLevelSyntax))
                
                // This is really an undefined statement,
                // we return immediately
                return
            }
        }
    }
    
    internal struct ResolvedStruct {
        internal var staticMethods: [FunctionDeclaration]
        internal var instanceMethods: [FunctionDeclaration]
    }
    
    internal struct ResolvedEnum {
        internal var cases: [String]
    }
    
    internal struct FunctionDeclaration: Hashable {
        internal var name: String
        internal var parameters: [Parameter]
        internal var returnType: String
        internal var isAsync: Bool
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(parameters)
        }
        
        internal struct Parameter: Hashable {
            internal var name: String
            internal var typeName: String
            internal var omittable: Bool
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(name)
                hasher.combine(typeName)
            }
        }
    }
    
    internal func _typeCheckStmt(_ stmt: StmtSyntax, diags: inout [Diagnostic]) {
        
    }
    
    internal func _typeCheckExpr(_ expr: ExprSyntax, diags: inout [Diagnostic]) {
        
    }
}

// MARK: - Type-Check decls
extension SemaEvaluator {
    internal func _typeCheckDecl(_ decl: DeclSyntax, diags: inout [Diagnostic]) {
        if let enumDecl = decl.as(EnumDeclSyntax.self) {
            _typeCheckEnumDecl(enumDecl, diags: &diags)
        } else if let funcDecl = decl.as(FunctionDeclSyntax.self) {
            _typeCheckFunctionDecl(funcDecl, diags: &diags)
        } else {
            diags.append(.init(node: decl, message: .unsupportedDeclaration))
        }
    }
    
    internal func _typeCheckEnumDecl(_ decl: EnumDeclSyntax, diags: inout [Diagnostic]) {
        if !decl.attributes.isEmpty {
            diags.append(.init(node: decl.attributes, message: .attributesNotSupported))
        }
        if let clause = decl.genericParameterClause {
            diags.append(.init(node: clause, message: .genericNotSupported))
        }
        if let clause = decl.inheritanceClause {
            diags.append(.init(node: clause, message: .inheritanceNotSupported))
        }
        if let clause = decl.genericWhereClause {
            diags.append(.init(node: clause, message: .whereClauseNotSupported))
        }
        
        let members = decl.memberBlock.members
        if members.isEmpty {
            diags.append(.init(node: decl, message: .missingMemberBlock))
        }
        
        var cases: [String] = []
        for member in members {
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                if !caseDecl.attributes.isEmpty {
                    diags.append(.init(node: caseDecl.attributes, message: .attributesNotSupported))
                }
                if !caseDecl.modifiers.isEmpty {
                    diags.append(.init(node: caseDecl.modifiers, message: .declModifierNotSupported))
                }
                
                if caseDecl.elements.isEmpty {
                    diags.append(.init(node: caseDecl, message: .missingIdentifierInEnumCase))
                }
                for element in caseDecl.elements {
                    if let clause = element.parameterClause {
                        diags.append(.init(node: clause, message: .enumCaseParameterNotSupported))
                    }
                    if let rawValue = element.rawValue {
                        diags.append(.init(node: rawValue, message: .enumRawValueNotSupported))
                    }
                    
                    let caseName = element.name.text
                    if !cases.contains(caseName) {
                        cases.append(caseName)
                    } else {
                        diags.append(.init(node: caseDecl, message: .invalidRedeclaration(of: caseName)))
                    }
                }
            } else {
                diags.append(.init(node: member.decl, message: .unsupportedDeclInEnum))
            }
        }
        
        let enumName = decl.name.text
        if !_resolvedEnums.keys.contains(enumName) {
            let resolved = ResolvedEnum(cases: cases)
            _resolvedEnums.updateValue(resolved, forKey: enumName)
        } else {
            diags.append(.init(node: decl.name, message: .invalidRedeclaration(of: enumName)))
        }
    }
    
    internal func _typeCheckFunctionDecl(_ decl: FunctionDeclSyntax, diags: inout [Diagnostic]) {
        guard _isTopLevelSyntax(decl) else {
            diags.append(.init(node: decl, message: .unexpectedTopLevelTypeCheckPath))
            return
        }
        
        let function = _typeCheckAnyFunctionDecl(decl, diags: &diags)
        if !_resolvedTopFunctions.contains(function) {
            _resolvedTopFunctions.append(function)
        } else {
            let resolvedName = _resolveFuncName(decl, diags: &diags)
            diags.append(.init(node: decl, message: .invalidRedeclaration(of: resolvedName)))
        }
    }
    
    internal func _typeCheckAnyFunctionDecl(_ decl: FunctionDeclSyntax, diags: inout [Diagnostic]) -> FunctionDeclaration {
        if !decl.attributes.isEmpty {
            diags.append(.init(node: decl.attributes, message: .attributesNotSupported))
        }
        if !decl.modifiers.isEmpty {
            diags.append(.init(node: decl.modifiers, message: .declModifierNotSupported))
        }
        if let clause = decl.genericParameterClause {
            diags.append(.init(node: clause, message: .genericNotSupported))
        }
        if let clause = decl.genericWhereClause {
            diags.append(.init(node: clause, message: .whereClauseNotSupported))
        }
        if let body = decl.body {
            diags.append(.init(node: body, message: .functionUnexpectedBody))
        }
        
        var resultParams: [FunctionDeclaration.Parameter] = []
        let parameters = decl.signature.parameterClause.parameters
        for parameter in parameters {
            if !parameter.attributes.isEmpty {
                diags.append(.init(node: parameter.attributes, message: .attributesNotSupported))
            }
            if !parameter.modifiers.isEmpty {
                diags.append(.init(node: parameter.modifiers, message: .declModifierNotSupported))
            }
            if let ellipsis = parameter.ellipsis {
                diags.append(.init(node: ellipsis, message: .functionParamUnexpectedEllipsis))
            }
            if let defaultValue = parameter.defaultValue {
                diags.append(.init(node: defaultValue, message: .functionParamUnsupportedDefaultValueDecl))
            }
            if let secondName = parameter.secondName {
                diags.append(.init(node: secondName, message: .functionParamSecondNameIsUnused))
            }
            
            if let resolvedType = _resolveType(parameter.type, diags: &diags) {
                resultParams.append(
                    .init(
                        name: parameter.firstName.text,
                        typeName: resolvedType.typeName,
                        omittable: resolvedType.optional
                    )
                )
            }
        }
        
        var isAsync = false
        if let effects = decl.signature.effectSpecifiers {
            if let clause = effects.throwsClause {
                diags.append(.init(node: clause, message: .functionThrowsNotSupported))
            }
            
            if effects.asyncSpecifier?.text == "async" {
                isAsync = true
            }
        }
        
        var returnTypeName = ""
        if let retClause = decl.signature.returnClause,
           let resolvedType = _resolveType(retClause.type, diags: &diags) {
            if resolvedType.optional {
                diags.append(.init(node: retClause, message: .contextOptionalTypeNotSupported))
            }
            
            returnTypeName = resolvedType.typeName
        }
        
        return .init(
            name: decl.name.text,
            parameters: resultParams,
            returnType: returnTypeName,
            isAsync: isAsync
        )
    }
}

// MARK: - Resolve
extension SemaEvaluator {
    internal func _resolveType(_ syntax: TypeSyntax, diags: inout [Diagnostic]) -> (typeName: String, optional: Bool)? {
        if let idSyntax = syntax.as(IdentifierTypeSyntax.self) {
            if let clause = idSyntax.genericArgumentClause {
                diags.append(.init(node: clause, message: .genericNotSupported))
                return nil
            }
            
            return (idSyntax.name.text, false)
        } else if let optSyntax = syntax.as(OptionalTypeSyntax.self) {
            if let resolved = _resolveType(optSyntax.wrappedType, diags: &diags) {
                if resolved.optional {
                    diags.append(.init(node: optSyntax.questionMark, message: .nestingOptionalTypeNotSupported))
                    return nil
                }
                
                return (resolved.typeName, true)
            }
        }
        
        return nil
    }
    
    internal func _resolveFuncName(_ decl: FunctionDeclSyntax, diags: inout [Diagnostic]) -> String {
        var result = ""
        
        result += decl.name.text
        result += "("
        
        var paramDescs: [String] = []
        for param in decl.signature.parameterClause.parameters {
            var desc = ""
            if let resolvedType = _resolveType(param.type, diags: &diags) {
                desc += param.firstName.text
                desc += ": "
                desc += resolvedType.typeName
                if resolvedType.optional {
                    desc += "?"
                }
            }
            paramDescs.append(desc)
        }
        result += paramDescs.joined(separator: ", ")
        
        result += ")"
        
        if decl.signature.effectSpecifiers?.asyncSpecifier?.text == "async" {
            result += " async"
        }
        
        if let retClause = decl.signature.returnClause,
           let type = _resolveType(retClause.type, diags: &diags) {
            result += " -> \(type.typeName)"
        }
        
        return result
    }
}

internal func _isTopLevelSyntax(_ syntax: any SyntaxProtocol) -> Bool {
    // Expected if it's top level:
    // SourceFileSyntax
    // ├─statements: CodeBlockItemListSyntax
    // │ ╰─CodeBlockItemSyntax
    // │   ╰─ThisSyntax
    return !(syntax.parent?.parent?.parent?.hasParent ?? false)
}
