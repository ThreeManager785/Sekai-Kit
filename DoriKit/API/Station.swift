//===---*- Greatdori! -*---------------------------------------------------===//
//
// Station.swift
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
internal import Alamofire
internal import SwiftyJSON

extension _DoriAPI {
    public enum Station {
        @inlinable
        public static func register(
            username: String,
            password: String,
            email: String
        ) async throws(APIError) -> UnverifiedUserToken {
            try await register(with: .init(
                username: username,
                password: password,
                email: email
            ))
        }
        public static func register(with form: RegisterForm) async throws(APIError) -> UnverifiedUserToken {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    AF.request(
                        "https://server.bandoristation.com",
                        method: .post,
                        parameters: [
                            "function_group": "UserLogin",
                            "function": "signup",
                            "username": form.username,
                            "password": form.password,
                            "email": form.email
                        ],
                        encoding: JSONEncoding.default
                    ).response { response in
                        if let _data = response.data,
                           let json = try? JSON(data: consume _data) {
                            if let token = json["response"]["token"].string {
                                continuation.resume(returning: .init(_value: token))
                            } else {
                                continuation.resume(throwing: APIError(
                                    rawValue: json["response"].stringValue
                                ) ?? .unknown)
                            }
                        } else {
                            continuation.resume(throwing: APIError.unknown)
                        }
                    }
                }
            } catch {
                throw error as! APIError
            }
        }
        
        @inlinable
        public static func login(
            username: String,
            password: String
        ) async throws(APIError) -> LoginResponse {
            try await login(with: .init(username: username, password: password))
        }
        public static func login(with credential: Credential) async throws(APIError) -> LoginResponse {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    AF.request(
                        "https://server.bandoristation.com",
                        method: .post,
                        parameters: [
                            "function_group": "UserLogin",
                            "function": "login",
                            "username": credential.username,
                            "password": credential.password
                        ],
                        encoding: JSONEncoding.default
                    ).response { response in
                        if let _data = response.data,
                           let json = try? JSON(data: consume _data) {
                            if json["response"]["redirect_to"].string != nil {
                                continuation.resume(
                                    returning: .emailVerificationRequired(
                                        token: .init(_value: json["response"]["token"].stringValue)
                                    )
                                )
                            } else if let token = json["response"]["token"].string {
                                continuation.resume(returning: .success(
                                    token: .init(_value: token),
                                    userInfo: .init(
                                        id: json["response"]["user_id"].intValue,
                                        _avatarFileName: json["response"]["avatar"].stringValue,
                                        role: json["response"]["role"].intValue,
                                        banStatus: json["response"]["ban_status"]["is_banned"].boolValue
                                                   ? .banned(interval: json["response"]["ban_status"]["interval"].doubleValue)
                                                   : .normal,
                                        websiteSettings: .init(
                                            backgroundDynamicEffectEnabled: json["response"]["website_setting"]["background"]["dynamic_effect"].boolValue,
                                            postPreference: .init(
                                                roomType: .init(rawValue: Int(json["response"]["website_setting"]["send_room_number"]["type"].stringValue) ?? 0) ?? .daredemo,
                                                preselectedWordList: json["response"]["website_setting"]["send_room_number"]["preselection_word_list"].map {
                                                    $0.1.stringValue
                                                }
                                            )
                                        ),
                                        followedUsers: json["response"]["following_user"].map {
                                            .init(
                                                id: $0.1["user_id"].intValue,
                                                followingDate: .init(timeIntervalSince1970: $0.1["time"].doubleValue)
                                            )
                                        }
                                    )
                                ))
                            } else {
                                continuation.resume(throwing: APIError(
                                    rawValue: json["response"].stringValue
                                ) ?? .unknown)
                            }
                        } else {
                            continuation.resume(throwing: APIError.unknown)
                        }
                    }
                }
            } catch {
                throw error as! APIError
            }
        }
        
        public static func currentEmail(
            fromUserToken token: UnverifiedUserToken
        ) async throws(APIError) -> String {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    AF.request(
                        "https://server.bandoristation.com",
                        method: .post,
                        parameters: [
                            "function_group": "UserLogin",
                            "function": "getCurrentEmail"
                        ],
                        encoding: JSONEncoding.default,
                        headers: defaultRequestHeaders.with(name: "Auth-Token", value: token._value)
                    ).response { response in
                        if let _data = response.data,
                           let json = try? JSON(data: consume _data) {
                            if let email = json["response"]["email"].string {
                                continuation.resume(returning: email)
                            } else {
                                continuation.resume(throwing: APIError(
                                    rawValue: json["response"].stringValue
                                ) ?? .unknown)
                            }
                        } else {
                            continuation.resume(throwing: APIError.unknown)
                        }
                    }
                }
            } catch {
                throw error as! APIError
            }
        }
        
        public static func sendVerificationCode(
            forUserToken token: UnverifiedUserToken
        ) async throws(APIError) {
            do {
                try await withCheckedThrowingContinuation { continuation in
                    AF.request(
                        "https://server.bandoristation.com",
                        method: .post,
                        parameters: [
                            "function_group": "UserLogin",
                            "function": "sendEmailVerificationCode"
                        ],
                        encoding: JSONEncoding.default,
                        headers: defaultRequestHeaders.with(name: "Auth-Token", value: token._value)
                    ).response { response in
                        if let _data = response.data,
                           let json = try? JSON(data: consume _data) {
                            if json["status"].stringValue == "success" {
                                continuation.resume(returning: ())
                            } else {
                                continuation.resume(throwing: APIError(
                                    rawValue: json["response"].stringValue
                                ) ?? .unknown)
                            }
                        } else {
                            continuation.resume(throwing: APIError.unknown)
                        }
                    }
                }
            } catch {
                throw error as! APIError
            }
        }
        
        public static func verifyEmail(
            forUserToken token: UnverifiedUserToken,
            withCode code: String
        ) async throws(APIError) -> UserToken {
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    AF.request(
                        "https://server.bandoristation.com",
                        method: .post,
                        parameters: [
                            "function_group": "UserLogin",
                            "function": "verifyEmail",
                            "verification_code": code
                        ],
                        encoding: JSONEncoding.default,
                        headers: defaultRequestHeaders.with(name: "Auth-Token", value: token._value)
                    ).response { response in
                        if let _data = response.data,
                           let json = try? JSON(data: consume _data) {
                            if let token = json["response"]["token"].string {
                                continuation.resume(returning: .init(_value: token))
                            } else {
                                continuation.resume(throwing: APIError(
                                    rawValue: json["response"].stringValue
                                ) ?? .unknown)
                            }
                        } else {
                            continuation.resume(throwing: APIError.unknown)
                        }
                    }
                }
            } catch {
                throw error as! APIError
            }
        }
        
        /// Keep a connection to receive new rooms.
        ///
        /// - Parameters:
        ///   - client: A string to identify the client.
        ///   - userToken: A valid user token for access group settings.
        ///   - pushRooms: A closure to be called when any new rooms available.
        ///
        /// This function creates a connection to receive room updates.
        /// When the connection becomes active, it calls `pushRooms`
        /// for the initial room list, this can be an empty array
        /// if no rooms are available.
        ///
        /// You can disconnect by cancelling the task with this function.
        ///
        /// This function returns when the task is cancelled,
        /// or throws an error if any error occured.
        /// In both cases, the connection is disconnected
        /// and you can create a new task with this function to start over.
        ///
        /// ```swift
        /// let task = Task {
        ///     do {
        ///         try await _DoriAPI.Station.receiveRooms { newRooms in
        ///             roomArray.append(contentsOf: newRooms)
        ///         }
        ///         print("Finished!")
        ///     } catch {
        ///         handleError(error)
        ///     }
        /// }
        ///
        /// while true {
        ///     if shouldStopReceiving {
        ///         task.cancel()
        ///         break
        ///     }
        ///     sleep(10)
        /// }
        /// ```
        ///
        /// - IMPORTANT:
        ///     It's important to keep a reference to the task
        ///     for this function. If you lose all references to the task,
        ///     the connection is kept forever until any errors occurs
        ///     or your app is terminated.
        public static func receiveRooms(
            client: String = "DoriKit",
            userToken: UserToken? = nil,
            pushingNewRooms pushRooms: sending ([Room]) -> Void
        ) async throws {
            final class Coordinator: NSObject, URLSessionWebSocketDelegate {
                private let passOpened: @Sendable (
                    URLSession,
                    URLSessionWebSocketTask,
                    String?
                ) -> Void
                private let passClosed: @Sendable (
                    URLSession,
                    URLSessionWebSocketTask,
                    URLSessionWebSocketTask.CloseCode,
                    Data?
                ) -> Void
                
                init(
                    onOpen: @Sendable @escaping (
                        _ session: URLSession,
                        _ webSocketTask: URLSessionWebSocketTask,
                        _ protocol: String?
                    ) -> Void,
                    onClose: @Sendable @escaping (
                        _ session: URLSession,
                        _ webSocketTask: URLSessionWebSocketTask,
                        _ closeCode: URLSessionWebSocketTask.CloseCode,
                        _ reason: Data?
                    ) -> Void
                ) {
                    self.passOpened = onOpen
                    self.passClosed = onClose
                }
                
                func urlSession(
                    _ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?
                ) {
                    passOpened(session, webSocketTask, `protocol`)
                }
                func urlSession(
                    _ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?
                ) {
                    passClosed(session, webSocketTask, closeCode, reason)
                }
            }
            
            enum RunloopWakeReason {
                case receiveMessage(URLSessionWebSocketTask.Message)
                case heartBeatTimeout
            }
            
            // Locking local variables
            let isConnected = Locking(false)
            let runLoopContinuation: Locking<CheckedContinuation<RunloopWakeReason, any Error>?> = .init(nil)
            runLoopContinuation._lock() // unlock when continuation ready
            
            let coordinator = Coordinator(onOpen: { session, webSocketTask, `protocol` in
                isConnected.withLock {
                    $0 = true
                }
            }, onClose: { session, webSocketTask, closeCode, reason in
                isConnected.withLock {
                    $0 = false
                }
            })
            
            let configuration = URLSessionConfiguration.default
            configuration.headers = defaultRequestHeaders
            let session = URLSession(
                configuration: configuration,
                delegate: coordinator,
                delegateQueue: nil
            )
            
            let task = session.webSocketTask(with: URL(string: "wss://api.bandoristation.com")!)
            task.resume()
            defer { task.cancel(with: .goingAway, reason: nil) }
            
            let receiveLoopTask = Task {
                repeat {
                    if Task.isCancelled {
                        return
                    }
                    
                    do {
                        let message = try await task.receive()
                        runLoopContinuation.withLock {
                            $0?.resume(returning: .receiveMessage(message))
                        }
                    } catch {
                        runLoopContinuation.withLock {
                            $0?.resume(throwing: error)
                        }
                    }
                } while true
            }
            defer {
                receiveLoopTask.cancel()
            }
            
            let heartBeatTask = Task {
                do {
                    repeat {
                        if Task.isCancelled {
                            return
                        }
                        
                        try await Task.sleep(for: .seconds(30))
                        
                        runLoopContinuation.withLock {
                            $0?.resume(returning: .heartBeatTimeout)
                        }
                    } while true
                } catch {}
            }
            defer {
                heartBeatTask.cancel()
            }
            
            do {
                repeat {
                    if Task.isCancelled {
                        return
                    }
                    
                    let reason = try await withCheckedThrowingContinuation { continuation in
                        runLoopContinuation._value.value = continuation
                        runLoopContinuation._unlock()
                    }
                    runLoopContinuation._lock()
                    switch reason {
                    case .receiveMessage(let message):
                        switch message {
                        case .string(let string):
                            let json = JSON(parseJSON: string)
                            if json["action"].stringValue == "sendServerTime" {
                                // Send initial messages
                                var initialActions: [Any] = []
                                initialActions.append([
                                    "action": "setClient",
                                    "data": [
                                        "client": client,
                                        "send_room_number": true
                                    ]
                                ])
                                initialActions.append([
                                    "action": "getRoomNumberList",
                                    "data": nil
                                ])
                                if let userToken {
                                    initialActions.append([
                                        "action": "setAccessPermission",
                                        "data": [
                                            "token": userToken._value
                                        ]
                                    ])
                                }
                                if ((try? await task.send(.data(JSONSerialization.data(withJSONObject: initialActions)))) == nil) {
                                    throw RoomUpdateError.failedToInitializeConnection
                                }
                            } else if json["action"].stringValue == "sendRoomNumberList" {
                                var newRooms: [Room] = []
                                for (_, roomJSON) in json["response"] {
                                    newRooms.append(.init(parsing: roomJSON))
                                }
                                pushRooms(newRooms)
                            }
                        default: break
                        }
                    case .heartBeatTimeout:
                        let heartBeatAction: [String: Any] = [
                            "action": "heartbeat",
                            "data": [
                                "client": client
                            ]
                        ]
                        task.send(.data(try JSONSerialization.data(withJSONObject: heartBeatAction))) {
                            if let error = $0 {
                                runLoopContinuation.withLock {
                                    $0?.resume(throwing: error)
                                }
                            }
                        }
                    }
                } while true
            } catch {
                runLoopContinuation._value.value = nil
                throw error
            }
        }
    }
}

