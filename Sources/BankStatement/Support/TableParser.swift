//
//  TableParser.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Rows into entries: which rows belong to the transaction table, what each
//  one is, and which description lines belong to which transaction.
//
//  Statements break a long description over lines in one of two ways. Most
//  print the figure on the FIRST line and let the description run on below;
//  some print the date on the first line and the figure on the LAST. A row
//  with words and no figure means opposite things in the two, so the layout
//  is decided once, from the whole statement, by counting which kind of
//  dated row it has more of.
//

import CoreGraphics
import Foundation

/// Finds the transaction table and reads it.
enum TableParser {

    /// A gap above a row of more than this many typical row pitches ends the
    /// table on that page: what follows is a footer or a summary.
    static let tableEndPitches: CGFloat = 3.5

    /// The table, read.
    struct Result: Sendable, Equatable {
        /// Every table row that matters, in order.
        var entries: [TableEntry] = []
        /// The rows outside any table, for summaries and dates.
        var outside: [TextRow] = []
        /// The rows inside a table, headers included.
        var inside: [TextRow] = []
        /// Whether any header row was found.
        var foundHeader = false
    }

    /// One table row, classified but not yet folded.
    enum Line: Sendable, Equatable {
        /// A row with a figure in a money column.
        case figure(RawTransaction)
        /// A row with words and no figure.
        case words(date: String?, text: String, page: Int)
        /// A row printing a balance.
        case marker(BalanceMarker)
    }

    /// Reads every page's rows.
    ///
    /// - Parameter rows: Every row of every page, page by page, top to bottom.
    /// - Returns: The entries, and the rows that were not part of a table.
    static func parse(_ rows: [TextRow]) -> Result {
        var result = Result()
        var lines: [Line] = []
        var columns: [Column]?
        var inTable = false
        var page = 0
        var lastY: CGFloat?
        var pitches: [CGFloat] = []
        // The page a table was seen to end on. It does not restart there
        // without a header: below its end is a footer, whatever it looks like.
        var endedOn: Int?
        // Whether the previous row was a header — its second line is skipped.
        var headerAbove = false

        for row in rows {
            if row.page != page {
                page = row.page
                inTable = false
                lastY = nil
            }
            if let found = HeaderMatcher.columns(in: row) {
                columns = found
                inTable = true
                lastY = row.frame.midY
                result.foundHeader = true
                result.inside.append(row)
                headerAbove = true
                continue
            }
            guard let columns else {
                result.outside.append(row)
                continue
            }

            let cells = CellAssigner.cells(of: row, columns: columns)
            // The header's second line — the same headings in a second
            // language (日期 進支詳情 存入 提取 結餘), or a lone "($)" — has no
            // date and no figure. Read as a row it became the tail of the
            // transaction above it.
            if headerAbove, cells.date == nil, cells.money.isEmpty {
                headerAbove = false
                result.inside.append(row)
                continue
            }
            headerAbove = false
            // An undated line whose only figures are zero is the description
            // running on, not a transaction: one card statement (bsb-002 of a
            // real-layout benchmark) prints 0.00 beside every continuation
            // line, and reading them as transactions doubled the count while
            // still "reconciling" — a zero changes no sum.
            let zeroOnly = cells.date == nil && !cells.money.isEmpty
                && cells.money.filter { $0.key != .balance }.allSatisfy { $0.value.value == 0 }
            let figures = !zeroOnly && cells.money.keys.contains { $0 != .balance }

            if inTable, let lastY {
                let pitch = median(pitches) ?? row.height * 1.5
                let gap = lastY - row.frame.midY
                if gap > max(pitch * tableEndPitches, row.height * 2.5) {
                    inTable = false
                    endedOn = row.page
                } else {
                    pitches.append(gap)
                }
            }
            // A page with no header of its own continues the last table from
            // its first transaction, never from its letterhead.
            if !inTable, endedOn != row.page, figures, cells.date != nil {
                inTable = true
            }
            guard inTable else {
                result.outside.append(row)
                continue
            }
            lastY = row.frame.midY
            result.inside.append(row)

            let text = cells.description.joined(separator: " ")
            if let kind = RowVocabulary.balanceKind(of: row.text) {
                let figure = cells.money[.balance] ?? row.words.reversed().lazy.compactMap { AmountParser.parse($0.text) }.first
                if let figure {
                    lines.append(.marker(BalanceMarker(kind: kind, balance: figure, page: row.page, text: text)))
                }
                // Anything under a balance carried forward is the page's footer.
                if kind == .closing {
                    inTable = false
                    endedOn = row.page
                }
                continue
            }
            // A total is skipped, not taken as the table's end: a merchant
            // called TOTAL UK starts its row the same way. Skipping that one
            // by mistake leaves a figure out, and the next balance says so.
            if RowVocabulary.isTotal(text), cells.date == nil { continue }
            if figures {
                lines.append(.figure(RawTransaction(
                    dateText: cells.date, description: text,
                    moneyOut: cells.money[.moneyOut], moneyIn: cells.money[.moneyIn],
                    amount: cells.money[.amount], balance: cells.money[.balance], page: row.page)))
            } else if let balance = cells.money[.balance], text.isEmpty, cells.date == nil {
                lines.append(.marker(BalanceMarker(kind: .running, balance: balance, page: row.page, text: "")))
            } else if !text.isEmpty || cells.date != nil {
                lines.append(.words(date: cells.date, text: text, page: row.page))
            }
        }

        result.entries = fold(lines)
        return result
    }

    /// Folds description lines into the transactions they belong to.
    ///
    /// - Parameter lines: The table's rows, classified.
    /// - Returns: One entry per transaction or balance.
    static func fold(_ lines: [Line]) -> [TableEntry] {
        let amountLast = isAmountOnLastLine(lines)
        var entries: [TableEntry] = []
        var pending: (date: String?, text: [String])?

        for line in lines {
            switch line {
            case .marker(let marker):
                pending = nil
                entries.append(.marker(marker))

            case .figure(var transaction):
                if let held = pending {
                    transaction.dateText = transaction.dateText ?? held.date
                    transaction.description = (held.text + [transaction.description])
                        .filter { !$0.isEmpty }.joined(separator: " ")
                    pending = nil
                }
                entries.append(.transaction(transaction))

            case .words(let date, let text, _):
                if date != nil || amountLast {
                    if date != nil || pending == nil {
                        pending = (date, [text])
                    } else {
                        pending?.text.append(text)
                    }
                } else if case .transaction(var last)? = entries.last {
                    last.description = [last.description, text].filter { !$0.isEmpty }.joined(separator: " ")
                    entries[entries.count - 1] = .transaction(last)
                } else if pending != nil {
                    pending?.text.append(text)
                }
            }
        }
        return entries
    }

    /// Whether this statement prints a wrapped transaction's figure on its
    /// last line rather than its first.
    ///
    /// Counted from dated rows: a dated row with no figure is the first line
    /// of a transaction whose figure comes later.
    static func isAmountOnLastLine(_ lines: [Line]) -> Bool {
        var datedWithFigure = 0, datedWithout = 0
        for line in lines {
            switch line {
            case .figure(let transaction) where transaction.dateText != nil: datedWithFigure += 1
            case .words(let date, _, _) where date != nil: datedWithout += 1
            default: break
            }
        }
        return datedWithout > datedWithFigure
    }

    /// The middle value, or nil for none.
    static func median(_ values: [CGFloat]) -> CGFloat? {
        guard !values.isEmpty else { return nil }
        return values.sorted()[values.count / 2]
    }
}
