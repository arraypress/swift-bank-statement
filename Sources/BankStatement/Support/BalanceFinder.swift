//
//  BalanceFinder.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The opening and closing balances printed outside the table — the summary
//  box on page one. A card statement often prints its whole sum on one line
//  ("Previous balance £500.00 Payments £500.00 New balance £212.40"), so a
//  label's figure is the first one AFTER the label, not the last on the row.
//

import Foundation

/// Finds balances printed in a statement's summary.
enum BalanceFinder {

    /// The first opening and closing balances labelled outside the table.
    ///
    /// - Parameter rows: The rows outside the transaction table.
    /// - Returns: Each figure, if one was found.
    static func stated(in rows: [TextRow]) -> (opening: PrintedAmount?, closing: PrintedAmount?) {
        var opening: PrintedAmount?
        var closing: PrintedAmount?
        for row in rows {
            if opening == nil { opening = figure(after: RowVocabulary.opening, in: row) }
            if closing == nil { closing = figure(after: RowVocabulary.closing, in: row) }
            if opening != nil, closing != nil { break }
        }
        if opening == nil || closing == nil {
            let dated = datedBalances(in: rows)
            if dated.count >= 2 {
                opening = opening ?? dated.first?.amount
                closing = closing ?? dated.last?.amount
            }
        }
        return (opening, closing)
    }

    /// The words that open a dated balance: "Balance as of 01.05.2025:",
    /// "Saldo per 31-05-2025", "Solde au 31 janvier 2025".
    static let datedLabels: Set<String> = ["balance", "saldo", "solde", "kontostand"]
    static let datedLinks: Set<String> = ["as", "of", "on", "at", "per", "op", "au", "am", "al", "em", "du", "le"]

    /// Balances labelled only by their date, earliest first.
    ///
    /// A summary that says "Balance as of 01.05.2025" and "Balance as of
    /// 31.05.2025" names its opening and closing by date, not by word: the
    /// earlier is the opening. Found on a real-layout benchmark statement
    /// (bsb-003), which printed no other balance anywhere — so without this
    /// it came back unverifiable with a page of transactions missing.
    static func datedBalances(in rows: [TextRow]) -> [(date: StatementDate, amount: PrintedAmount)] {
        var found: [(token: DateParser.Token, amount: PrintedAmount)] = []
        for row in rows {
            let words = row.words.map { $0.text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":")) }
            guard let label = words.firstIndex(where: datedLabels.contains) else { continue }
            var index = label + 1
            while index < words.count, datedLinks.contains(words[index]) { index += 1 }
            // The date may run over several words: "31 janvier 2025".
            var token: DateParser.Token?
            var end = index
            for length in stride(from: min(3, words.count - index), through: 1, by: -1) {
                if let parsed = DateParser.token(words[index..<index + length].joined(separator: " ")) {
                    token = parsed
                    end = index + length
                    break
                }
            }
            guard let token, end < row.words.count,
                  let amount = row.words[end...].lazy.compactMap({ AmountParser.parse($0.text) }).first else { continue }
            found.append((token, amount))
        }
        let order = DateParser.decideOrder(found.map(\.token), fallback: .dayFirst).order
        return found.compactMap { item in DateParser.resolve(item.token, order: order).map { ($0, item.amount) } }
            .sorted { $0.date < $1.date }
    }

    /// The first figure after any of the labels on a row.
    static func figure(after labels: [String], in row: TextRow) -> PrintedAmount? {
        let words = row.words.map { $0.text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":")) }
        for label in labels {
            let parts = label.split(separator: " ").map(String.init)
            guard parts.count <= words.count else { continue }
            for start in 0...(words.count - parts.count) where Array(words[start..<start + parts.count]) == parts {
                if let found = row.words[(start + parts.count)...].lazy.compactMap({ AmountParser.parse($0.text) }).first {
                    return found
                }
            }
        }
        return nil
    }
}
