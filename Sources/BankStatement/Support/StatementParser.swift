//
//  StatementParser.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Pages of words into a statement: rows, the table, the dates, the sense,
//  the sums. Pure — no PDF, no file — so every decision can be tested
//  against words placed by hand.
//

import Foundation

/// Turns positioned words into a reconciled statement.
enum StatementParser {

    /// Words on a row that mark it as the one stating the statement's period
    /// or date — the best place to find the year that yearless dates belong
    /// to.
    static let periodWords = ["period", "statement date", "date of statement", "to", "from", "between",
                              "ending", "closing date", "statement closing", "as at", "as of"]

    /// Reads a statement from its pages.
    ///
    /// - Parameters:
    ///   - pages: Every page's words.
    ///   - source: The file they came from, for the result and for errors.
    ///   - options: What the caller knows.
    /// - Returns: The statement, reconciled.
    /// - Throws: ``StatementError/noTextLayer(_:)`` when there are no words at
    ///   all, ``StatementError/noTransactionTable(_:)`` when no table is found.
    static func parse(_ pages: [StatementPage], source: URL?, options: StatementOptions) throws -> Statement {
        guard pages.contains(where: { !$0.words.isEmpty }) else { throw StatementError.noTextLayer(source) }

        let rows = pages.flatMap(RowBuilder.rows(of:))
        let table = TableParser.parse(rows)
        let raws = table.entries.compactMap { entry -> RawTransaction? in
            if case .transaction(let transaction) = entry { return transaction }
            return nil
        }
        guard table.foundHeader, !raws.isEmpty else { throw StatementError.noTransactionTable(source) }

        var warnings: [String] = []
        let allText = rows.map(\.text).joined(separator: "\n")

        // Dates: the order first, from every date in the table at once.
        let tokens = raws.map { $0.dateText.flatMap(DateParser.token) }
        let order: DateOrder
        if options.dateOrder != .automatic {
            order = options.dateOrder
        } else {
            let fallback: DateOrder = allText.contains("$") ? .monthFirst : .dayFirst
            let decision = DateParser.decideOrder(tokens.compactMap { $0 }, fallback: fallback)
            order = decision.order
            if !decision.decided {
                warnings.append("the dates do not say which number is the day; read as "
                                + (order == .dayFirst ? "day first" : "month first")
                                + " — pass a date order to be sure")
            }
        }

        // Then the year, for dates printed without one.
        // The period is printed outside the table; the table is only searched
        // when nothing outside it carries a year.
        let periodEnd = self.periodEnd(rows: table.outside, order: order)
            ?? self.periodEnd(rows: table.inside, order: order)
            ?? options.year.map { StatementDate(year: $0, month: 12, day: 31) }
        var dates: [StatementDate?] = []
        var last: StatementDate?
        for token in tokens {
            var date = token.flatMap { DateParser.resolve($0, order: order) }
            if let resolved = date, let periodEnd { date = DateParser.placing(resolved, before: periodEnd) }
            if date == nil { date = last }
            dates.append(date)
            last = date
        }
        if dates.contains(where: { $0 != nil && $0?.year == nil }) {
            warnings.append("the statement prints no year; dates are given without one")
        }

        // The sense: whichever makes the balances agree, and the card
        // wording when both do.
        let summary = BalanceFinder.stated(in: table.outside)
        func run(_ sense: BalanceSense) -> Reconciler.Outcome {
            Reconciler.reconcile(table.entries, sense: sense,
                                 statedOpening: summary.opening.map { Reconciler.balance($0, sense: sense) },
                                 statedClosing: summary.closing.map { Reconciler.balance($0, sense: sense) })
        }
        let sense: BalanceSense
        let outcome: Reconciler.Outcome
        if let chosen = options.sense {
            sense = chosen
            outcome = run(chosen)
        } else {
            let asset = run(.asset), liability = run(.liability)
            let card = RowVocabulary.soundsLikeCard(allText)
            let assetHolds = asset.reconciliation.status == .reconciled
            let liabilityHolds = liability.reconciliation.status == .reconciled
            if liabilityHolds && (card || !assetHolds) {
                (sense, outcome) = (.liability, liability)
            } else if !assetHolds && !liabilityHolds && card {
                (sense, outcome) = (.liability, liability)
            } else {
                (sense, outcome) = (.asset, asset)
            }
        }

        let transactions = raws.indices.map { index in
            Transaction(date: dates[index], description: raws[index].description,
                        amount: outcome.amounts[index], balance: outcome.balances[index],
                        page: raws[index].page)
        }
        return Statement(source: source, pageCount: pages.count, transactions: transactions,
                         openingBalance: outcome.opening?.0, openingSource: outcome.opening?.1,
                         closingBalance: outcome.closing?.0, closingSource: outcome.closing?.1,
                         periodEnd: periodEnd, sense: sense, dateOrder: order,
                         reconciliation: outcome.reconciliation, warnings: warnings)
    }

    /// The latest full date the statement prints, preferring rows that state
    /// its period.
    ///
    /// A statement also prints dates that are not its period — a rate change
    /// next year, a payment due next month — so the period's own row is
    /// believed first, and the latest date anywhere only when no row says
    /// "period", "to" or "statement date".
    static func periodEnd(rows: [TextRow], order: DateOrder) -> StatementDate? {
        var preferred: [StatementDate] = []
        var anywhere: [StatementDate] = []
        for row in rows {
            let dates = DateParser.fullDates(in: row.words.map(\.text), order: order)
            guard !dates.isEmpty else { continue }
            anywhere += dates
            let text = " " + row.text.lowercased() + " "
            if periodWords.contains(where: { text.contains(" \($0) ") }) { preferred += dates }
        }
        return (preferred.isEmpty ? anywhere : preferred).max()
    }
}
