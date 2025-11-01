//===---*- Greatdori! -*---------------------------------------------------===//
//
// DiagsList.swift
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

private let bugReportURL = "https://github.com/Greatdori/DoriKit/issues"

extension DiagnosticMessage where Self == ZeileDiagnosticMessage {
    static var unrecognizedTopLevelSyntax: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "unrecognized top level syntax",
            id: "unrecognized_top_level_syntax"
        )
    }
    
    static var unsupportedDeclaration: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "unsupported declaration",
            id: "unsupported_declaration"
        )
    }
    
    static var attributesNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "attributes syntax is not supported",
            id: "attributes_syntax_not_supported"
        )
    }
    
    static var declModifierNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "declaration modifier is not supported",
            id: "decl_modifier_not_supported"
        )
    }
    
    static var genericNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "generic syntax is not supported",
            id: "generic_syntax_not_supported"
        )
    }
    
    static var inheritanceNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "inheritance syntax is not supported",
            id: "inheritance_syntax_not_supported"
        )
    }
    
    static var whereClauseNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "where clause syntax is not supported",
            id: "where_clause_syntax_not_supported"
        )
    }
    
    static var missingMemberBlock: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "expected member declaration block",
            id: "missing_member_block"
        )
    }
    
    static var unsupportedDeclInEnum: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "this declaration is not supported in enum",
            id: "unsupported_decl_in_enum"
        )
    }
    
    static var missingIdentifierInEnumCase: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "expected identifier in enum 'case' declaration",
            id: "missing_identifier_in_enum_case"
        )
    }
    
    static var enumCaseParameterNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "parameters syntax for enum case is not supported",
            id: "enum_case_parameter_not_supported"
        )
    }
    
    static var enumRawValueNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "raw value for enum is not supported",
            id: "enum_raw_value_not_supported"
        )
    }
    
    static var unexpectedTopLevelTypeCheckPath: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            """
            this syntax should be type-checked by its parent node; \
            please submit a bug report (\(bugReportURL))
            """,
            id: "unexpected_top_level_type_check_path"
        )
    }
    
    static var functionUnexpectedBody: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "unexpected function body declaration",
            id: "function_unexpected_body"
        )
    }
    
    static var functionParamSecondNameIsUnused: some DiagnosticMessage {
        ZeileDiagnosticMessage.warning(
            "second parameter name is unused",
            id: "function_param_second_name_is_unused"
        )
    }
    
    static var functionParamUnexpectedEllipsis: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "unexpected ellipsis in function parameter declaration",
            id: "function_param_unexpected_ellipsis"
        )
    }
    
    static var functionParamUnsupportedDefaultValueDecl: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "default value declaration is not supported in function parameters",
            id: "function_param_unsupported_default_value_decl"
        )
    }
    
    static var functionThrowsNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "throwing function is not supported",
            id: "function_throws_not_supported"
        )
    }
    
    static var nestingOptionalTypeNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "nesting optional type is not supported",
            id: "nesting_optional_type_not_supported"
        )
    }
    
    static var contextOptionalTypeNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "optional type is not supported here",
            id: "context_optional_type_not_supported"
        )
    }
    
    static func invalidRedeclaration(of text: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "Invalid redeclaration of '\(text)'",
            id: "invalid_redeclaration"
        )
    }
}
