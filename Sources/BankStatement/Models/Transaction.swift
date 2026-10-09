//
//  Transaction.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One line of a statement's transaction table.
public struct Transaction: Sendable, Codable, Equatable {
    /// The day it was dated, or nil where the statement left the date column
    /// empty and no earlier row supplied one.
    public let date: StatementDate?
    /// What the statement says it was, continuation lines folded in.
    public let description: String
    /// Money in is positive, money out negative — from the account holder's
    /// side, whatever the statement's columns are called. A card purchase is
    /// negative even though it raised the balance the card company prints.
    public let amount: Decimal
    /// The running balance printed on this row, signed as printed (an
    /// overdraft is negative), or nil where the row printed none. Many banks
    /// print one only on the last row of each day.
    public let balance: Decimal?
    /// The page it was on, from 1.
    public let page: Int

    /// - Parameters:
    ///   - date: The day it was dated.
    ///   - description: What it was.
    ///   - amount: Signed from the account holder's side.
    ///   - balance: The running balance printed beside it.
    ///   - page: The page it was on.
    public init(date: StatementDate?, description: String, amount: Decimal,
                balance: Decimal?, page: Int) {
        self.date = date
        self.description = description
        self.amount = amount
        self.balance = balance
        self.page = page
    }
}
