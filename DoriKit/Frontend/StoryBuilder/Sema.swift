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
internal import SwiftParser
internal import SwiftOperators
internal import SwiftParserDiagnostics

internal final class SemaEvaluator {
    internal let sources: [SourceFileSyntax]
    
    internal init(_ sources: [SourceFileSyntax]) {
        self.sources = sources
    }
    
    internal var locale: _DoriAPI.Locale = .jp
    internal var resolvedFuncCalls: [/*hashValue*/Int: FunctionDeclaration] = [:]
    
    internal var _resolvedStructs: [/*name*/String: ResolvedStruct] = [:]
    internal var _resolvedEnums: [/*name*/String: ResolvedEnum] = [:]
    internal var _resolvedTopFunctions: [FunctionDeclaration] = []
    internal var _resolvedTopVariables: [/*name*/String: /*typeName*/String] = [:]
    
    internal var _variablesUnderTypeChecking: Set<String> = []
    
    internal func performSema() -> [Diagnostic] {
        // Clean up
        resolvedFuncCalls.removeAll()
        _resolvedStructs.removeAll()
        _resolvedEnums.removeAll()
        _resolvedTopFunctions.removeAll()
        _resolvedTopVariables.removeAll()
        _variablesUnderTypeChecking.removeAll()
        
        var diagnostics: [Diagnostic] = []
        
        for source in sources {
            let parseDiags = ParseDiagnosticsGenerator.diagnostics(for: source)
            diagnostics.append(contentsOf: parseDiags.map { .init($0) })
        }
        
        _performTypeCheck(diags: &diagnostics)
        
        return diagnostics
    }
    
    internal func _performTypeCheck(diags: inout [Diagnostic]) {
        for source in sources {
            if let shebang = source.shebang {
                _resolveShebang(shebang, diags: &diags)
            }
            
            _typeCheckSingle(source, diags: &diags)
        }
    }
    
    internal func _resolveShebang(_ shebang: TokenSyntax, diags: inout [Diagnostic]) {
        var shebangText = shebang.text
        shebangText.removeFirst(2)
        let shebangSrc = Parser.parse(source: shebangText)
        for statement in shebangSrc.statements {
            let item = statement.item
            if let seq = item.as(SequenceExprSyntax.self) {
                let precedence = OperatorTable.standardOperators
                if let foldedExpr = try? precedence.foldSingle(seq),
                   let infix = foldedExpr.as(InfixOperatorExprSyntax.self),
                   infix.operator.is(AssignmentExprSyntax.self) {
                    if infix.leftOperand.as(DeclReferenceExprSyntax.self)?.baseName.text == "locale" {
                        if let localeRef = infix.rightOperand.as(DeclReferenceExprSyntax.self)?.baseName.text,
                           let locale = _DoriAPI.Locale(rawValue: localeRef) {
                            self.locale = locale
                        }
                    } else {
                        diags.append(.init(node: shebang, message: .invalidShebang))
                    }
                } else {
                    diags.append(.init(node: shebang, message: .invalidShebang))
                }
            } else {
                diags.append(.init(node: shebang, message: .invalidShebang))
            }
        }
    }
    
    internal func _typeCheckSingle(_ source: SourceFileSyntax, diags: inout [Diagnostic]) {
        _typeCheckCodeBlock(source.statements, diags: &diags)
    }
    internal func _typeCheckCodeBlock(_ list: CodeBlockItemListSyntax, diags: inout [Diagnostic]) {
        for statement in list {
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
        internal var initializers: [FunctionDeclaration]
        internal var staticVariables: [/*name*/String: /*typeName*/String]
        internal var instanceVariables: [/*name*/String: /*typeName*/String]
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
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(name)
                hasher.combine(typeName)
            }
        }
    }
    
    internal func _typeCheckStmt(_ stmt: StmtSyntax, diags: inout [Diagnostic]) {
        
    }
}

