//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendLoginCampaign.swift
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

extension DoriFrontend {
    /// Request and fetch data about login campaigns in Bandori.
    ///
    /// *Login campaigns* are activities that give you some items
    /// after login.
    ///
    /// Many login campaigns seem like belonging to one series
    /// but are associated separated ID in the list.
    /// Only the login campaigns that are continuous (that is,
    /// there're multiple rectangles for putting items) are combined in 1 ID.
    ///
    /// ![Background image of login campaign:
    /// Ganso BanG Dream Chan Premiere Commemoration](LoginCampaignExampleImage)
    public enum LoginCampaigns {
        /// List all login campaigns.
        ///
        /// - Returns: All login campaigns, nil if failed to fetch.
        public static func list() async -> [PreviewCampaign]? {
            guard let campaigns = await DoriAPI.LoginCampaigns.all() else { return nil }
            return campaigns
        }
    }
}

extension DoriFrontend.LoginCampaigns {
    public typealias PreviewCampaign = DoriAPI.LoginCampaigns.PreviewCampaign
}
