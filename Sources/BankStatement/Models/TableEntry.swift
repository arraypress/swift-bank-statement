//
//  TableEntry.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A transaction table read row by row, before any arithmetic: the parser
//  says what each row IS, and the reconciler, which knows nothing about
//  layout, decides whether the figures agree.
//

import Foundation

/// A money figure as printed: its size, and what the statement said about
/// its direction.
struct PrintedAmount: Sendable, Equatable {
    /// The figure, negative when printed with a minus or in brackets.
    let value: Decimal
    /// A CR or DR the statement printed beside it.
    let marker: Marker?

    /// A direction printed beside a figure.
    enum Marker: String, Sendable, Equatable {
        case credit = "CR"
        case debit = "DR"
    }
}

/// One transaction as the table printed it.
struct RawTransaction: Sendable, Equatable {
    /// The text of the date cell, if the row had one.
    var dateText: String?
    /// The description, continuation lines folded in.
    var description: String
    /// The money-out cell.
    var moneyOut: PrintedAmount?
    /// The money-in cell.
    var moneyIn: PrintedAmount?
    /// The signed-amount cell.
    var amount: PrintedAmount?
    /// The running balance cell.
    var balance: PrintedAmount?
    /// The page, from 1.
    let page: Int
}

/// A row that prints a balance and is not a transaction.
struct BalanceMarker: Sendable, Equatable {

    /// What the balance row says it is.
    enum Kind: Sendable, Equatable {
        /// Opening balance, or balance brought forward.
        case opening
        /// Closing balance, or balance carried forward.
        case closing
        /// A balance with no label that says which.
        case running
    }

    let kind: Kind
    let balance: PrintedAmount
    let page: Int
    let text: String
}

/// A row of a transaction table, classified.
enum TableEntry: Sendable, Equatable {
    case transaction(RawTransaction)
    case marker(BalanceMarker)
}