extension _DoriAPI.Station {
    public enum APIError: String, Sendable, Error, Hashable {
        // TBH the error handling in the Station API is tremendously distressing.
        // It always returns status 200 and describe errors as plain texts
        
        case operationNotAllowed = "Not allowed"
        case forbidden = "No permission"
        case badRequest = "Unparsable format"
        case missingParameters = "Missing Parameters"
        case missingFunctionParameter = "Missing Parameter \"function\""
        case undefinedFunctionGroup = "Undefined function group"
        case undefinedFunction = "Undefined function"
        case methodNotAllowed = "Forbidden method"
        case undefinedAccessToken = "Undefined access token"
        case invalidToken = "Token validation failure"
        case userNotFound = "Nonexistent user"
        case emailNotFound = "Undefined email"
        case emailNotAvailable = "Duplicate email"
        case invalidEmail = "Invalid email"
        case emailVerified = "Verified email"
        case undefinedVerificationCode = "Undefined verification code"
        case invalidVerificationCode = "Invalid verification code"
        case tooManyLogins = "Too many logins"
        case wrongPassword = "Wrong password"
        case tooManySignups = "Too many signups"
        case usernameOrEmailNotAvailable = "Username or email already exists"
        case usernameNotAvailable = "Username already exists"
        case qqNumberNotAvailable = "QQ already exists"
        case badVerificationRequest = "Undefined verification request"
        case tooManySubmits = "Duplicate number submit" // The Swift name is right
        case failedToVerifyPlayer = "Player verification failure"
        case failedToGetPlayerData = "No player data"
        case tooManyRequests = "Requests are too frequent"
        case unknown = "API request failure" // We use this as a fallback
    }
    
