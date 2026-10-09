//
//  CellAssigner.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A row's words, sorted into the columns its header set out.
//
//  The line between two columns is drawn halfway between their headings, and
//  a word belongs to the column its centre falls in. Halfway, and the centre,
//  because figures are right-aligned and headings often are not: a long
//  figure under a short heading starts well left of it, but its middle stays
//  on the right side of the line.
//

import CoreGraphics
import Foundation

/// Sorts a row's words into cells.
enum CellAssigner {

    /// A row's words, by column.
    struct Cells: Sendable, Equatable {
        /// The date cell's text, if there was one and it reads as a date.
        var date: String?
        /// Every word that is not a date or a figure, left to right.
        var description: [String] = []
        /// The figure under each money column.
        var money: [ColumnKind: PrintedAmount] = [:]
    }

    /// The column each word of a row falls under.
    ///
    /// - Parameters:
    ///   - row: The row.
    ///   - columns: The header's columns, left to right.
    /// - Returns: The cells.
    static func cells(of row: TextRow, columns: [Column]) -> Cells {
        var cells = Cells()
        var dateWords: [String] = []
        let ordered = columns.sorted { $0.frame.minX < $1.frame.minX }
        let boundaries = zip(ordered, ordered.dropFirst()).map { ($0.frame.maxX + $1.frame.minX) / 2 }

        for word in row.words {
            let index = boundaries.firstIndex { word.frame.midX < $0 } ?? ordered.count - 1
            let kind = ordered[index].kind
            switch kind {
            case .date:
                dateWords.append(word.text)
            case .otherDate:
                continue
            case .moneyOut, .moneyIn, .amount, .balance:
                if cells.money[kind] == nil, let amount = AmountParser.parse(word.text) {
                    cells.money[kind] = amount
                } else {
                    cells.description.append(word.text)
                }
            case .description, .other:
                cells.description.append(word.text)
            }
        }

        // The longest run of leading words that reads as a date is the date;
        // whatever follows is a description that starts further left than
        // its heading. No date at all, and every word is description.
        let length = (0...dateWords.count).reversed().first { length in
            length > 0 && DateParser.token(dateWords.prefix(length).joined(separator: " ")) != nil
        } ?? 0
        if length > 0 { cells.date = dateWords.prefix(length).joined(separator: " ") }
        cells.description.insert(contentsOf: dateWords.dropFirst(length), at: 0)
        return cells
    }
}
