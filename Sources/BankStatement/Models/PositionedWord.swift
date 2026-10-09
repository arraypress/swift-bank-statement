//
//  PositionedWord.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A word and where it sat. Everything the parser decides — which column a
//  number belongs to, which line a word is on, where the table ends — is
//  decided from these rectangles, never from the order the text came out in:
//  PDFKit hands text back in drawing order, and a statement's drawing order is
//  whatever its generator felt like.
//

import CoreGraphics
import Foundation

/// One word on a page, in PDF points with the origin at the bottom left.
public struct PositionedWord: Sendable, Codable, Equatable, Hashable {
    /// The word, with no surrounding whitespace.
    public let text: String
    /// Where it sat on the page, in points, origin bottom left — PDF's own
    /// convention, kept so the numbers match anything else reading the page.
    public let frame: CGRect

    /// - Parameters:
    ///   - text: The word.
    ///   - frame: Its box on the page.
    public init(text: String, frame: CGRect) {
        self.text = text
        self.frame = frame
    }
}
