//===---*- Greatdori! -*---------------------------------------------------===//
//
// Diagnostic.swift
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
internal import SwiftDiagnostics

public struct Diagnostic: Sendable {
    internal let _diag: SwiftDiagnostics.Diagnostic
    internal var _lazySourceLocation: __Reference<SourceLocation?>
    
    internal init(_ diag: SwiftDiagnostics.Diagnostic) {
        self._diag = diag
        self._lazySourceLocation = .init(nil)
    }
    
    public var line: Int {
        ensureLazySourceLocation()
        return _lazySourceLocation.value!.line
    }
    public var column: Int {
        ensureLazySourceLocation()
        return _lazySourceLocation.value!.column
    }
    
    public var message: String {
        _diag.message
    }
    
    public var severity: Severity {
        .init(_diag.diagMessage.severity)
    }
    
    private func ensureLazySourceLocation() {
        if _lazySourceLocation.value != nil {
            return
        }
        
        let converter = SourceLocationConverter(fileName: "", tree: _diag.node.root)
        _lazySourceLocation.value = converter.location(for: _diag.position)
    }
    
    public enum Severity: Sendable {
        case error
        case warning
        case note
        case remark
        
        internal init(_ severity: DiagnosticSeverity) {
            self = switch severity {
            case .error: .error
            case .warning: .warning
            case .note: .note
            case .remark: .remark
            }
        }
    }
}
extension Diagnostic {
    internal init(
        node: some SyntaxProtocol,
        position: AbsolutePosition? = nil,
        message: DiagnosticMessage,
        highlights: [Syntax]? = nil,
        notes: [Note] = [],
        fixIts: [FixIt] = []
    ) {
        self.init(
            .init(
                node: node,
                position: position,
                message: message,
                highlights: highlights,
                notes: notes,
                fixIts: fixIts
            )
        )
    }
}

extension Array<Diagnostic> {
    public var hasError: Bool {
        contains { diag in
            diag._diag.diagMessage.severity == .error
        }
    }
}

extension Diagnostic: CustomStringConvertible {
    public var description: String {
        _diag.debugDescription + "\n"
        + DiagnosticsFormatter.annotatedSource(tree: syntaxRoot(of: _diag.node), diags: [_diag])
    }
}
private func syntaxRoot(of node: some SyntaxProtocol) -> Syntax {
    if let parent = node.parent {
        return syntaxRoot(of: parent)
    } else {
        return Syntax(node)
    }
}

internal struct ZeileDiagnosticMessage: DiagnosticMessage {
    internal var diagnosticID: SwiftDiagnostics.MessageID
    internal var severity: SwiftDiagnostics.DiagnosticSeverity
    internal var message: String
    
    internal static func error(_ message: LocalizedStringResource, id: String) -> Self {
        .init(
            diagnosticID: .init(
                domain: "DoriKit_Zeile",
                id: id
            ),
            severity: .error,
            message: String(localized: message)
        )
    }
    
    internal static func warning(_ message: LocalizedStringResource, id: String) -> Self {
        .init(
            diagnosticID: .init(
                domain: "DoriKit_Zeile",
                id: id
            ),
            severity: .warning,
            message: String(localized: message)
        )
    }
    
    internal static func note(_ message: LocalizedStringResource, id: String) -> Self {
        .init(
            diagnosticID: .init(
                domain: "DoriKit_Zeile",
                id: id
            ),
            severity: .note,
            message: String(localized: message)
        )
    }
    
    internal static func remark(_ message: LocalizedStringResource, id: String) -> Self {
        .init(
            diagnosticID: .init(
                domain: "DoriKit_Zeile",
                id: id
            ),
            severity: .remark,
            message: String(localized: message)
        )
    }
}
