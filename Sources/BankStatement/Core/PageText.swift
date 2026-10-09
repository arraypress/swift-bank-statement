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
    static func glyphs(of page: PDFPage) -> [Glyph] {
        guard let string = page.string, !string.isEmpty else { return [] }
        let text = string as NSString
        var glyphs: [Glyph] = []
        glyphs.reserveCapacity(text.length)
        var location = 0
        while location < text.length {
            let range = text.rangeOfComposedCharacterSequence(at: location)
            location = NSMaxRange(range)
            let character = text.substring(with: range)
            guard !character.allSatisfy(\.isWhitespace) else {
                glyphs.append(Glyph(text: " ", frame: .zero))
                continue
            }
            guard let frame = page.selection(for: range)?.bounds(for: page), !frame.isEmpty else { continue }
            glyphs.append(Glyph(text: character, frame: frame))
        }
        return glyphs
    }
}
