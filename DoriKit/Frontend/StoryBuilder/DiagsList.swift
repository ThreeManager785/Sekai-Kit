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
    
    static var nestingStructNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "nesting struct declaration is not supported",
            id: "nesting_struct_not_supported"
        )
    }
    
    static var nestingEnumNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "nesting enum declaration is not supported",
            id: "nesting_enum_not_supported"
        )
    }
    
    static var varBindingUnexpectedID: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "expected identifier",
            id: "variable_binding_unexpected_identifier"
        )
    }
    
    static var varAccessorNotSupported: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "variable accessor syntax is not supported",
            id: "variable_accessor_not_supported"
        )
    }
    
    static var failedToFoldOperators: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            """
            failed to resolve operators; \
            please submit a bug report (\(bugReportURL))
            """,
            id: "failed_to_fold_operators"
        )
    }
    
    static var cannotInferTypeWithoutAnnotation: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "type could not be inferred without a type annotation",
            id: "cannot_infer_type_without_type_annotation"
        )
    }
    
    static var invalidStaticVarDeclPosition: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "static properties may only be declared on a type",
            id: "invalid_static_variable_declaration_position"
        )
    }
    
    static var awaitCallUnsupportedFunc: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "'await' in a function that does not support concurrency",
            id: "await_call_unsupported_function"
        )
    }
    
    static var circularRefInExpr: some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "circular reference in expression",
            id: "circulat_reference_in_expression"
        )
    }
    
    static func invalidRedeclaration(of text: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "Invalid redeclaration of '\(text)'",
            id: "invalid_redeclaration"
        )
    }
    
    static func unsupportedVarSpec(_ spec: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "variable specifier '\(spec)' is not supported",
            id: "unsupported_variable_specifier"
        )
    }
    
    static func missingStdlibType(_ typeName: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            """
            standard library type '\(typeName)' is missing or broken; \
            please submit a bug report (\(bugReportURL))
            """,
            id: "missing_stdlib_type"
        )
    }
    
    static func unsupportedOperator(_ operator: String?) -> some DiagnosticMessage {
        if let `operator` {
            ZeileDiagnosticMessage.error(
                "operator '\(`operator`)' is not supported",
                id: "unsupported_operator"
            )
        } else {
            ZeileDiagnosticMessage.error(
                "this operator is not supported",
                id: "unsupported_operator"
            )
        }
    }
    
    static func specTypeNotMatchToInit(specType: String, initType: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "cannot convert value of type '\(initType)' to specified type '\(specType)'",
            id: "specified_type_not_match_to_initializer"
        )
    }
    
    static func cannotFindTypeInScope(_ typeName: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "cannot find type '\(typeName)' in scope",
            id: "cannot_find_type_in_scope"
        )
    }
    
    static func cannotFindRefInScope(_ refName: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "cannot find '\(refName)' in scope",
            id: "cannot_find_reference_in_scope"
        )
    }
    
    static func typeValueHasNoMember(type: String, member: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "value of type '\(type)' has no member '\(member)'",
            id: "type_value_has_no_member"
        )
    }
    
    static func cannotCallNonFuncValue(ofType type: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "Cannot call value of non-function type '\(type)'",
            id: "cannot_call_non-function_value"
        )
    }
    
    static func callExtraArgLabel(_ label: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "extraneous argument label '\(label):' in call",
            id: "call_extra_argument_label"
        )
    }
    
    static func callMissingArgLabel(_ label: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "missing argument label '\(label):' in call",
            id: "call_missing_argument_label"
        )
    }
    
    static func callIncorrectArgLabel(have: String, expected: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "incorrect argument label in call (have '\(have):', expected '\(expected):')",
            id: "call_incorrect_argument_label"
        )
    }
    
    static func callArgTypeNotMatchToDecl(callType: String, declType: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "cannot convert value of type '\(callType)' to expected argument type '\(declType)'",
            id: "call_argument_type_not_match_to_declaration"
        )
    }
    
    static func callAmbiguousMemberOverload(_ name: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "ambiguous reference to member \(name)",
            id: "call_ambiguous_member_overload"
        )
    }
    
    static func callNoExactMatchToFunc(_ funcName: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "no exact matches in call to function '\(funcName)'",
            id: "call_no_exact_match_to_function"
        )
    }
    
    static func duplicateDeclModifier(of modifier: String) -> some DiagnosticMessage {
        ZeileDiagnosticMessage.error(
            "'\(modifier)' cannot appear after another '\(modifier)' keyword",
            id: "duplicate_declaration_modifier"
        )
    }
}
