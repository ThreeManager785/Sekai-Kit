//===---*- Greatdori! -*---------------------------------------------------===//
//
// NetworkConfig.swift
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

internal let AF = {
    let info = Bundle.main.infoDictionary
    let executable = (info?["CFBundleExecutable"] as? String) ??
    (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
    "Unknown"
    let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
    
    let cfNetworkVersion = Bundle(identifier: "com.apple.CFNetwork")?
        .infoDictionary?[kCFBundleVersionKey as String] as? String ?? "Unknown"
    
    var _utsname = utsname()
    unsafe uname(&_utsname)
    let darwinVersion = unsafe withUnsafePointer(to: &_utsname.release) { ptr in
        unsafe ptr.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { pointer in
            unsafe String(cString: pointer)
        }
    }
    
    let userAgent = """
    \(executable)/\(appVersion) \
    DoriKit/1.0.0 \
    CFNetwork/\(cfNetworkVersion) \
    Darwin/\(darwinVersion)
    """
    
    var defaultRequestHeaders: HTTPHeaders = .default
    defaultRequestHeaders.update(.userAgent(userAgent))
    
    let configuration = URLSessionConfiguration.af.default
    configuration.headers = defaultRequestHeaders
    let session = Session(configuration: configuration)
    return session
}()
