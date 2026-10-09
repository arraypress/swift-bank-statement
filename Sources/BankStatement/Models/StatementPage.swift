//
//  StatementPage.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The seam between reading a PDF and parsing a statement. A PDF's text layer
//  becomes these; so could an OCR pass, which is why the parser takes pages of
//  words rather than a PDF.
//

import Foundation

/// The words on one page of a statement.
public struct StatementPage: Sendable, Codable, Equatable {
    /// The page's number, from 1.
    public let number: Int
    /// Every word on the page, in any order.
    public let words: [PositionedWord]

    /// - Parameters:
    ///   - number: The page's number, from 1.
    ///   - words: Every word on the page.
    public init(number: Int, words: [PositionedWord]) {
        self.number = number
        self.words = words
    }
}
