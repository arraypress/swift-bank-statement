//
//  Reconciliation.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The reason this library exists. Reading a table off a PDF is easy to get
//  nearly right, and nearly right is the dangerous kind of wrong: one dropped
//  row in four hundred looks exactly like a correct answer. A statement
//  carries its own proof — every running balance, and the closing balance,
//  are sums of what came before — so the parse is checked against it, and a
//  parse that does not add up is reported as one.
//

import Foundation

/// Whether the transactions read off a statement add up to the balances
/// printed on it.
public struct Reconciliation: Sendable, Codable, Equatable {

    /// The verdict.
    public enum Status: String, Sendable, Codable, Equatable {
        /// Every printed balance was checked and every one agreed.
        case reconciled
        /// A printed balance disagreed with the sum. ``Reconciliation/firstBreak`` says where.
        case broken
        /// There was nothing to check against: no running balance and no
        /// stated closing balance. Not a failure of the statement — a failure
        /// to prove the parse.
        case unverifiable
    }

    /// The verdict.
    public let status: Status
    /// How many printed balances — running, carried forward and closing —
    /// were checked against the sum.
    public let balancesChecked: Int
    /// The total of the money in.
    public let totalIn: Decimal
    /// The total of the money out, as a positive number.
    public let totalOut: Decimal
    /// The first place the sum and the statement disagreed, or nil.
    public let firstBreak: ReconciliationBreak?
    /// Why a statement is unverifiable, in a sentence.
    public let reason: String?

    /// - Parameters:
    ///   - status: The verdict.
    ///   - balancesChecked: How many printed balances were checked.
    ///   - totalIn: The money in.
    ///   - totalOut: The money out, positive.
    ///   - firstBreak: Where it first disagreed.
    ///   - reason: Why it could not be checked.
    public init(status: Status, balancesChecked: Int, totalIn: Decimal, totalOut: Decimal,
                firstBreak: ReconciliationBreak?, reason: String?) {
        self.status = status
        self.balancesChecked = balancesChecked
        self.totalIn = totalIn
        self.totalOut = totalOut
        self.firstBreak = firstBreak
        self.reason = reason
    }
}

/// Where a statement and the sum of its transactions first disagreed.
public struct ReconciliationBreak: Sendable, Codable, Equatable {

    /// Which printed balance disagreed.
    public enum Kind: String, Sendable, Codable, Equatable {
        /// A running balance beside a transaction.
        case runningBalance = "running_balance"
        /// A balance carried to, or brought from, another page.
        case carriedForward = "carried_forward"
        /// The statement's closing balance.
        case closingBalance = "closing_balance"
    }

    /// Which printed balance disagreed.
    public let kind: Kind
    /// The page it was printed on, from 1.
    public let page: Int
    /// The transaction it was printed beside, as an index into
    /// ``Statement/transactions`` — nil for a closing or carried-forward
    /// balance, which sit on a row of their own.
    public let transactionIndex: Int?
    /// The description of that transaction, or of the balance row.
    public let description: String
    /// What the statement printed.
    public let printed: Decimal
    /// What the transactions add up to at that point.
    public let calculated: Decimal

    /// - Parameters:
    ///   - kind: Which balance disagreed.
    ///   - page: The page it was on.
    ///   - transactionIndex: The transaction beside it, if any.
    ///   - description: What the row said.
    ///   - printed: The statement's figure.
    ///   - calculated: The sum's figure.
    public init(kind: Kind, page: Int, transactionIndex: Int?, description: String,
                printed: Decimal, calculated: Decimal) {
        self.kind = kind
        self.page = page
        self.transactionIndex = transactionIndex
        self.description = description
        self.printed = printed
        self.calculated = calculated
    }
}