// MARK: - Type-Check decls
extension SemaEvaluator {
    internal func _typeCheckDecl(_ decl: DeclSyntax, diags: inout [Diagnostic]) {
        if let enumDecl = decl.as(EnumDeclSyntax.self) {
            _typeCheckEnumDecl(enumDecl, diags: &diags)
        } else if let funcDecl = decl.as(FunctionDeclSyntax.self) {
            _typeCheckFunctionDecl(funcDecl, diags: &diags)
        } else if let structDecl = decl.as(StructDeclSyntax.self) {
            _typeCheckStructDecl(structDecl, diags: &diags)
        } else if let varDecl = decl.as(VariableDeclSyntax.self) {
            _typeCheckVariableDecl(varDecl, diags: &diags)
        } else {
            diags.append(.init(node: decl, message: .unsupportedDeclaration))
        }
    }
    
    internal func _typeCheckEnumDecl(_ decl: EnumDeclSyntax, diags: inout [Diagnostic]) {
        guard _isTopLevelSyntax(decl) else {
            diags.append(.init(node: decl, message: .nestingEnumNotSupported))
            return
        }
        
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
                
                for element in caseDecl.elements {
                    if let clause = element.parameterClause {
                        diags.append(.init(node: clause, message: .enumCaseParameterNotSupported))
                    }
                    if let rawValue = element.rawValue {
                        diags.append(.init(node: rawValue, message: .enumRawValueNotSupported))
                    }
                    
                    let caseName = element.name.text
                    if !caseName.isEmpty {
                        if !cases.contains(caseName) {
                            cases.append(caseName)
                        } else {
                            diags.append(.init(node: caseDecl, message: .invalidRedeclaration(of: caseName)))
                        }
                    } else {
                        diags.append(.init(node: caseDecl, message: .missingIdentifierInEnumCase))
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
                        typeName: resolvedType
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
            returnTypeName = resolvedType
        }
        
        return .init(
            name: decl.name.text,
            parameters: resultParams,
            returnType: returnTypeName,
            isAsync: isAsync
        )
    }
    
    internal func _typeCheckStructDecl(_ decl: StructDeclSyntax, diags: inout [Diagnostic]) {
        guard _isTopLevelSyntax(decl) else {
            diags.append(.init(node: decl, message: .nestingStructNotSupported))
            return
        }
        
        if !decl.attributes.isEmpty {
            diags.append(.init(node: decl.attributes, message: .attributesNotSupported))
        }
        if !decl.modifiers.isEmpty {
            diags.append(.init(node: decl.modifiers, message: .declModifierNotSupported))
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
        
        var staticMethods: [FunctionDeclaration] = []
        var instanceMethods: [FunctionDeclaration] = []
        var initializers: [FunctionDeclaration] = []
        var staticVariables: [String: String] = [:]
        var instanceVariables: [String: String] = [:]
        
        for member in decl.memberBlock.members {
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                let resolved = _typeCheckAnyFunctionDecl(
                    funcDecl.with(
                        \.modifiers,
                         .init(funcDecl.modifiers.compactMap { $0.name.text == "static" ? nil : $0 })
                    ),
                    diags: &diags
                )
                if funcDecl.modifiers.contains(where: { $0.name.text == "static" }) {
                    staticMethods.append(resolved)
                } else {
                    instanceMethods.append(resolved)
                }
            } else if let initDecl = member.decl.as(InitializerDeclSyntax.self) {
                let funcLikeDecl = initDecl.asFunctionDecl()
                let resolved = _typeCheckAnyFunctionDecl(funcLikeDecl, diags: &diags)
                initializers.append(resolved)
            } else if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                let resolved = _typeCheckVariableDecl(varDecl, diags: &diags)
                for (name, typeName, isStatic) in resolved {
                    if isStatic {
                        staticVariables.updateValue(typeName, forKey: name)
                    } else {
                        instanceVariables.updateValue(typeName, forKey: name)
                    }
                }
            } else {
                diags.append(.init(node: member, message: .unsupportedDeclaration))
            }
        }
        
        if _resolvedStructs[decl.name.text] == nil {
            _resolvedStructs.updateValue(
                .init(
                    staticMethods: staticMethods,
                    instanceMethods: instanceMethods,
                    initializers: initializers,
                    staticVariables: staticVariables,
                    instanceVariables: instanceVariables
                ),
                forKey: decl.name.text
            )
        } else {
            diags.append(.init(node: decl.name, message: .invalidRedeclaration(of: decl.name.text)))
        }
    }
    
