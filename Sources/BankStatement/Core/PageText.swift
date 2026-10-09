//
//  PageText.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Reading a PDF's text layer with positions.
//
//  PROBED before this was written, on a generated statement: PDFKit's
//  `characterBounds(at:)` drifts ONE character per line break away from
//  `PDFPage.string` — index 42 reported the box of character 43 — so every
//  word after the first line would have been placed under its neighbour.
//  `selection(for:)` on a one-character range agrees with the string, so
//  that is what this uses. `selectionsByLine()` was ruled out too: it split
//  one printed row in two at the gap before the money columns.
//
//  Read a token at a time, the whole text layer of an eleven-page statement
//  takes 0.04 s (measured, release build); the parsing after it is where the
//  time goes.
//

import CoreGraphics
import Foundation
import PDFKit

/// Reads positioned words out of a PDF.
enum PageText {

    /// Every page's words.
    static func pages(of document: PDFDocument) -> [StatementPage] {
        (0..<document.pageCount).compactMap { index in
            guard let page = document.page(at: index) else { return nil }
            return StatementPage(number: index + 1, words: WordBuilder.words(from: glyphs(of: page)))
        }
    }

    /// Every character of a page with its box.
    ///
    /// Asked for a token at a time — a run of non-space characters — rather
    /// than a character at a time: a selection is the expensive call, and a
    /// page of a statement has six times as many characters as tokens. A
    /// token whose box is too wide for its length is two columns with no
    /// space in the text between them, and only that one is asked for again
    /// character by character, so the word builder can split it at the gap.
    static func glyphs(of page: PDFPage) -> [Glyph] {
        guard let string = page.string, !string.isEmpty else { return [] }
        let text = string as NSString
        var glyphs: [Glyph] = []
        glyphs.reserveCapacity(text.length / 4)
        let pattern = try! NSRegularExpression(pattern: "\\S+")

        for match in pattern.matches(in: string, range: NSRange(location: 0, length: text.length)) {
            let range = match.range
            guard let frame = page.selection(for: range)?.bounds(for: page), !frame.isEmpty else { continue }
            let token = text.substring(with: range)
            // A character is rarely wider than its height; a token much wider
            // than that per character has a gap inside it.
            if frame.width > frame.height * CGFloat(token.count) * 1.2 || frame.height > 40 {
                glyphs += characters(of: page, in: range, text: text)
            } else {
                glyphs.append(Glyph(text: token, frame: frame))
            }
            glyphs.append(Glyph(text: " ", frame: .zero))
        }
        return glyphs
    }

    /// The characters of one range, each with its own box.
    static func characters(of page: PDFPage, in range: NSRange, text: NSString) -> [Glyph] {
        var glyphs: [Glyph] = []
        var location = range.location
        while location < NSMaxRange(range) {
            let character = text.rangeOfComposedCharacterSequence(at: location)
            location = NSMaxRange(character)
            guard let frame = page.selection(for: character)?.bounds(for: page), !frame.isEmpty else { continue }
            glyphs.append(Glyph(text: text.substring(with: character), frame: frame))
        }
        return glyphs
    }
}
