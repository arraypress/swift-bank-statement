//
//  Statement.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A statement, read: its transactions, its balances, and whether they agree.
public struct Statement: Sendable, Codable, Equatable {
    /// The file it was read from, when it was read from one.
    public let source: URL?
    /// How many pages the document has.
    public let pageCount: Int
    /// Every transaction, in the order the statement lists them.
    public let transactions: [Transaction]
    /// The balance the statement opened with.
    public let openingBalance: Decimal?
    /// Whether the opening balance was printed or worked back from the first
    /// running balance.
    public let openingSource: BalanceSource?
    /// The balance the statement closed with.
    public let closingBalance: Decimal?
    /// Whether the closing balance was printed or taken from the last
    /// running balance.
    public let closingSource: BalanceSource?
    /// The latest full date the statement prints — normally the end of its
    /// period — which yearless dates are placed against.
    public let periodEnd: StatementDate?
    /// Which way the printed balance moves: an account's rises with money in,
    /// a card's with money spent.
    public let sense: BalanceSense
    /// How numeric dates were read.
    public let dateOrder: DateOrder
    /// Whether the transactions add up to the printed balances.
    public let reconciliation: Reconciliation
    /// Things a caller should know that did not stop the read — an assumed
    /// date order, a year that could not be found.
    public let warnings: [String]

    /// - Parameters:
    ///   - source: The file it came from.
    ///   - pageCount: How many pages.
    ///   - transactions: The transactions, in order.
    ///   - openingBalance: The opening balance.
    ///   - openingSource: Where the opening balance came from.
    ///   - closingBalance: The closing balance.
    ///   - closingSource: Where the closing balance came from.
    ///   - periodEnd: The latest full date printed.
    ///   - sense: Which way the balance moves.
    ///   - dateOrder: How numeric dates were read.
    ///   - reconciliation: Whether it adds up.
    ///   - warnings: What a caller should know.
    public init(source: URL?, pageCount: Int, transactions: [Transaction],
                openingBalance: Decimal?, openingSource: BalanceSource?,
                closingBalance: Decimal?, closingSource: BalanceSource?,
                periodEnd: StatementDate?, sense: BalanceSense, dateOrder: DateOrder,
                reconciliation: Reconciliation, warnings: [String]) {
        self.source = source
        self.pageCount = pageCount
        self.transactions = transactions
        self.openingBalance = openingBalance
        self.openingSource = openingSource
        self.closingBalance = closingBalance
        self.closingSource = closingSource
        self.periodEnd = periodEnd
        self.sense = sense
        self.dateOrder = dateOrder
        self.reconciliation = reconciliation
        self.warnings = warnings
    }
}
