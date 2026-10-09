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
        return (opening, closing)
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
