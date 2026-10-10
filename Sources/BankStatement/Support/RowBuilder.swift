//
//  RowBuilder.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Words into lines, by where they sit rather than the order they came in,
//  and then the one repair a line needs before its cells can be read: money
//  that the page broke into pieces put back together.
//

import CoreGraphics
import Foundation

/// Groups words into rows.
enum RowBuilder {

    /// Words whose centres are within this many heights of a row's centre
    /// share it.
    static let rowTolerance: CGFloat = 0.4

    /// The rows of a page, top to bottom, each left to right.
    ///
    /// - Parameter page: The page's words.
    /// - Returns: Its rows.
    static func rows(of page: StatementPage) -> [TextRow] {
        // Top of the page first: PDF's origin is at the bottom.
        let sorted = page.words.sorted { $0.frame.midY > $1.frame.midY }
        var groups: [[PositionedWord]] = []
        var centres: [CGFloat] = []

        for word in sorted {
            let tolerance = max(word.frame.height, 1) * rowTolerance
            if let last = centres.last, abs(last - word.frame.midY) <= tolerance {
                groups[groups.count - 1].append(word)
                let count = CGFloat(groups[groups.count - 1].count)
                centres[centres.count - 1] = last + (word.frame.midY - last) / count
            } else {
                groups.append([word])
                centres.append(word.frame.midY)
            }
        }
        return groups.map { group in
            TextRow(page: page.number, words: mergingMoney(group.sorted { $0.frame.minX < $1.frame.minX }))
        }
    }

    /// The words of a row with money that was printed in pieces rejoined.
    ///
    /// Three ways a figure arrives split: a thousands space (`1 234,56`), a
    /// currency mark set apart (`£ 12.50`), and a direction set apart
    /// (`12.50 CR`). Each is rejoined only when the gap is a space's width and
    /// the result reads as money — so `2231 12.50` in a description stays two
    /// words.
    ///
    /// Not `\b` after the three digits: Swift's word boundary follows Unicode's
    /// word rules, which read `234,56` as ONE word, so `\d{3}\b` never matched
    /// the second half of a figure. A test caught it.
    ///
    /// - Parameter words: The row's words, left to right.
    /// - Returns: The words, with split figures joined.
    static func mergingMoney(_ words: [PositionedWord]) -> [PositionedWord] {
        // A space's width is the row's own, not a fixed share of the type
        // height: one real-layout statement (bsb-005) set every space at
        // 0.6 of a height, the old fixed limit, so "1 200,45 $" stayed three
        // words and its closing balance read as 133.60.
        let gaps = zip(words, words.dropFirst()).map { $1.frame.minX - $0.frame.maxX }.filter { $0 > 0 }.sorted()
        let typicalSpace = gaps.isEmpty ? 0 : gaps[gaps.count / 2]
        var result: [PositionedWord] = []
        for word in words {
            guard let previous = result.last else {
                result.append(word)
                continue
            }
            let height = max(previous.frame.height, word.frame.height, 1)
            let gap = word.frame.minX - previous.frame.maxX
            guard gap < max(height * 0.6, min(typicalSpace * 1.3, height * 0.9)) else {
                result.append(word)
                continue
            }
            let upper = word.text.uppercased()
            let joined: String?
            if AmountParser.isAmount(previous.text), ["CR", "DR", "-"].contains(upper) {
                joined = previous.text + upper
            } else if AmountParser.currencyMarks.contains(previous.text.uppercased()),
                      AmountParser.isAmount(word.text) {
                joined = previous.text + word.text
            } else if AmountParser.isAmount(previous.text), AmountParser.currencyMarks.contains(upper),
                      AmountParser.isAmount(previous.text + word.text) {
                // A mark set after the figure, as much of Europe prints it:
                // "114,83 €". Left alone it ended up in the description.
                joined = previous.text + word.text
            } else if previous.text.wholeMatch(of: /[\-−(+]?\p{Sc}?\d{1,3}/) != nil,
                      word.text.wholeMatch(of: /\d{3}(?!\d).*/) != nil,
                      AmountParser.isAmount(previous.text + " " + word.text) {
                joined = previous.text + " " + word.text
            } else {
                joined = nil
            }
            if let joined {
                result[result.count - 1] = PositionedWord(text: joined, frame: previous.frame.union(word.frame))
            } else {
                result.append(word)
            }
        }
        return result
    }
}
