//
//  HeaderMatcher.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Finding the transaction table by its header row, and the columns by their
//  headings. Every layout decision downstream hangs off this row: a figure
//  belongs to "Paid out" because it sits under "Paid out".
//
//  A heading is matched as a PHRASE, not a word, so "Paid in" is found inside
//  a row where "Paid out" and "Paid in" sit a few points apart. And a row is
//  only a header when its headings are set apart like columns: a sentence in
//  the small print that happens to say "date", "amount" and "balance" has a
//  space between every word, and a header has a gutter between every heading.
//

import CoreGraphics
import Foundation

/// Recognises a transaction table's header row.
enum HeaderMatcher {

    /// Headings, normalised, and what each column holds. UK, Irish, US and
    /// card-statement wordings.
    static let vocabulary: [String: ColumnKind] = {
        var table: [String: ColumnKind] = [:]
        for phrase in ["date", "transaction date", "trans date", "date of transaction", "txn date"] {
            table[phrase] = .date
        }
        for phrase in ["posting date", "post date", "posted", "date posted", "value date",
                       "booking date", "effective date", "processed", "date processed"] {
            table[phrase] = .otherDate
        }
        for phrase in ["description", "details", "transaction details", "transaction description",
                       "description of transaction", "payment type and details", "particulars",
                       "narrative", "transaction", "transactions", "merchant", "payee",
                       "description details", "type and details", "transaction type and details"] {
            table[phrase] = .description
        }
        for phrase in ["paid out", "money out", "out", "debit", "debits", "withdrawal", "withdrawals",
                       "payments", "debit amount", "amount out", "outgoings", "withdrawn",
                       "withdrawals and other debits", "checks and other debits",
                       "withdrawals and debits", "payments out"] {
            table[phrase] = .moneyOut
        }
        for phrase in ["paid in", "money in", "in", "credit", "credits", "deposit", "deposits",
                       "receipts", "credit amount", "amount in", "lodgements", "lodgments",
                       "deposits and other credits", "deposits and additions", "deposits and credits",
                       "payments in"] {
            table[phrase] = .moneyIn
        }
        for phrase in ["amount", "transaction amount", "value", "amount spent"] {
            table[phrase] = .amount
        }
        for phrase in ["balance", "running balance", "balance after", "ledger balance",
                       "account balance", "daily balance"] {
            table[phrase] = .balance
        }
        return table
    }()

    /// The longest heading, in words.
    static let longestPhrase = 5

    /// Within a heading, words sit no further apart than this many heights.
    static let phraseGap: CGFloat = 1.0

    /// Between headings, at least this many heights of gutter. A space in a
    /// sentence is about a quarter of one.
    static let columnGutter: CGFloat = 0.7

    /// A heading normalised for lookup: lowercase, brackets and currency
    /// marks dropped, punctuation trimmed. "Paid out (£)" is "paid out".
    static func normalise(_ text: String) -> String {
        var body = text.lowercased()
        body = body.replacing(/\([^)]*\)/, with: " ")
        body = body.replacing(/[£$€¥:*]/, with: " ")
        for code in ["gbp", "usd", "eur", "chf", "cad", "aud"] {
            body = body.replacing(code, with: " ")
        }
        body = body.replacing(/[.,]$/, with: "")
        return body.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// What a heading names, if it is one.
    static func kind(of phrase: String) -> ColumnKind? {
        vocabulary[normalise(phrase)]
    }

    /// The columns a row sets out, when it is a transaction table's header.
    ///
    /// - Parameter row: A row of a page.
    /// - Returns: The columns, left to right, or nil when the row is not a
    ///   header: it needs a date column, a money column, three recognised
    ///   headings in all, a gutter between each, and no more unrecognised
    ///   words than recognised headings.
    static func columns(in row: TextRow) -> [Column]? {
        let words = row.words
        let height = row.height
        var columns: [Column] = []
        var unmatched: [PositionedWord] = []
        var unmatchedCells = 0
        var index = 0

        func flushUnmatched() {
            guard !unmatched.isEmpty else { return }
            let frame = unmatched.dropFirst().reduce(unmatched[0].frame) { $0.union($1.frame) }
            columns.append(Column(kind: .other, frame: frame))
            unmatchedCells += 1
            unmatched = []
        }

        while index < words.count {
            var matched = false
            for length in stride(from: min(longestPhrase, words.count - index), through: 1, by: -1) {
                let slice = Array(words[index..<index + length])
                guard isOnePhrase(slice, height: height),
                      let kind = kind(of: slice.map(\.text).joined(separator: " ")) else { continue }
                flushUnmatched()
                let frame = slice.dropFirst().reduce(slice[0].frame) { $0.union($1.frame) }
                columns.append(Column(kind: kind, frame: frame))
                index += length
                matched = true
                break
            }
            if !matched {
                if let last = unmatched.last, words[index].frame.minX - last.frame.maxX > height * phraseGap {
                    flushUnmatched()
                }
                unmatched.append(words[index])
                index += 1
            }
        }
        flushUnmatched()

        // One date column; any after the first is a second date to drop.
        var seenDate = false
        columns = columns.map { column in
            guard column.kind == .date else { return column }
            defer { seenDate = true }
            return seenDate ? Column(kind: .otherDate, frame: column.frame) : column
        }

        let recognised = columns.filter { $0.kind != .other }
        guard recognised.contains(where: { $0.kind == .date }),
              recognised.contains(where: { [.moneyOut, .moneyIn, .amount].contains($0.kind) }),
              recognised.count >= 3,
              unmatchedCells <= recognised.count else { return nil }

        for (left, right) in zip(columns, columns.dropFirst())
        where right.frame.minX - left.frame.maxX < height * columnGutter {
            return nil
        }
        return columns
    }

    /// Whether consecutive words are close enough to be one heading.
    static func isOnePhrase(_ words: [PositionedWord], height: CGFloat) -> Bool {
        zip(words, words.dropFirst()).allSatisfy { $1.frame.minX - $0.frame.maxX <= height * phraseGap }
    }
}
