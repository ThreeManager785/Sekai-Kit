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
internal import SwiftyJSON
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

private let assetListLock = NSLock()
nonisolated(unsafe) private var assetList: _DoriAPI.Assets.AssetList?
private let bundleFileListCacheLock = NSLock()
nonisolated(unsafe) private var cachedBundleFileList: [Int: [String]] = [:]
#if canImport(SwiftUI) && canImport(WebKit)
private let live2dModelCacheLock = NSLock()
nonisolated(unsafe) private var cachedLive2dModelList: [String: Live2DModel] = [:]
#endif

private let semaResultCacheLock = NSLock()
nonisolated(unsafe) private var cachedSemaResult: (Int, SemaEvaluator)?

internal func _completeZeileCode(
    _ code: String,
    at index: String.Index,
    in locale: _DoriAPI.Locale,
    assetFolder: FileWrapper? = nil
) -> [CodeCompletionItem] {
    assert(
        !Thread.isMainThread,
        "code completion should not be called on the main thread"
    )
    
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
    
    var lineBreakCount: Int?
    var sema: SemaEvaluator {
        let lf = lineBreakCount ?? code.count { $0 == "\n" }
        lineBreakCount = lf
        if let (expLf, sema) = semaResultCacheLock.withLock({
            unsafe cachedSemaResult
        }), expLf == lf {
            return sema
        } else {
            let sema = SemaEvaluator(allSources, in: locale)
            _ = sema.performSema()
            semaResultCacheLock.withLock {
                unsafe cachedSemaResult = (lf, sema)
            }
            return sema
        }
    }
    
    lookup: if let fullParent = fullParent(of: token) {
        if fullParent.is(DeclReferenceExprSyntax.self) {
            result.append(contentsOf: lookupToken(token, in: allSources))
        } else if !(token.trimmedRange ~= .init(utf8Offset: offset)) {
            result.append(contentsOf: lookupToken(
                token.with(\.tokenKind, .identifier("")),
                in: allSources
            ))
        } else if let memberAccess = fullParent.as(MemberAccessExprSyntax.self) {
            if memberAccess.declName.baseName == token || token.text == "." {
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
        } else if let stringLiteral = fullParent.as(StringLiteralExprSyntax.self),
                  let stringParent = DoriKit.fullParent(of: stringLiteral),
                  let funcCall = stringParent.as(FunctionCallExprSyntax.self) {
            // Lookup Path
            guard _prepareAssetListForZeileCompletion() else { break lookup }
            
            result.append(contentsOf: lookupPath(
                token,
                inside: stringLiteral,
                in: funcCall,
                with: sema,
                assetFolder: assetFolder
            ))
            
            #if canImport(SwiftUI) && canImport(WebKit)
            if result.isEmpty {
                // Lookup Live2D
                result.append(contentsOf: lookupLive2D(
                    token,
                    inside: stringLiteral,
                    within: funcCall,
                    in: locale,
                    with: sema
                ))
            }
            #endif // canImport(SwiftUI) && canImport(WebKit)
        }
    }
    
    result.append(contentsOf: lookupKeyword(token))
    
    let tokenString = token.text
    result.sort { lhs, rhs in
        let lscore = matchScore(for: lhs.displayName.string, query: tokenString)
        let rscore = matchScore(for: rhs.displayName.string, query: tokenString)
        if _fastPath(lscore != rscore) {
            return lscore > rscore
        } else {
            return lhs.displayName.string < rhs.displayName.string
        }
    }
    
    return result
}

public struct CodeCompletionItem: Hashable {
    public let itemType: ItemType
    public let declaration: NSAttributedString
    public let displayName: NSAttributedString
    public let previewContent: PreviewContent?
    
    internal let currentSyntax: TokenSyntax
    internal let replacementSyntax: TokenSyntax
    
    internal init(
        itemType: ItemType,
        declaration: NSAttributedString,
        displayName: NSAttributedString,
        previewContent: PreviewContent? = nil,
        currentSyntax: TokenSyntax,
        replacementSyntax: TokenSyntax
    ) {
        self.itemType = itemType
        self.declaration = declaration
        self.displayName = displayName
        self.previewContent = previewContent
        self.currentSyntax = currentSyntax
        self.replacementSyntax = replacementSyntax
    }
    
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
        case file
        case folder
    }
    
    public enum PreviewContent: Hashable {
        case image(URL)
        case live2d(URL)
        #if canImport(SwiftUI) && canImport(WebKit)
        case live2dMotion(URL, Live2DMotion)
        case live2dExpression(URL, Live2DExpression)
        #endif
    }
}