    public struct Credential: Sendable, Hashable {
        public var username: String
        public var password: String
        
        public init(username: String, password: String) {
            self.username = username
            self.password = password
        }
    }
    
    public struct RegisterForm: Sendable, Hashable {
        public var username: String
        public var password: String
        public var email: String
        
        public init(username: String, password: String, email: String) {
            self.username = username
            self.password = password
            self.email = email
        }
    }
    
    public struct UserToken: Sendable, Hashable, Codable {
        internal var _value: String
    }
    public struct UnverifiedUserToken: Sendable, Hashable, Codable {
        internal var _value: String
    }
    
    public enum LoginResponse: Sendable {
        case emailVerificationRequired(token: UnverifiedUserToken)
        case success(token: UserToken, userInfo: SelfInformation)
    }
    
    public struct SelfInformation: Sendable, Identifiable, Hashable {
        public var id: Int
        public var _avatarFileName: String
        public var role: Int
        public var banStatus: BanStatus
        public var websiteSettings: WebsiteSettings
        public var followedUsers: [FollowedUser]
        
        public var avatarURL: URL? {
            _avatarFileName.isEmpty ? nil : .init(string: "https://asset.bandoristation.com/images/user-avatar/\(_avatarFileName)")
        }
        
        public enum BanStatus: Sendable, Hashable {
            case normal
            case banned(interval: TimeInterval)
        }
        