    @discardableResult
    internal func _typeCheckVariableDecl(_ decl: VariableDeclSyntax, diags: inout [Diagnostic])
    -> [(name: String, typeName: String, isStatic: Bool)] {
        if !decl.attributes.isEmpty {
            diags.append(.init(node: decl.attributes, message: .attributesNotSupported))
        }
        
        var isStatic = false
        for modifier in decl.modifiers {
            guard modifier.name.text == "static" else {
                diags.append(.init(node: modifier, message: .declModifierNotSupported))
                continue
            }
            guard !isStatic else {
                diags.append(.init(node: modifier, message: .duplicateDeclModifier(of: modifier.name.text)))
                continue
            }
            
            isStatic = true
            
            if _isTopLevelSyntax(decl) {
                diags.append(.init(node: modifier, message: .invalidStaticVarDeclPosition))
            }
        }
        
        let spec = decl.bindingSpecifier.text
        if spec != "let" {
            diags.append(.init(node: decl.bindingSpecifier, message: .unsupportedVarSpec(spec)))
        }
        
        var result: [(String, String, Bool)] = []
        
        for binding in decl.bindings {
            guard let idPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                diags.append(.init(node: binding.pattern, message: .varBindingUnexpectedID))
                continue
            }
            
            let variableName = idPattern.identifier.text
            
            var qualifiedVariableName = variableName
            if let structDecl = decl.parent?.parent?.parent?.parent?.as(StructDeclSyntax.self) {
                qualifiedVariableName = structDecl.name.text + "." + variableName
            }
            if _variablesUnderTypeChecking.contains(qualifiedVariableName) {
                diags.append(.init(node: binding, message: .circularRefInExpr))
                continue
            }
            _variablesUnderTypeChecking.insert(qualifiedVariableName)
            defer { _variablesUnderTypeChecking.remove(qualifiedVariableName) }
            
            var typeName: String?
            if let annotation = binding.typeAnnotation {
                if let resolvedType = _resolveType(annotation.type, diags: &diags) {
                    typeName = resolvedType
                } else {
                    // `_resolveType` has produced diagnostics here
                    continue
                }
            }
            if let initializer = binding.initializer {
                if let initType = _resolveExprType(initializer.value, diags: &diags) {
                    if typeName == nil {
                        typeName = initType
                    } else if initType != typeName {
                        diags.append(.init(
                            node: initializer.value,
                            message: .specTypeNotMatchToInit(specType: typeName!, initType: initType)
                        ))
                    }
                }
            }
            
            if let typeName {
                result.append((variableName, typeName, isStatic))
            } else {
                diags.append(.init(node: binding, message: .cannotInferTypeWithoutAnnotation))
            }
        }
        
        if _isTopLevelSyntax(decl) {
            for (name, typeName, _) in result {
                if !_resolvedTopVariables.keys.contains(name) {
                    _resolvedTopVariables.updateValue(typeName, forKey: name)
                }
            }
        }
        
        return result
    }
}

// MARK: - Type-Check exprs
extension SemaEvaluator {
    internal func _typeCheckExpr(_ expr: ExprSyntax, diags: inout [Diagnostic]) {
        _ = _resolveExprType(expr, diags: &diags)
    }
}

