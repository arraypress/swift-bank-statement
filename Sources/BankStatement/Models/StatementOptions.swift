//
//  StatementOptions.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a caller knows that the statement might not say.
public struct StatementOptions: Sendable, Equatable {
    /// How to read a date like 03/04. ``DateOrder/automatic`` decides from
    /// the dates themselves and warns when they cannot decide it.
    public var dateOrder: DateOrder = .automatic
    /// Which way the balance moves. Nil decides from the statement: whichever
    /// sense makes the balances agree, and a card's vocabulary when both do.
    public var sense: BalanceSense?
    /// The year to give yearless dates when the statement prints no full date
    /// to place them against.
    public var year: Int?

    public init() {}
}