        public struct WebsiteSettings: Sendable, Hashable {
            public var backgroundDynamicEffectEnabled: Bool
            public var postPreference: PostPreference
            
            public struct PostPreference: Sendable, Hashable {
                public var roomType: RoomType
                public var preselectedWordList: [String]
            }
        }
        
        public struct FollowedUser: Sendable, Identifiable, Hashable {
            public var id: Int
            public var followingDate: Date
        }
    }
    
    public struct UserInformation: Sendable, Identifiable, Hashable {
        public var id: Int
        public var type: String
        public var username: String
        public var _avatarFileName: String
        public var gameProfile: GameProfile?
        
        public var avatarURL: URL? {
            _avatarFileName.isEmpty ? nil : .init(string: "https://asset.bandoristation.com/images/user-avatar/\(_avatarFileName)")
        }
        
        public struct GameProfile: Sendable, Identifiable, Hashable {
            public var id: Int
            public var degreeIDs: [Int]
            public var dateUpdated: Date
            public var server: _DoriAPI.Locale
            public var bandPower: Int
            public var mainDeck: [Situation]
            
            public struct Situation: Sendable, Hashable {
                public var id: Int
                public var trained: Bool
                public var illust: String
            }
        }
    }
    
    public enum RoomType: Int, Sendable, Hashable {
        case daredemo = 0
        case standard = 7
        case master = 12
        case grand = 18
        case legend = 25
    }
    
