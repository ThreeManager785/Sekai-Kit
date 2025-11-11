//===---*- Greatdori! -*---------------------------------------------------===//
//
// CodeCompletion.swift
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
internal import SwiftParser
internal import SwiftSyntaxBuilder

#if os(macOS)
import AppKit
#else
import UIKit
#endif

private let stdlibSource = {
    Parser.parse(source: try! .init(
        contentsOf: #bundle.url(
            forResource: "Stdlib",
            withExtension: "zeile"
        )!,
        encoding: .utf8
    ))
}()

internal func _completeZeileCode(
    _ code: String,
    at index: String.Index
) -> [CodeCompletionItem] {
    guard let position = index.samePosition(in: code.utf8) else {
        return []
    }
    let offset = code.utf8.distance(
        from: code.utf8.startIndex,
        to: position
    )
    
    let source = Parser.parse(source: code)
    let allSources = [stdlibSource, source]
    
    guard let token = source.token(at: .init(utf8Offset: offset)) else {
        return []
    }
    
    var result: [CodeCompletionItem] = []
    
    guard let fullParent = fullParent(of: token) else {
        return []
    }
    
    if fullParent.is(DeclReferenceExprSyntax.self) {
        result.append(contentsOf: lookupToken(token, in: allSources))
    } else if let memberAccess = fullParent.as(MemberAccessExprSyntax.self) {
        if memberAccess.declName.baseName == token || token.text == "." {
            let sema = SemaEvaluator(allSources)
            _ = sema.performSema()
            
            if let decl = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
                let declName = decl.baseName.text
                if sema._resolvedStructs[declName] != nil
                    || sema._resolvedEnums[declName] != nil {
                    result.append(contentsOf: lookupMember(token, ofType: "\(declName).Type", in: sema))
                } else if let type = sema._resolvedTopVariables[declName] {
                    result.append(contentsOf: lookupMember(token, ofType: type, in: sema))
                }
            } else if memberAccess.base == nil {
                if let accessParent = DoriKit.fullParent(of: memberAccess) {
                    if let funcCall = accessParent.as(FunctionCallExprSyntax.self),
                       let decl = sema.resolvedFuncCalls[funcCall.hashValue] {
                        for (index, arg) in funcCall.arguments.enumerated() {
                            guard decl.parameters.startIndex..<decl.parameters.endIndex ~= index else {
                                break
                            }
                            if arg.expression.as(MemberAccessExprSyntax.self) == memberAccess {
                                result.append(contentsOf: lookupMember(
                                    token,
                                    ofType: "\(decl.parameters[index].typeName).Type",
                                    in: sema
                                ))
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    let tokenString = token.text
    result.sort { lhs, rhs in
        matchScore(for: lhs.displayName.string, query: tokenString)
        > matchScore(for: rhs.displayName.string, query: tokenString)
    }
    
    return result
}

public struct CodeCompletionItem: Hashable {
    public let itemType: ItemType
    public let declaration: NSAttributedString
    public let displayName: NSAttributedString
    
    internal let currentSyntax: TokenSyntax
    internal let replacementSyntax: TokenSyntax
    
    public var replacedCode: String {
        replacementSyntax.root.description
    }
    public var replacingLength: Int {
        replacementSyntax.text.count - currentSyntax.text.count
    }
    
    public enum ItemType: String, Hashable {
        case variable
        case function
        case staticMethod
        case instanceMethod
        case structure
        case enumeration
        case keyword
    }
}

private func fullParent(of syntax: some SyntaxProtocol) -> Syntax? {
    guard let parent = syntax.parent else {
        return nil
    }
    if parent.is(DeclSyntax.self) || parent.is(ExprSyntax.self) {
        return Syntax(_findMemberAccess(parent)) ?? parent
    } else {
        return fullParent(of: parent)
    }
}
private func _findMemberAccess(_ syntax: some SyntaxProtocol) -> MemberAccessExprSyntax? {
    guard let parent = syntax.parent else {
        return nil
    }
    if let expr = parent.as(MemberAccessExprSyntax.self) {
        return expr
    } else {
        return _findMemberAccess(parent)
    }
}

private func lookupToken(
    _ token: TokenSyntax,
    in sources: [SourceFileSyntax]
) -> [CodeCompletionItem] {
    var result: [CodeCompletionItem] = []
    
    let text = token.text
    
    let attributeRemover = AttributeRemover()
    
    for source in sources {
        for statement in source.statements {
            let item = statement.item
            if let decl = item.as(VariableDeclSyntax.self) {
                for binding in decl.bindings {
                    guard let idText = binding.pattern
                        .as(IdentifierPatternSyntax.self)?
                        .identifier
                        .text else {
                        continue
                    }
                    let match = idText.matchCompletionInput(of: text)
                    if !match.isEmpty {
                        result.append(.init(
                            itemType: .variable,
                            declaration: highlight(for: decl),
                            displayName: displayName(for: idText, matched: match),
                            currentSyntax: token,
                            replacementSyntax: token.with(\.tokenKind, .identifier(idText))
                        ))
                    }
                }
            } else if let decl = item.as(FunctionDeclSyntax.self) {
                var idText = decl.name.text
                idText += decl.signature.parameterClause.description.replacing("\n", with: " ")
                let match = idText.matchCompletionInput(of: text)
                if !match.isEmpty {
                    var replaceResult = decl.name.text
                    var params = decl.signature.parameterClause
                    params = attributeRemover.rewrite(params)
                        .cast(FunctionParameterClauseSyntax.self)
                    var replacementParams: [FunctionParameterSyntax] = []
                    for parameter in params.parameters {
                        var newParam = parameter
                        if let type = newParam.type.as(IdentifierTypeSyntax.self) {
                            newParam = newParam.with(
                                \.type,
                                 TypeSyntax(type.with(
                                    \.name,
                                     .identifier("<#\(type.name.text)#>")
                                     // The placeholder above is expected
                                 ))
                            )
                        }
                        newParam = newParam.with(\.secondName, nil)
                        if newParam.firstName.text == "_" {
                            newParam = newParam.with(\.firstName, .identifier(""))
                            newParam = newParam.with(\.colon, .identifier(""))
                        }
                        replacementParams.append(newParam)
                    }
                    params = params.with(
                        \.parameters,
                         .init(replacementParams)
                    )
                    replaceResult += params.description.replacing("\n", with: " ")
                    result.append(.init(
                        itemType: .function,
                        declaration: highlight(for: decl),
                        displayName: displayName(for: idText, matched: match),
                        currentSyntax: token,
                        replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                    ))
                }
            } else if let decl = item.as(StructDeclSyntax.self) {
                let idText = decl.name.text
                let match = idText.matchCompletionInput(of: text)
                if !match.isEmpty {
                    var cleanDecl = decl.with(\.memberBlock, .init(members: []))
                    cleanDecl = cleanDecl.with(\.memberBlock.leftBrace, .identifier(""))
                    cleanDecl = cleanDecl.with(\.memberBlock.rightBrace, .identifier(""))
                    result.append(.init(
                        itemType: .structure,
                        declaration: highlight(for: cleanDecl),
                        displayName: displayName(for: idText, matched: match),
                        currentSyntax: token,
                        replacementSyntax: token.with(\.tokenKind, .identifier(idText))
                    ))
                    
                    for member in decl.memberBlock.members {
                        if let initializer = member.decl.as(InitializerDeclSyntax.self) {
                            let displayText = idText + initializer.signature
                                .parameterClause.description
                                .replacing("\n", with: " ")
                            var replaceResult = decl.name.text
                            var params = initializer.signature.parameterClause
                            params = attributeRemover.rewrite(params)
                                .cast(FunctionParameterClauseSyntax.self)
                            var replacementParams: [FunctionParameterSyntax] = []
                            for parameter in params.parameters {
                                var newParam = parameter
                                if let type = newParam.type.as(IdentifierTypeSyntax.self) {
                                    newParam = newParam.with(
                                        \.type,
                                         TypeSyntax(type.with(
                                            \.name,
                                             .identifier("<#\(type.name.text)#>")
                                             // The placeholder above is expected
                                         ))
                                    )
                                }
                                newParam = newParam.with(\.secondName, nil)
                                if newParam.firstName.text == "_" {
                                    newParam = newParam.with(\.firstName, .identifier(""))
                                    newParam = newParam.with(\.colon, .identifier(""))
                                }
                                replacementParams.append(newParam)
                            }
                            params = params.with(
                                \.parameters,
                                 .init(replacementParams)
                            )
                            replaceResult += params.description.replacing("\n", with: " ")
                            result.append(.init(
                                itemType: .staticMethod,
                                declaration: highlight(for: initializer),
                                displayName: displayName(for: displayText, matched: match),
                                currentSyntax: token,
                                replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                            ))
                        }
                    }
                }
            } else if let decl = item.as(EnumDeclSyntax.self) {
                let idText = decl.name.text
                let match = idText.matchCompletionInput(of: text)
                if !match.isEmpty {
                    var cleanDecl = decl.with(\.memberBlock, .init(members: []))
                    cleanDecl = cleanDecl.with(\.memberBlock.leftBrace, .identifier(""))
                    cleanDecl = cleanDecl.with(\.memberBlock.rightBrace, .identifier(""))
                    result.append(.init(
                        itemType: .enumeration,
                        declaration: highlight(for: cleanDecl),
                        displayName: displayName(for: idText, matched: match),
                        currentSyntax: token,
                        replacementSyntax: token.with(\.tokenKind, .identifier(idText))
                    ))
                }
            }
        }
    }
    
    return result
}
private func lookupMember(
    _ token: TokenSyntax,
    ofType baseType: String,
    in sema: SemaEvaluator
) -> [CodeCompletionItem] {
    var result: [CodeCompletionItem] = []
    
    let text = token.text
    
    var isStatic = false
    var baseType = baseType
    if baseType.hasSuffix(".Type") {
        baseType.removeLast(".Type".count)
        isStatic = true
    }
    
    func addFunction(
        _ function: SemaEvaluator.FunctionDeclaration,
        isInitializer: Bool = false
    ) {
        var idText = function.name
        idText += "("
        var paramTexts: [String] = []
        for param in function.parameters {
            paramTexts.append("\(param.name): \(param.typeName)")
        }
        idText += paramTexts.joined(separator: ", ")
        idText += ")"
        
        var replaceResult = function.name
        if text == "." {
            replaceResult = "." + replaceResult
        }
        replaceResult += "("
        paramTexts = []
        for param in function.parameters {
            let prefix = param.name != "_" && param.name != "" ? "\(param.name): " : ""
            paramTexts.append("\(prefix)<#\(param.typeName)#>")
        }
        replaceResult += paramTexts.joined(separator: ", ")
        replaceResult += ")"
        
        let match = idText.matchCompletionInput(of: text)
        if !match.isEmpty || text == "." {
            let decl: DeclSyntax
            if isInitializer {
                decl = .init((try? InitializerDeclSyntax(
                    .init(stringLiteral: idText)
                )) ?? .init(signature: .init(parameterClause: .init(parameters: []))))
            } else {
                decl = .init((try? FunctionDeclSyntax(
                    .init(stringLiteral: "func \(idText)")
                )) ?? .init(name: .identifier(""), signature: .init(parameterClause: .init(parameters: []))))
            }
            result.append(
                .init(
                    itemType: isStatic ? .staticMethod : .instanceMethod,
                    declaration: highlight(for: decl),
                    displayName: displayName(for: idText, matched: match),
                    currentSyntax: token,
                    replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                )
            )
        }
    }
    func addVariable(_ name: String, type: String) {
        let idText = name
        let match = idText.matchCompletionInput(of: text)
        if !match.isEmpty || text == "." {
            var replaceResult = idText
            if text == "." {
                replaceResult = "." + replaceResult
            }
            result.append(
                .init(
                    itemType: isStatic ? .staticMethod : .instanceMethod,
                    declaration: highlight(
                        for: (try? VariableDeclSyntax(
                                .init(stringLiteral: "let \(name): \(type)")
                        )) ?? VariableDeclSyntax(.let,
                            name: PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("")))
                        )
                    ),
                    displayName: displayName(for: idText, matched: match),
                    currentSyntax: token,
                    replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                )
            )
        }
    }
    
    if let resolved = sema._resolvedStructs[baseType] {
        if isStatic {
            for initializer in resolved.initializers {
                addFunction(initializer, isInitializer: true)
            }
            for method in resolved.staticMethods {
                addFunction(method)
            }
            for variable in resolved.staticVariables {
                addVariable(variable.key, type: variable.value)
            }
        } else {
            for method in resolved.instanceMethods {
                addFunction(method)
            }
            for variable in resolved.instanceVariables {
                addVariable(variable.key, type: variable.value)
            }
        }
    } else if isStatic, let resolved = sema._resolvedEnums[baseType] {
        for c in resolved.cases {
            let idText = c
            let match = idText.matchCompletionInput(of: text)
            if !match.isEmpty || text == "." {
                var replaceResult = idText
                if text == "." {
                    replaceResult = "." + replaceResult
                }
                result.append(
                    .init(
                        itemType: .staticMethod,
                        declaration: highlight(
                            for: (try? EnumCaseDeclSyntax(
                                .init(stringLiteral: "case \(c)")
                            )) ?? .init(elements: [])
                        ),
                        displayName: displayName(for: idText, matched: match),
                        currentSyntax: token,
                        replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                    )
                )
            }
        }
    }
    
    return result
}

private func highlight(for syntax: some SyntaxProtocol) -> NSAttributedString {
    var string = syntax.description.replacing("\n", with: " ")
    while string.hasPrefix(" ") {
        string.removeFirst()
    }
    while string.hasSuffix(" ") {
        string.removeLast()
    }
    let result = NSMutableAttributedString(
        string: string
    )
    _highlightZeileCode(for: result, config: .init())
    return .init(attributedString: result)
}
private func displayName(
    for text: String,
    matched indexs: [String.Index]
) -> NSAttributedString {
    let result = NSMutableAttributedString(string: text)
    #if os(macOS)
    result.addAttribute(
        .foregroundColor,
        value: NSColor(named: "ZeileCompletionUnhit", bundle: #bundle)!,
        range: .init(location: 0, length: result.length)
    )
    result.addAttribute(
        .font,
        value: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
        range: .init(location: 0, length: result.length)
    )
    for index in indexs {
        result.addAttribute(
            .foregroundColor,
            value: NSColor.textColor,
            range: .init(index...index, in: text)
        )
    }
    #else
    
    #endif
    return .init(attributedString: result)
}

private final class AttributeRemover: SyntaxRewriter {
    override func visit(_ node: AttributedTypeSyntax) -> TypeSyntax {
        return node.baseType
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        return DeclSyntax(node.with(\.attributes, []))
    }
}

private func matchScore(for candidate: String, query: String) -> Double {
    let candChars = Array(candidate)
    let queryChars = Array(query)
    let lowerCand = Array(candidate.lowercased())
    let lowerQuery = Array(query.lowercased())
    
    var indices: [Int] = []
    var i = 0, j = 0
    var caseMatchScore = 0.0
    
    while i < lowerCand.count, j < lowerQuery.count {
        if lowerCand[i] == lowerQuery[j] {
            indices.append(i)
            
            // 如果大小写完全一致，额外加分
            if candChars[i] == queryChars[j] {
                caseMatchScore += 1.0
            } else {
                // 大小写不同，稍微低一些
                caseMatchScore += 0.5
            }
            
            j += 1
        }
        i += 1
    }
    guard j == lowerQuery.count else { return 0 }
    
    var prefixScore = 0
    for (a, b) in zip(lowerCand, lowerQuery) {
        if a == b {
            prefixScore += 1
        } else {
            break
        }
    }
    
    var maxConsecutive = 1
    var current = 1
    for k in 1..<indices.count {
        if indices[k] == indices[k - 1] + 1 {
            current += 1
        } else {
            maxConsecutive = max(maxConsecutive, current)
            current = 1
        }
    }
    maxConsecutive = max(maxConsecutive, current)
    
    let startOffset = Double(indices.first ?? candChars.count)
    
    let score =
    Double(prefixScore) * 3.0 +
    Double(maxConsecutive) * 2.0 +
    caseMatchScore * 1.0 -
    startOffset * 0.5
    
    return score
}


extension String {
    fileprivate func matchCompletionInput(
        of pattern: String
    ) -> [String.Index] {
        let lowerSelf = self.lowercased()
        let lowerPattern = pattern.lowercased()
        
        var indices: [String.Index] = []
        var i = self.startIndex
        var j = lowerPattern.startIndex
        
        while i < self.endIndex, j < lowerPattern.endIndex {
            if lowerSelf[i] == lowerPattern[j] {
                indices.append(i)
                j = lowerPattern.index(after: j)
            }
            i = self.index(after: i)
        }
        
        return j == lowerPattern.endIndex ? indices : []
    }
}