@discardableResult
internal func _prepareAssetListForZeileCompletion() -> Bool {
    assetListLock.lock()
    guard unsafe assetList == nil else {
        assetListLock.unlock()
        return true
    }
    assetListLock.unlock()
    
    Task.detached {
        if let list = await _DoriAPI.Assets.info(in: .jp) {
            assetListLock.withLock {
                unsafe assetList = list
            }
        }
    }
    return false
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
                    if !match.isEmpty || text.isEmpty {
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
                if !match.isEmpty || text.isEmpty {
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
                if !match.isEmpty || text.isEmpty {
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
                            var params = initializer.signature.parameterClause
                            params = attributeRemover.rewrite(params)
                                .cast(FunctionParameterClauseSyntax.self)
                            
                            let displayText = idText + params.description
                                .replacing("\n", with: " ")
                            
                            var replaceResult = decl.name.text
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
                if !match.isEmpty || text.isEmpty {
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
            result.append(.init(
                itemType: isStatic ? .staticMethod : .instanceMethod,
                declaration: highlight(for: decl),
                displayName: displayName(for: idText, matched: match),
                currentSyntax: token,
                replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
            ))
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
            result.append(.init(
                itemType: isStatic ? .staticMethod : .instanceMethod,
                declaration: highlight(
                    for: (try? VariableDeclSyntax(
                        .init(stringLiteral: "let \(name): \(type)")
                    )) ?? .init(.let, name: PatternSyntax(IdentifierPatternSyntax(identifier: .identifier(""))))
                ),
                displayName: displayName(for: idText, matched: match),
                currentSyntax: token,
                replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
            ))
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
                result.append(.init(
                    itemType: .staticMethod,
                    declaration: highlight(
                        for: (try? EnumCaseDeclSyntax(
                            .init(stringLiteral: "case \(c)")
                        )) ?? .init(elements: [])
                    ),
                    displayName: displayName(for: idText, matched: match),
                    currentSyntax: token,
                    replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                ))
            }
        }
    }
    
    return result
}
private func lookupPath(
    _ token: TokenSyntax,
    inside argument: StringLiteralExprSyntax,
    in funcCall: FunctionCallExprSyntax,
    with sema: SemaEvaluator,
    assetFolder: FileWrapper?
) -> [CodeCompletionItem] {
    assert(unsafe assetList != nil)
    guard let assetList = unsafe assetList else { return [] }
    
    guard let funcDecl = sema.resolvedFuncCalls[funcCall.hashValue] else {
        return []
    }
    
    var argIndex: Int?
    for (index, arg) in funcCall.arguments.enumerated() {
        if arg.expression.as(StringLiteralExprSyntax.self) == argument {
            argIndex = index
            break
        }
    }
    guard let argIndex else { return [] }
    
    let argAttrs = funcDecl.parameters[argIndex].attributes
    var pathPrefix: String?
    for attr in argAttrs where attr.name == "_pathPrefix" {
        pathPrefix = attr.arguments[0]
        break
    }
    guard let pathPrefix else { return [] }
    let path: String
    if token.text.hasPrefix("jp/")
        || token.text.hasPrefix("en/")
        || token.text.hasPrefix("tw/")
        || token.text.hasPrefix("cn/")
        || token.text.hasPrefix("kr/") {
        path = String(token.text.dropFirst(3))
    } else if token.text.hasPrefix("/") {
        path = token.text
    } else if token.text.hasPrefix("http://")
                || token.text.hasPrefix("https://") {
        return []
    } else {
        path = pathPrefix + token.text
    }
    
    guard let _lastInput = token.text.split(
        separator: "/",
        omittingEmptySubsequences: false
    ).last else { return [] }
    let lastInput = _lastInput != "\"" ? String(_lastInput) : ""
    //              ~~~~~~~~~~~~~~~^^~
    // The token is \" if the string literal is empty
    
    if !path.hasPrefix("/") {
        // Resolve from remote asset list
        
        var pathDesc = _DoriAPI.Assets.PathDescriptor(locale: .jp)
        func resolveChild(
            _ pathSeg: [String],
            in list: _DoriAPI.Assets.AssetList
        ) -> _DoriAPI.Assets.Child? {
            guard !pathSeg.isEmpty else {
                return .list(list)
            }
            
            var nextSeg = pathSeg
            let thisSeg = nextSeg.removeFirst()
            guard let child = list.access(thisSeg, updatingPath: &pathDesc) else {
                return nil
            }
            
            if nextSeg.isEmpty {
                return child
            }
            
            if case .list(let assetList) = child {
                return resolveChild(nextSeg, in: assetList)
            } else {
                return child
            }
        }
        guard let child = resolveChild(
            path.split(separator: "/", omittingEmptySubsequences: false)
                .map { String($0) }
                .dropLast()
                .compactMap { $0.isEmpty ? nil : $0 },
            in: assetList
        ) else { return [] }
        
        var result: [CodeCompletionItem] = []
        
        switch child {
        case .files:
            @safe nonisolated(unsafe) var contents: [String]?
            if let c = bundleFileListCacheLock
                .withLock({ unsafe cachedBundleFileList[pathDesc.hashValue] }) {
                contents = c
            } else {
                let semaphore = DispatchSemaphore(value: 0)
                let desc = pathDesc
                Task { @Sendable in
                    contents = await _DoriAPI.Assets.contentsOf(desc)
                    semaphore.signal()
                }
                semaphore.wait()
                if let contents {
                    _ = bundleFileListCacheLock.withLock {
                        unsafe cachedBundleFileList.updateValue(
                            contents,
                            forKey: pathDesc.hashValue
                        )
                    }
                }
            }
            if let contents {
                for name in contents {
                    let match = name.matchCompletionInput(of: lastInput)
                    if !match.isEmpty || lastInput.isEmpty {
                        var _replaceResult = token.text
                            .split(separator: "/", omittingEmptySubsequences: false)
                            .dropLast()
                        _replaceResult += [Substring(name)]
                        let replaceResult = _replaceResult.joined(separator: "/")
                        
                        var previewContent: CodeCompletionItem.PreviewContent?
                        if name.hasSuffix(".png") {
                            previewContent = .image(pathDesc.resourceURL(name: name))
                        }
                        
                        result.append(.init(
                            itemType: .file,
                            declaration: .init(),
                            displayName: displayName(for: name, matched: match),
                            previewContent: previewContent,
                            currentSyntax: token,
                            replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                        ))
                    }
                }
            }
        case .list(let list):
            let names = list.keys
            for name in names {
                let match = name.matchCompletionInput(of: lastInput)
                if !match.isEmpty || lastInput.isEmpty {
                    var _replaceResult = token.text
                        .split(separator: "/", omittingEmptySubsequences: false)
                        .dropLast()
                    _replaceResult += [Substring(name)]
                    let replaceResult = _replaceResult.joined(separator: "/")
                    
                    var previewContent: CodeCompletionItem.PreviewContent?
                    if pathDesc._path.hasPrefix("/live2d/chara/") {
                        previewContent = .live2d(.init(string: "https://bestdori.com/assets/jp/live2d/chara/\(name)_rip/buildData.asset")!)
                    }
                    
                    result.append(.init(
                        itemType: .folder,
                        declaration: .init(),
                        displayName: displayName(for: name, matched: match),
                        previewContent: previewContent,
                        currentSyntax: token,
                        replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                    ))
                }
            }
        }
        
        return result
    } else if let assetFolder {
        // Resolve from local asset list
        
        var result: [CodeCompletionItem] = []
        
        var enclosingFolder = assetFolder
        for componment in path.components(separatedBy: "/").dropLast() {
            if !componment.isEmpty {
                if let newWrapper = enclosingFolder.fileWrappers?[componment] {
                    enclosingFolder = newWrapper
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        guard let contents = enclosingFolder.fileWrappers?.keys else {
            return []
        }
        
        for content in contents.sorted() {
            let match = content.matchCompletionInput(of: lastInput)
            if !match.isEmpty || lastInput.isEmpty {
                let wrapper = enclosingFolder.fileWrappers![content]!
                
                var _replaceResult = token.text
                    .split(separator: "/", omittingEmptySubsequences: false)
                    .dropLast()
                _replaceResult += [Substring(content)]
                var replaceResult = _replaceResult.joined(separator: "/")
                
                if wrapper.isDirectory {
                    replaceResult += "/"
                }
                
                result.append(.init(
                    itemType: .file,
                    declaration: .init(),
                    displayName: displayName(for: content, matched: match),
                    currentSyntax: token,
                    replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                ))
            }
        }
        
        return result
    } else {
        return []
    }
}
#if canImport(SwiftUI) && canImport(WebKit)
private func lookupLive2D(
    _ token: TokenSyntax,
    inside argument: StringLiteralExprSyntax,
    within funcCall: FunctionCallExprSyntax,
    in locale: _DoriAPI.Locale,
    with sema: SemaEvaluator
) -> [CodeCompletionItem] {
    guard let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self),
          let base = memberAccess.base else {
        return []
    }
    
    guard let funcDecl = sema.resolvedFuncCalls[funcCall.hashValue] else {
        return []
    }
    
    var argIndex: Int?
    for (index, arg) in funcCall.arguments.enumerated() {
        if arg.expression.as(StringLiteralExprSyntax.self) == argument {
            argIndex = index
            break
        }
    }
    guard let argIndex else { return [] }
    
    let argAttrs = funcDecl.parameters[argIndex].attributes
    var argType: String? // Either 'motion' or 'expression'
    for attr in argAttrs {
        if attr.name == "_live2dMotion" {
            argType = "motion"
            break
        } else if attr.name == "_live2dExpression" {
            argType = "expression"
            break
        }
    }
    guard let argType else { return [] }
    
    let _ir = StoryIR(locale: locale, actions: [])
    var _diags: [Diagnostic] = []
    let irEvaluator = IRGenEvaluator(_ir, semaResult: sema)
    guard let baseObject = irEvaluator._evaluateExpr(base, diags: &_diags),
          baseObject.type == "Character" else {
        return []
    }
    let live2dPath = baseObject.storages["live2dPath"]!.castTrivial().asString()
    let l2dAssetPath = "https://bestdori.com/assets/\(live2dPath)_rip/buildData.asset"
    
    @safe nonisolated(unsafe) var model: Live2DModel?
    if let m = live2dModelCacheLock
        .withLock({ unsafe cachedLive2dModelList[l2dAssetPath] }) {
        model = m
    } else {
        let semaphore = DispatchSemaphore(value: 0)
        Task { @Sendable in
            let result = await requestJSON(l2dAssetPath)
            if case let .success(json) = result {
                model = .init(json: json)
                _ = live2dModelCacheLock.withLock {
                    unsafe cachedLive2dModelList.updateValue(
                        model!,
                        forKey: l2dAssetPath
                    )
                }
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
    guard let model else { return [] }
    
    let files = argType == "motion" ? model.motions : model.expressions
    
    var result: [CodeCompletionItem] = []
    
    for file in files {
        let fileBaseName = file.fileName
            .components(separatedBy: ".")
            .dropLast()
            .joined(separator: ".")
        let match = fileBaseName.matchCompletionInput(of: token.text)
        if !match.isEmpty || token.text == "\"" {
            var replaceResult = fileBaseName
            if token.text == "\"" {
                replaceResult = "\"\(replaceResult)"
            }
            
            var previewContent: CodeCompletionItem.PreviewContent?
            if argType == "motion" {
                previewContent = .live2dMotion(
                    .init(string: l2dAssetPath)!,
                    .init(_file: file, preload: file.preload())
                )
            } else {
                previewContent = .live2dExpression(
                    .init(string: l2dAssetPath)!,
                    .init(_file: file, preload: file.preload())
                )
            }
            
            result.append(
                .init(
                    itemType: .variable,
                    declaration: .init(),
                    displayName: displayName(for: fileBaseName, matched: match),
                    previewContent: previewContent,
                    currentSyntax: token,
                    replacementSyntax: token.with(\.tokenKind, .identifier(replaceResult))
                )
            )
        }
    }
    
    return result
}
#endif // canImport(SwiftUI) && canImport(WebKit)
private func lookupKeyword(_ token: TokenSyntax) -> [CodeCompletionItem] {
    let keywords = ["let"]
    
    let text = token.text
    
    var result: [CodeCompletionItem] = []
    
    for keyword in keywords {
        let match = keyword.matchCompletionInput(of: text)
        if !match.isEmpty {
            let decl = NSMutableAttributedString(string: "keyword \(keyword)")
            #if os(macOS)
            decl.addAttribute(
                .font,
                value: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                range: .init(location: 0, length: decl.length)
            )
            decl.addAttribute(
                .foregroundColor,
                value: NSColor(named: "ZeileSyntaxHighlightKeyword", bundle: #bundle)!,
                range: .init(location: 8, length: keyword.count)
            )
            #elseif os(iOS)
            decl.addAttribute(
                .font,
                value: UIFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                range: .init(location: 0, length: decl.length)
            )
            decl.addAttribute(
                .foregroundColor,
                value: UIColor(
                    resource: .init(name: "ZeileSyntaxHighlightKeyword",
                                    bundle: #bundle)
                ),
                range: .init(location: 8, length: keyword.count)
            )
            #endif
            result.append(
                .init(
                    itemType: .keyword,
                    declaration: .init(attributedString: decl),
                    displayName: displayName(for: keyword, matched: match),
                    currentSyntax: token,
                    replacementSyntax: token.with(\.tokenKind, .identifier(keyword))
                )
            )
        }
    }
    
    return result
}

private func highlight(for syntax: some SyntaxProtocol) -> NSAttributedString {
    var string = syntax.trimmed.description.replacing("\n", with: " ")
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
    #elseif os(iOS)
    result.addAttribute(
        .foregroundColor,
        value: UIColor(
            resource: .init(name: "ZeileCompletionUnhit", bundle: #bundle)
        ),
        range: .init(location: 0, length: result.length)
    )
    result.addAttribute(
        .font,
        value: UIFont.monospacedSystemFont(ofSize: 12, weight: .medium),
        range: .init(location: 0, length: result.length)
    )
    for index in indexs {
        result.addAttribute(
            .foregroundColor,
            value: UIColor.label,
            range: .init(index...index, in: text)
        )
    }
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
    var query = query
    if query.contains("/") {
        // Consider path input
        query = String(query
            .split(separator: "/", omittingEmptySubsequences: false)
            .last!)
    }
    
    guard !query.isEmpty else { return 0 }
    
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