// MARK: - Resolve
extension SemaEvaluator {
    internal func _resolveType(_ syntax: TypeSyntax, diags: inout [Diagnostic]) -> String? {
        if let idSyntax = syntax.as(IdentifierTypeSyntax.self) {
            if let clause = idSyntax.genericArgumentClause {
                diags.append(.init(node: clause, message: .genericNotSupported))
                return nil
            }
            
            let typeName = idSyntax.name.text
            if _lookupTypeExistence(atRoot: typeName) {
                return idSyntax.name.text
            } else {
                diags.append(.init(node: syntax, message: .cannotFindTypeInScope(typeName)))
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
                desc += resolvedType
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
            result += " -> \(type)"
        }
        
        return result
    }
}

// MARK: Resolve - Type
extension SemaEvaluator {
    internal func _resolveExprType(_ expr: ExprSyntax, type: String? = nil, diags: inout [Diagnostic]) -> String? {
        if let awaitExpr = expr.as(AwaitExprSyntax.self) {
            // 'await' doesn't change the type,
            // we return the type of the wrapped expr
            return _resolveExprType(awaitExpr.expression, diags: &diags)
        } else if let boolLiteralExpr = expr.as(BooleanLiteralExprSyntax.self) {
            // A bool value always has the type 'Bool',
            // if the context determines another type that is
            // `ExpressibleByBooleanLiteral`, the caller should handle it
            guard _lookupTypeExistence(atRoot: "Bool") else {
                diags.append(.init(node: boolLiteralExpr, message: .missingStdlibType("Bool")))
                return nil
            }
            return "Bool"
        } else if let closureExpr = expr.as(ClosureExprSyntax.self) {
            // A closure always has the type 'Closure'
            guard _lookupTypeExistence(atRoot: "Closure") else {
                diags.append(.init(node: closureExpr, message: .missingStdlibType("Closure")))
                return nil
            }
            _typeCheckCodeBlock(closureExpr.statements, diags: &diags)
            return "Closure"
        } else if let declRefExpr = expr.as(DeclReferenceExprSyntax.self) {
            return _resolveDeclRefExprType(declRefExpr, diags: &diags)
        } else if let floatLiteralExpr = expr.as(FloatLiteralExprSyntax.self) {
            // A float value always has the type 'Float',
            // if the context determines another type that is
            // `ExpressibleByFloatLiteral`, the caller should handle it
            guard _lookupTypeExistence(atRoot: "Float") else {
                diags.append(.init(node: floatLiteralExpr, message: .missingStdlibType("Float")))
                return nil
            }
            return "Float"
        } else if let funcCallExpr = expr.as(FunctionCallExprSyntax.self) {
            return _resolveFuncCallExprType(funcCallExpr, type: type, diags: &diags)
        } else if let infixOperatorExpr = expr.as(InfixOperatorExprSyntax.self) {
            // Only assignment infix operator is valid currently,
            // and an assignment expr always has the type 'Void'
            guard infixOperatorExpr.operator.is(AssignmentExprSyntax.self) else {
                let operatorName = infixOperatorExpr.operator
                    .as(BinaryOperatorExprSyntax.self)?.operator.text
                diags.append(.init(node: infixOperatorExpr.operator, message: .unsupportedOperator(operatorName)))
                return nil
            }
            return ""
        } else if let intLiteralExpr = expr.as(IntegerLiteralExprSyntax.self) {
            // A integer value always has the type 'Int',
            // if the context determines another type that is
            // `ExpressibleByIntegerLiteral`, the caller should handle it
            guard _lookupTypeExistence(atRoot: "Int") else {
                diags.append(.init(node: intLiteralExpr, message: .missingStdlibType("Int")))
                return nil
            }
            return "Int"
        } else if let memberAccessExpr = expr.as(MemberAccessExprSyntax.self) {
            return _resolveMemberAccessExprType(memberAccessExpr, type: type, diags: &diags)
        } else if let seqExpr = expr.as(SequenceExprSyntax.self) {
            // We have to use SwiftOperators to fold this expr
            // then resolve the folded expr
            let precedence = OperatorTable.standardOperators
            if let foldedExpr = try? precedence.foldSingle(seqExpr) {
                return _resolveExprType(foldedExpr, diags: &diags)
            } else {
                diags.append(.init(node: seqExpr, message: .failedToFoldOperators))
                return nil
            }
        } else if let stringLiteralExpr = expr.as(StringLiteralExprSyntax.self) {
            // A string value always has the type 'String',
            // if the context determines another type that is
            // `ExpressibleByStringLiteral`, the caller should handle it
            guard _lookupTypeExistence(atRoot: "String") else {
                diags.append(.init(node: stringLiteralExpr, message: .missingStdlibType("String")))
                return nil
            }
            return "String"
        } else {
            return nil
        }
    }
    
    internal func _resolveDeclRefExprType(_ expr: DeclReferenceExprSyntax, diags: inout [Diagnostic]) -> String? {
        let baseName = expr.baseName.text
        if let parent = expr.parent,
           let memberAccessExpr = parent.as(MemberAccessExprSyntax.self),
           expr != memberAccessExpr.base?.as(DeclReferenceExprSyntax.self) {
            return _resolveMemberAccessExprType(memberAccessExpr, diags: &diags)
        } else {
            // It should be a single identifier
            if let result = _lookupTopDeclType(baseName) {
                return result
            } else {
                diags.append(.init(node: expr.baseName, message: .cannotFindRefInScope(baseName)))
                return nil
            }
        }
    }
    
