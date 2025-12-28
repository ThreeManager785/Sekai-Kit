//===---*- Greatdori! -*---------------------------------------------------===//
//
// FrontendMiracleTicket.swift
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
    /// Request and fetch data about miracle tickets in Bandori.
    ///
    /// *Miracle Tickets* can be used to exchange one card of your choice in GBP.
    ///
    /// You can only get all miracle tickets in one request,
    /// to find a miracle ticket with a specific ID, use `Array.first(where:)`
    /// to find the miracle ticket by ID.
    ///
    /// ![A miracle ticket](MiracleTicketExampleImage)
    public enum MiracleTickets {
        /// List all miracle tickets with related information.
        ///
        /// - Returns: All miracle tickets with related cards.
        public static func extendedList() async -> [ExtendedMiracleTicket]? {
            let groupResult = await withTasksResult {
                await DoriAPI.MiracleTickets.all()
            } _: {
                await DoriAPI.Cards.all()
            }
            guard let tickets = groupResult.0 else { return nil }
            guard let cards = groupResult.1 else { return nil }
            
            return tickets.map {
                .init(
                    ticket: $0,
                    cards: $0.ids.map { ids in
                        if let ids {
                            cards.filter { ids.contains($0.id) }
                        } else {
                            nil
                        }
                    }
                )
            }
        }
    }
}

extension DoriFrontend.MiracleTickets {
    public struct ExtendedMiracleTicket: Sendable, Identifiable, Hashable, DoriCache.Cacheable {
        public var ticket: DoriAPI.MiracleTickets.MiracleTicket
        public var cards: DoriAPI.LocalizedData<[DoriAPI.Cards.PreviewCard]>
        
        public var id: Int {
            ticket.id
        }
    }
}