    public struct Room: Sendable, Hashable {
        internal let _rawJSON: String
        
        public var type: RoomType
        public var source: Source
        public var creator: UserInformation
        public var dateCreated: Date
        public var message: String
        public var number: String
        
        public enum Source: Sendable, Hashable {
            case qq(String)
            case website(String)
            case unknown
        }
    }
    
    public enum RoomUpdateError: Sendable, Error {
        case failedToInitializeConnection
        case receivedError(any Error)
    }
}
extension _DoriAPI.Station.Room {
    internal init(parsing json: JSON) {
        self.init(
            _rawJSON: json.rawString()!,
            type: .init(rawValue: Int(json["type"].stringValue) ?? 0) ?? .daredemo,
            source: .init(parsing: json["source_info"]),
            creator: .init(
                id: json["user_info"]["user_id"].intValue,
                type: json["user_info"]["type"].stringValue,
                username: json["user_info"]["username"].stringValue,
                _avatarFileName: json["user_info"]["avatar"].stringValue,
                gameProfile: json["user_info"]["bandori_player_brief_info"]["latest_update_time"].double != nil
                ? .init(
                    id: json["user_info"]["bandori_player_brief_info"]["user_id"].intValue,
                    degreeIDs: json["user_info"]["bandori_player_brief_info"]["degrees"].map { $0.1.intValue },
                    dateUpdated: .init(timeIntervalSince1970: json["user_info"]["bandori_player_brief_info"]["latest_update_time"].doubleValue),
                    server: .init(rawValue: json["user_info"]["bandori_player_brief_info"]["server"].stringValue) ?? .jp,
                    bandPower: json["user_info"]["bandori_player_brief_info"]["band_power"].intValue,
                    mainDeck: json["user_info"]["bandori_player_brief_info"]["main_deck"].map {
                        .init(
                            id: $0.1["situationId"].intValue,
                            trained: $0.1["trainingStatus"].stringValue == "done",
                            illust: $0.1["illust"].stringValue
                        )
                    }
                ) : nil
            ),
            dateCreated: .init(timeIntervalSince1970: json["time"].doubleValue / 1000),
            message: json["raw_message"].stringValue,
            number: json["number"].stringValue
        )
    }
}
extension _DoriAPI.Station.Room.Source {
    internal init(parsing json: JSON) {
        if json["type"].stringValue == "qq" {
            self = .qq(json["name"].stringValue)
        } else if json["type"].stringValue == "website" {
            self = .website(json["name"].stringValue)
        } else {
            self = .unknown
        }
    }
}