    internal func _resolveFuncCallExprType(_ expr: FunctionCallExprSyntax, type: String? = nil, diags: inout [Diagnostic]) -> String? {
        guard var calledExprType = _resolveExprType(expr.calledExpression, type: type, diags: &diags) else {
            return nil
        }
        
        if calledExprType == "<circular>" {
            diags.append(.init(node: expr.calledExpression, message: .circularRefInExpr))
            return nil
        }
        
        if !calledExprType.contains("/f") {
            if calledExprType.hasSuffix(".Type") {
                // Calling type itself as a function implicitly
                // calls the initializer
                calledExprType.removeLast(".Type".count)
                calledExprType += "/f" + "init"
            } else {
                diags.append(.init(node: expr, message: .cannotCallNonFuncValue(ofType: calledExprType)))
                return nil
            }
        }
        
        let _splitType = calledExprType.split(separator: "/f")
        let superType = _splitType[0]
        let funcName = _splitType[1]
        
        var candidates: [FunctionDeclSyntax] = []
        if superType == "~TOP" {
            for source in self.sources {
                for statement in source.statements {
                    let item = statement.item
                    if let decl = item.as(FunctionDeclSyntax.self),
                       decl.name.text == funcName {
                        candidates.append(decl)
                    }
                }
            }
        } else {
            for source in self.sources {
                for statement in source.statements {
                    let item = statement.item
                    if let decl = item.as(StructDeclSyntax.self),
                       decl.name.text == superType {
                        for member in decl.memberBlock.members {
                            if let decl = member.decl.as(FunctionDeclSyntax.self),
                               decl.name.text == funcName {
                                candidates.append(decl)
                            } else if funcName == "init",
                                      let decl = member.decl.as(InitializerDeclSyntax.self) {
                                candidates.append(decl.asFunctionDecl(returns: String(superType)))
                            }
                        }
                    }
                }
            }
        }
        
        let closureIdentifier = "/closure/"
        var calledArgs = expr.arguments
        if let closure = expr.trailingClosure {
            calledArgs.append(.init(label: .identifier(closureIdentifier), expression: closure))
        }
        
        var comparedCandidates: [(FunctionDeclSyntax, [Diagnostic])] = []
        for candidate in candidates where candidate.signature.parameterClause.parameters.count == calledArgs.count {
            var d: [Diagnostic] = []
            
            if calledArgs.count > 0 {
                // Compare parameters one-by-one
                for index in 0..<calledArgs.count {
                    let declParam = Array(candidate.signature.parameterClause.parameters)[index]
                    let callParam = Array(calledArgs)[index]
                    
                    // Compare argument label
                    if declParam.firstName.text != (callParam.label?.text ?? "_") && callParam.label?.text != closureIdentifier {
                        if declParam.firstName.text == "_", let callText = callParam.label?.text {
                            d.append(.init(node: callParam, message: .callExtraArgLabel(callText)))
                        } else if callParam.label == nil {
                            d.append(.init(node: callParam, message: .callMissingArgLabel(declParam.firstName.text)))
                        } else {
                            d.append(.init(
                                node: callParam,
                                message: .callIncorrectArgLabel(
                                    have: callParam.label?.text ?? "_",
                                    expected: declParam.firstName.text
                                )
                            ))
                        }
                    }
                    
                    // Compare type
                    if let declType = _resolveType(declParam.type, diags: &d) {
                        if let callType = _resolveExprType(callParam.expression, type: declType, diags: &d) {
                            if declType != callType {
                                d.append(.init(
                                    node: callParam.expression,
                                    message: .callArgTypeNotMatchToDecl(
                                        callType: callType,
                                        declType: declType
                                    )
                                ))
                            }
                        } else {
                            if let memberAccessExpr = callParam.expression.as(MemberAccessExprSyntax.self),
                               memberAccessExpr.base == nil {
                                let inference = _inferPartialExprType(
                                    memberAccessExpr,
                                    candidates: candidates.compactMap {
                                        let params = Array($0.signature.parameterClause.parameters)
                                        if params.count == calledArgs.count {
                                            if let type = _resolveType(params[index].type, diags: &d) {
                                                return type
                                            } else {
                                                return nil
                                            }
                                        } else {
                                            return nil
                                        }
                                    }
                                )
                                switch inference {
                                case .none:
                                    d.append(.init(node: memberAccessExpr, message: .cannotInferTypeWithoutAnnotation))
                                case .exact:
                                    break
                                case .multiple:
                                    d.append(.init(
                                        node: memberAccessExpr,
                                        message: .callAmbiguousMemberOverload(memberAccessExpr.declName.baseName.text)
                                    ))
                                }
                            }
                        }
                    } // The type-checker emits an error if `declType` can't
                      // be determined, so we do nothing
                }
            }
            
            // Check for async-await call
            // Calling an `async` function without `await` is allowed,
            // but the counter is not allowed
            if let _parent = expr.parent,
               let awaitExpr = _parent.as(AwaitExprSyntax.self),
                candidate.signature.effectSpecifiers?.asyncSpecifier == nil {
                d.append(.init(node: awaitExpr.awaitKeyword, message: .awaitCallUnsupportedFunc))
            }
            
            comparedCandidates.append((candidate, d))
        }
        
        guard !comparedCandidates.isEmpty else {
            diags.append(.init(node: expr, message: .callNoExactMatchToFunc(String(funcName))))
            return nil
        }
        
        let qualifiedCollection = comparedCandidates.min { $0.1.count < $1.1.count }!
        let qualifiedDecl = qualifiedCollection.0
        diags.append(contentsOf: qualifiedCollection.1) // Add diags produced during resolution
        var _d: [Diagnostic] = []
        resolvedFuncCalls.updateValue(_typeCheckAnyFunctionDecl(qualifiedDecl, diags: &_d), forKey: expr.hashValue)
        if let clause = qualifiedDecl.signature.returnClause {
            return _resolveType(clause.type, diags: &diags)
        } else {
            return ""
        }
    }
    
