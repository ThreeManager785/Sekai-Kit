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
    
    internal init(_ diag: SwiftDiagnostics.Diagnostic) {
        self._diag = diag
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
    internal var hasError: Bool {
        contains { diag in
            diag._diag.diagMessage.severity == .error
        }
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
