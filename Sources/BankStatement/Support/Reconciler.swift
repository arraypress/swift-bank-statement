//
//  Reconciler.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The arithmetic, and nothing but. Given what the table said in order, walk
//  it with a running total and compare that total with every balance the
//  statement printed. Exact `Decimal` equality — there is no tolerance,
//  because a statement's figures are exact and a tolerance is a place for a
//  missing penny to hide.
//
//  Where the statement prints no opening balance, the first running balance
//  becomes the baseline. That balance is NOT counted as checked: an opening
//  worked back from a row agrees with that row by construction, and counting
//  it would let a one-balance statement call itself proven.
//

import Foundation

/// Checks a statement's transactions against its printed balances.
enum Reconciler {

    /// What reconciling produced.
    struct Outcome: Sendable, Equatable {
        /// The verdict.
        var reconciliation: Reconciliation
        /// Each transaction's amount from the holder's side, in table order.
        var amounts: [Decimal]
        /// Each transaction's printed balance, signed, in table order.
        var balances: [Decimal?]
        /// The opening balance and where it came from.
        var opening: (Decimal, BalanceSource)?
        /// The closing balance and where it came from.
        var closing: (Decimal, BalanceSource)?

        static func == (lhs: Outcome, rhs: Outcome) -> Bool {
            lhs.reconciliation == rhs.reconciliation && lhs.amounts == rhs.amounts
                && lhs.balances == rhs.balances
                && lhs.opening?.0 == rhs.opening?.0 && lhs.opening?.1 == rhs.opening?.1
                && lhs.closing?.0 == rhs.closing?.0 && lhs.closing?.1 == rhs.closing?.1
        }
    }

    /// How a transaction moves the printed balance.
    ///
    /// On an account, money in raises the balance. On a card, money spent
    /// does — so a card's Debit column adds and its Credit column subtracts,
    /// and a CR beside a card's figure is a payment that lowers what is owed.
    static func effect(of transaction: RawTransaction, sense: BalanceSense) -> Decimal {
        let sign: Decimal = sense == .asset ? 1 : -1
        var total: Decimal = 0
        if let out = transaction.moneyOut { total -= sign * abs(out.value) }
        if let money = transaction.moneyIn { total += sign * abs(money.value) }
        if let amount = transaction.amount {
            switch amount.marker {
            case .credit: total += sign * abs(amount.value)
            case .debit: total -= sign * abs(amount.value)
            case nil: total += amount.value
            }
        }
        return total
    }

    /// A printed balance, signed.
    ///
    /// DR on an account's balance is an overdraft; CR on a card's is money
    /// the card company owes back. Both come out negative.
    static func balance(_ printed: PrintedAmount, sense: BalanceSense) -> Decimal {
        switch (printed.marker, sense) {
        case (.debit, .asset), (.credit, .liability): return -abs(printed.value)
        case (.credit, .asset), (.debit, .liability): return abs(printed.value)
        case (nil, _): return printed.value
        }
    }

    /// Walks the table and checks every printed balance.
    ///
    /// - Parameters:
    ///   - entries: The table, in order.
    ///   - sense: Which way the balance moves.
    ///   - statedOpening: An opening balance printed outside the table.
    ///   - statedClosing: A closing balance printed outside the table.
    /// - Returns: The verdict, the signed amounts, and the two ends.
    static func reconcile(_ entries: [TableEntry], sense: BalanceSense,
                          statedOpening: Decimal?, statedClosing: Decimal?) -> Outcome {
        var running = statedOpening
        var opening: (Decimal, BalanceSource)? = statedOpening.map { ($0, .stated) }
        var unanchored: Decimal = 0
        var checked = 0
        var firstBreak: ReconciliationBreak?
        var amounts: [Decimal] = []
        var balances: [Decimal?] = []
        var totalIn: Decimal = 0, totalOut: Decimal = 0
        var lastClosingMarker: Decimal?

        let lastTransaction = entries.lastIndex { if case .transaction = $0 { return true } else { return false } } ?? -1

        /// Compares the running total with a printed balance, or makes the
        /// printed balance the baseline when there is none yet.
        func meet(_ printed: Decimal, kind: ReconciliationBreak.Kind, page: Int,
                  transaction: Int?, description: String) {
            guard let current = running else {
                opening = (printed - unanchored, .derived)
                running = printed
                return
            }
            checked += 1
            if current != printed, firstBreak == nil {
                firstBreak = ReconciliationBreak(kind: kind, page: page, transactionIndex: transaction,
                                                 description: description, printed: printed, calculated: current)
            }
            // Carry on from what was printed, so one misread cannot turn
            // every later balance into a second report of the same fault.
            running = printed
        }

        for (position, entry) in entries.enumerated() {
            switch entry {
            case .marker(let marker):
                let value = balance(marker.balance, sense: sense)
                let after = position > lastTransaction
                switch marker.kind {
                case .opening where amounts.isEmpty && running == nil:
                    opening = (value, .stated)
                    running = value
                case .closing:
                    meet(value, kind: after ? .closingBalance : .carriedForward, page: marker.page,
                         transaction: nil, description: marker.text)
                    if after { lastClosingMarker = value }
                case .opening, .running:
                    meet(value, kind: .carriedForward, page: marker.page, transaction: nil, description: marker.text)
                }

            case .transaction(let transaction):
                let change = effect(of: transaction, sense: sense)
                if running != nil { running! += change } else { unanchored += change }
                let amount = sense == .asset ? change : -change
                if amount > 0 { totalIn += amount } else { totalOut -= amount }
                amounts.append(amount)

                let printed = transaction.balance.map { balance($0, sense: sense) }
                balances.append(printed)
                if let printed {
                    meet(printed, kind: .runningBalance, page: transaction.page,
                         transaction: amounts.count - 1, description: transaction.description)
                }
            }
        }

        var closing: (Decimal, BalanceSource)?
        if let statedClosing {
            if lastClosingMarker != statedClosing {
                meet(statedClosing, kind: .closingBalance, page: entries.last.map(page(of:)) ?? 1,
                     transaction: nil, description: "closing balance")
            }
            closing = (statedClosing, .stated)
        } else if let lastClosingMarker {
            closing = (lastClosingMarker, .stated)
        } else if let running, balances.last.flatMap({ $0 }) != nil {
            closing = (running, .derived)
        }

        let status: Reconciliation.Status
        var reason: String?
        if firstBreak != nil {
            status = .broken
        } else if checked == 0 {
            status = .unverifiable
            reason = running == nil && opening == nil
                ? "the statement prints no balance to check the transactions against"
                : "only one balance is printed, and an opening worked back from it proves nothing"
        } else {
            status = .reconciled
        }

        return Outcome(
            reconciliation: Reconciliation(status: status, balancesChecked: checked,
                                           totalIn: totalIn, totalOut: totalOut,
                                           firstBreak: firstBreak, reason: reason),
            amounts: amounts, balances: balances, opening: opening, closing: closing)
    }

    /// The page an entry was printed on.
    static func page(of entry: TableEntry) -> Int {
        switch entry {
        case .transaction(let transaction): return transaction.page
        case .marker(let marker): return marker.page
        }
    }
}