    internal func _resolveMemberAccessExprType(_ expr: MemberAccessExprSyntax, type: String? = nil, diags: inout [Diagnostic]) -> String? {
        if let base = expr.base {
            if let baseType = _resolveExprType(base, diags: &diags) {
                if let result = _lookupMemberType(expr.declName.baseName.text, of: baseType) {
                    return result
                } else {
                    diags.append(.init(node: expr.declName, message: .typeValueHasNoMember(type: baseType, member: expr.declName.baseName.text)))
                    return nil
                }
            }
        } else if let type {
            let baseType = "\(type).Type"
            if let result = _lookupMemberType(expr.declName.baseName.text, of: baseType) {
                return result
            } else {
                diags.append(.init(node: expr.declName, message: .typeValueHasNoMember(type: baseType, member: expr.declName.baseName.text)))
                return nil
            }
        }
        return nil
    }
}

// MARK: - Lookup

// If a function type presents during look up:
// <function-type> ::= <base-type> '/f' <function-name>
// <base-type> ::= <type> | '~TOP'
// <type> ::= [A-Za-z_0-9]+
// <function-name> ::= [A-Za-z_0-9]+
//
// To represent a metatype:
// <metatype> ::= <type> '.Type'
// <type> ::= [A-Za-z_0-9]+
extension SemaEvaluator {
    internal func _lookupTypeExistence(atRoot typeName: String) -> Bool {
        // fast-path
        if _resolvedStructs.keys.contains(typeName)
            || _resolvedEnums.keys.contains(typeName) {
            return true
        }
        
        // We iterate over all root decls and do a quick check.
        // Since this doesn't actually perform a fully type-check,
        // we can't add results to resolved lists
        for source in self.sources {
            for statement in source.statements {
                let item = statement.item
                if let structDecl = item.as(StructDeclSyntax.self) {
                    if typeName == structDecl.name.text {
                        return true
                    }
                } else if let enumDecl = item.as(EnumDeclSyntax.self) {
                    if typeName == enumDecl.name.text {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    internal func _lookupTopDeclType(_ name: String) -> String? {
        // Find from resolved list first
        if _resolvedStructs[name] != nil {
            return name + ".Type"
        }
        if _resolvedTopFunctions.contains(where: { $0.name == name }) {
            return "~TOP/f" + name
        }
        if let v = _resolvedTopVariables[name] {
            return v
        }
        
        // Iterate over root for decls and do a search
        for source in self.sources {
            for statement in source.statements {
                let item = statement.item
                if let decl = item.as(FunctionDeclSyntax.self),
                   decl.name.text == name {
                    return "~TOP/f" + name
                } else if let decl = item.as(StructDeclSyntax.self),
                          decl.name.text == name {
                    return name + ".Type"
                } else if let decl = item.as(VariableDeclSyntax.self) {
                    var diags: [Diagnostic] = []
                    let resolvedVar = _typeCheckVariableDecl(decl, diags: &diags)
                    if let v = resolvedVar.first(where: { $0.name == name }) {
                        return v.typeName
                    }
                }
            }
        }
        
        return nil
    }
    
    internal func _lookupMemberType(_ memberName: String, of baseType: String) -> String? {
        // Find from resolved list first
        let fixedBaseType = baseType.hasSuffix(".Type") ? String(baseType.dropLast(".Type".count)) : baseType
        if let s = _resolvedStructs[fixedBaseType] {
            if baseType.hasSuffix(".Type") {
                if memberName == "init" {
                    return "\(fixedBaseType)/finit"
                }
                if s.staticMethods.contains(where: { $0.name == memberName }) {
                    return "\(fixedBaseType)/f" + memberName
                }
                return s.staticVariables[memberName]
            } else {
                if s.instanceMethods.contains(where: { $0.name == memberName }) {
                    return "\(fixedBaseType)/f" + memberName
                }
                return s.instanceVariables[memberName]
            }
        }
        if _resolvedEnums[fixedBaseType] != nil {
            // Enum case is an instance of the enum itself
            return fixedBaseType
        }
        
        // Iterate over root for type decls and do a search
        for source in self.sources {
            for statement in source.statements {
                let item = statement.item
                if let structDecl = item.as(StructDeclSyntax.self),
                   fixedBaseType == structDecl.name.text {
                    if memberName == "init" {
                        return "\(fixedBaseType)/finit"
                    }
                    
                    for member in structDecl.memberBlock.members {
                        if let decl = member.decl.as(FunctionDeclSyntax.self),
                           decl.name.text == memberName {
                            return "\(fixedBaseType)/f" + memberName
                        } else if let decl = member.decl.as(VariableDeclSyntax.self) {
                            var diags: [Diagnostic] = []
                            let resolvedVar = _typeCheckVariableDecl(decl, diags: &diags)
                            if baseType.hasSuffix(".Type") {
                                if let v = resolvedVar.first(where: { $0.name == memberName && $0.isStatic }) {
                                    return v.typeName
                                }
                            } else {
                                if let v = resolvedVar.first(where: { $0.name == memberName && !$0.isStatic }) {
                                    return v.typeName
                                }
                            }
                        }
                    }
                } else if let enumDecl = item.as(EnumDeclSyntax.self),
                          fixedBaseType == enumDecl.name.text {
                    // Enum case is an instance of the enum itself
                    return fixedBaseType
                }
            }
        }
        
        return nil
    }
}

// MARK: - Type Inference
extension SemaEvaluator {
    internal func _inferPartialExprType(_ expr: MemberAccessExprSyntax, candidates: [String]) -> _TypeInferenceResult {
        assert(expr.base == nil, "type of qualified member access shouldn't be determined by inference")
        
        let partialName = expr.declName.baseName.text
        
        var results: [String] = []
        for candidate in candidates {
            if let type = _lookupMemberType(partialName, of: candidate + ".Type") {
                results.append(type)
            }
        }
        
        if results.isEmpty {
            return .none
        } else if results.count == 1 {
            return .exact(results[0])
        } else {
            return .multiple(results)
        }
    }
    
    internal enum _TypeInferenceResult {
        case none
        case exact(String)
        case multiple([String])
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

extension InitializerDeclSyntax {
    internal func asFunctionDecl(returns returnType: String? = nil) -> FunctionDeclSyntax {
        var signature = self.signature
        if let returnType {
            signature = signature.with(\.returnClause, .init(type: IdentifierTypeSyntax(name: .identifier(returnType))))
        }
        
        return .init(
            attributes: self.attributes,
            modifiers: self.modifiers,
            name: self.initKeyword,
            genericParameterClause: self.genericParameterClause,
            signature: signature,
            genericWhereClause: self.genericWhereClause,
            body: self.body
        )
    }
}
