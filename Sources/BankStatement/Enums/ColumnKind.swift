//
//  ColumnKind.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a column of a transaction table holds.
enum ColumnKind: String, Sendable, Equatable {
    /// The transaction date.
    case date
    /// A second date — a card's posting date beside its transaction date.
    /// Read, and dropped.
    case otherDate
    /// What the transaction was.
    case description
    /// Money out: paid out, debits, withdrawals.
    case moneyOut
    /// Money in: paid in, credits, deposits.
    case moneyIn
    /// One signed amount for both directions.
    case amount
    /// The running balance.
    case balance
    /// Anything else the header names. Its words join the description.
    case other

    /// Whether the column holds money.
    var holdsMoney: Bool {
        switch self {
        case .moneyOut, .moneyIn, .amount, .balance: return true
        default: return false
        }
    }
}
