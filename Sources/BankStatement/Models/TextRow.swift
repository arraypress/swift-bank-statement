//
//  TextRow.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// The words that share a line on a page, left to right.
struct TextRow: Sendable, Equatable {
    /// The page, from 1.
    let page: Int
    /// The words, left to right.
    let words: [PositionedWord]

    /// The box around every word.
    var frame: CGRect { words.map(\.frame).reduce(words.first?.frame ?? .zero) { $0.union($1) } }

    /// The words joined with single spaces.
    var text: String { words.map(\.text).joined(separator: " ") }

    /// A typical word height on the row — the unit every gap is measured in,
    /// so a rule holds for 7-point and 11-point statements alike.
    var height: CGFloat {
        let heights = words.map(\.frame.height).sorted()
        return heights.isEmpty ? 10 : max(heights[heights.count / 2], 1)
    }
}
