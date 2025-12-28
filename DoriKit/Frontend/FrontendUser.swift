//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendUser.swift
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
internal import Security

extension DoriFrontend {
    public enum User {
        
    }
}

extension DoriFrontend.User {
    public typealias LoginCredential = DoriAPI.User.LoginCredential
    public typealias Token = DoriAPI.User.Token
    
    /// Manages users' credential safely.
    ///
    /// Use this class to manage users' credential.
    /// Because tokens have a expiration date,
    /// you can save users' credential here to get new tokens later
    /// without requiring them to enter credentials again.
    public final class CredentialManager: @unchecked Sendable {
        public static let shared = CredentialManager()
        
        private static let tokenTag = "com.memz233.DoriKit.Frontend.CredentialManager.Token"
        private static let usernameTag = "com.memz233.DoriKit.Frontend.CredentialManager.Username"
        private static let passwordTag = "com.memz233.DoriKit.Frontend.CredentialManager.Password"
        
        public private(set) var token: Token?
        public private(set) var username: String?
        private var password: String?
        
        private init() {
            let tokenReadQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrApplicationTag as String: Self.tokenTag,
                kSecReturnData as String: true
            ]
            var _token: AnyObject?
            if unsafe SecItemCopyMatching(tokenReadQuery as CFDictionary, &_token) == errSecSuccess,
               let data = _token as? Data,
               let tokenString = String(data: data, encoding: .utf8) {
                let expirationDate = UserDefaults.standard.double(forKey: "_DoriKit_UserTokenExpirationDate")
                if expirationDate > 0 {
                    self.token = .init(tokenString, expirationDate: .init(timeIntervalSince1970: expirationDate))
                }
            }
            
            let usernameReadQuery: [String: Any] = [
                kSecClass as String: kSecClassIdentity,
                kSecAttrApplicationTag as String: Self.usernameTag,
                kSecReturnData as String: true
            ]
            var _username: AnyObject?
            if unsafe SecItemCopyMatching(usernameReadQuery as CFDictionary, &_username) == errSecSuccess,
               let data = _username as? Data {
                self.username = String(data: data, encoding: .utf8)
            }
            
            let passwordReadQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrApplicationTag as String: Self.passwordTag,
                kSecReturnData as String: true
            ]
            var _password: AnyObject?
            if unsafe SecItemCopyMatching(usernameReadQuery as CFDictionary, &_password) == errSecSuccess,
               let data = _password as? Data {
                self.password = String(data: data, encoding: .utf8)
            }
        }
        
        public func updateCredential(_ credential: LoginCredential) {
            self.username = credential.username
            self.password = credential.password
            
            let usernameRemoveQuery: [String: Any] = [
                kSecClass as String: kSecClassIdentity,
                kSecAttrApplicationTag as String: Self.usernameTag
            ]
            SecItemDelete(usernameRemoveQuery as CFDictionary)
            let usernameWriteQuery: [String: Any] = [
                kSecClass as String: kSecClassIdentity,
                kSecAttrApplicationTag as String: Self.usernameTag,
                kSecValueData as String: credential.username.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            SecItemAdd(usernameWriteQuery as CFDictionary, nil)
            
            let passwordRemoveQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrApplicationTag as String: Self.passwordTag
            ]
            SecItemDelete(passwordRemoveQuery as CFDictionary)
            let passwordWriteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrApplicationTag as String: Self.passwordTag,
                kSecValueData as String: credential.password.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            SecItemAdd(passwordWriteQuery as CFDictionary, nil)
        }
        public func updateToken(_ token: borrowing Token) {
            self.token = copy token
            
            let tokenRemoveQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrApplicationTag as String: Self.tokenTag
            ]
            SecItemDelete(tokenRemoveQuery as CFDictionary)
            let tokenWriteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrApplicationTag as String: Self.tokenTag,
                kSecValueData as String: token._value.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            SecItemAdd(tokenWriteQuery as CFDictionary, nil)
            
            UserDefaults.standard.set(
                token.expirationDate.timeIntervalSince1970,
                forKey: "_DoriKit_UserTokenExpirationDate"
            )
        }
        
        public func renewToken(_ token: consuming Token) async -> Token {
            if let username, let password {
                (try? await DoriAPI.User.login(
                    .init(username: username, password: password)
                )) ?? copy token
            } else {
                copy token
            }
        }
    }
}

extension DoriFrontend.User {
    @TaskLocal internal static var _currentUserToken: Token?
}

/// Configures requests occuring in closure to attach a user token.
/// 
/// - Parameters:
///   - token: A token attached to all requests occuring in `body`.
///   - body: A closure with all requests attached `token`.
/// - Returns: Result of provided closure.
public func withUserToken<R>(
    _ token: DoriFrontend.User.Token?,
    _ body: () throws -> R
) rethrows -> R {
    try DoriFrontend.User.$_currentUserToken.withValue(token, operation: body)
}

/// Configures requests occuring in closure to attach a user token.
///
/// - Parameters:
///   - token: A token attached to all requests occuring in `body`.
///   - body: A closure with all requests attached `token`.
/// - Returns: Result of provided closure.
public func withUserToken<R>(
    _ token: DoriFrontend.User.Token?,
    _ body: () async throws -> R
) async rethrows -> R {
    try await DoriFrontend.User.$_currentUserToken.withValue(token, operation: body)
}
