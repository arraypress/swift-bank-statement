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
        for phrase in ["date", "transaction date", "trans date", "date of transaction", "txn date",
                       "datum", "boekdatum", "buchungstag", "buchungsdatum", "fecha", "data", "date operation"] {
            table[phrase] = .date
        }
        for phrase in ["posting date", "post date", "posted", "date posted", "value date",
                       "booking date", "effective date", "processed", "date processed",
                       "valutadatum", "rentedatum", "wertstellung", "valuta", "date de valeur", "fecha valor"] {
            table[phrase] = .otherDate
        }
        for phrase in ["description", "details", "transaction details", "transaction description",
                       "description of transaction", "payment type and details", "particulars",
                       "narrative", "transaction", "transactions", "merchant", "payee",
                       "description details", "type and details", "transaction type and details",
                       "omschrijving", "beschrijving", "mededelingen", "verwendungszweck", "buchungstext",
                       "libelle", "operation", "operations", "nature de l'operation", "concepto", "descripcion"] {
            table[phrase] = .description
        }
        for phrase in ["paid out", "money out", "out", "debit", "debits", "withdrawal", "withdrawals",
                       "payments", "debit amount", "amount out", "outgoings", "withdrawn",
                       "withdrawals and other debits", "checks and other debits",
                       "withdrawals and debits", "payments out",
                       "af", "debet", "soll", "cargo", "cargos", "cheques et debits", "retraits"] {
            table[phrase] = .moneyOut
        }
        for phrase in ["paid in", "money in", "in", "credit", "credits", "deposit", "deposits",
                       "receipts", "credit amount", "amount in", "lodgements", "lodgments",
                       "deposits and other credits", "deposits and additions", "deposits and credits",
                       "payments in",
                       "bij", "haben", "abono", "abonos", "depots et credits", "depots"] {
            table[phrase] = .moneyIn
        }
        for phrase in ["amount", "transaction amount", "value", "amount spent",
                       "bedrag", "betrag", "montant", "importe", "importo"] {
            table[phrase] = .amount
        }
        for phrase in ["balance", "running balance", "balance after", "ledger balance",
                       "account balance", "daily balance",
                       "saldo", "solde", "kontostand"] {
            table[phrase] = .balance
        }
        return table
    }()

    /// Words a header row carries: a date heading in any of the languages
    /// above, or — for a table with its dates inside the description — a
    /// balance heading.
    static let headerCues = ["date", "datum", "fecha", "data", "balance", "solde", "saldo", "kontostand"]

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
        // Accents folded: "Détails", "Dépôts et crédits", "Débit".
        var body = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
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
        // Every date heading says "date"; a row without the word is not a
        // header, and most rows are not.
        // Every date heading says "date" in one of the languages here — or
        // the table has no date column and keeps its dates at the start of
        // the description, and then it says balance. Most rows say neither.
        let lowered = row.text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        guard row.words.count >= 3,
              headerCues.contains(where: { lowered.contains($0) }) else { return nil }
        let height = row.height
        var columns: [Column] = []
        var unmatchedCells = 0

        // Cells first: words closer than a column gutter are one heading.
        // Matching phrases across the whole row instead split "Merchant
        // Name or Transaction Description" into an unknown "Merchant Name
        // or" and a description a fifth of a line apart — and the gutter
        // check then refused the row. Found on a real-layout benchmark
        // statement (bsb-002), with "Interest Date" (bsb-003) the same way.
        for cell in cells(of: row.words, height: height) {
            let frame = cell.dropFirst().reduce(cell[0].frame) { $0.union($1.frame) }
            if let kind = kind(ofCell: cell, height: height) {
                columns.append(Column(kind: kind, frame: frame))
            } else if let split = phrases(in: cell, height: height) {
                // Two headings set too close to be told apart by the gutter:
                // fall back to finding each phrase within the cell.
                columns += split
            } else {
                columns.append(Column(kind: .other, frame: frame))
                unmatchedCells += 1
            }
        }

        // One date column; any after the first is a second date to drop.
        var seenDate = false
        columns = columns.map { column in
            guard column.kind == .date else { return column }
            defer { seenDate = true }
            return seenDate ? Column(kind: .otherDate, frame: column.frame) : column
        }

        let recognised = columns.filter { $0.kind != .other }
        // A date column, or — for a table that prints its dates inside the
        // description (bsb-005, French) — a description AND a balance, which
        // a sentence in the small print is unlikely to set out in columns.
        let dated = recognised.contains(where: { $0.kind == .date })
            || (recognised.contains(where: { $0.kind == .description }) && recognised.contains(where: { $0.kind == .balance }))
        guard dated,
              recognised.contains(where: { [.moneyOut, .moneyIn, .amount].contains($0.kind) }),
              recognised.count >= 3,
              unmatchedCells <= recognised.count else { return nil }

        for (left, right) in zip(columns, columns.dropFirst())
        where right.frame.minX - left.frame.maxX < height * columnGutter {
            return nil
        }
        return columns
    }

    /// Runs of words with no gutter between them — one heading each.
    static func cells(of words: [PositionedWord], height: CGFloat) -> [[PositionedWord]] {
        var cells: [[PositionedWord]] = []
        for word in words {
            if let last = cells.last?.last, word.frame.minX - last.frame.maxX < height * columnGutter {
                cells[cells.count - 1].append(word)
            } else {
                cells.append([word])
            }
        }
        return cells
    }

    /// What a whole cell names: the cell itself if it is a known heading,
    /// otherwise the longest known heading inside it — "Merchant Name or
    /// Transaction Description" is a description, "Interest Date" a date —
    /// as long as every heading inside it agrees on the kind.
    static func kind(ofCell cell: [PositionedWord], height: CGFloat) -> ColumnKind? {
        let texts = cell.map(\.text)
        if let whole = kind(of: texts.joined(separator: " ")) { return whole }
        var found: [(length: Int, kind: ColumnKind)] = []
        for start in texts.indices {
            for length in 1...min(longestPhrase, texts.count - start) {
                if let kind = kind(of: texts[start..<start + length].joined(separator: " ")) {
                    found.append((length, kind))
                }
            }
        }
        guard let longest = found.max(by: { $0.length < $1.length }) else { return nil }
        return Set(found.map(\.kind)).count == 1 ? longest.kind : nil
    }

    /// Each known heading in a cell that holds more than one kind, left to
    /// right — the old word-by-word matching, kept for headings set closer
    /// than a gutter. Nil when the cell names nothing.
    static func phrases(in cell: [PositionedWord], height: CGFloat) -> [Column]? {
        var columns: [Column] = []
        var other: [PositionedWord] = []
        func flush() {
            guard let first = other.first else { return }
            columns.append(Column(kind: .other, frame: other.dropFirst().reduce(first.frame) { $0.union($1.frame) }))
            other = []
        }
        var index = 0
        while index < cell.count {
            var matched = false
            for length in stride(from: min(longestPhrase, cell.count - index), through: 1, by: -1) {
                let slice = Array(cell[index..<index + length])
                guard let kind = kind(of: slice.map(\.text).joined(separator: " ")) else { continue }
                flush()
                columns.append(Column(kind: kind, frame: slice.dropFirst().reduce(slice[0].frame) { $0.union($1.frame) }))
                index += length
                matched = true
                break
            }
            if !matched {
                // Kept, not dropped: the words between headings are what make
                // a sentence in the small print fail the gutter check.
                other.append(cell[index])
                index += 1
            }
        }
        flush()
        return columns.filter { $0.kind != .other }.count > 1 ? columns : nil
    }

    /// Whether consecutive words are close enough to be one heading.
    static func isOnePhrase(_ words: [PositionedWord], height: CGFloat) -> Bool {
        zip(words, words.dropFirst()).allSatisfy { $1.frame.minX - $0.frame.maxX <= height * phraseGap }
    }
}
