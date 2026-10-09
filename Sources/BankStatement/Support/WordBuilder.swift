//
//  WordBuilder.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Characters into words. PDFKit puts a space wherever the page leaves a gap,
//  so whitespace is the main break — but not the only one: a generator that
//  places every word separately sometimes leaves a gap with no space in the
//  text, and two columns would then read as one word.
//

import CoreGraphics
import Foundation

/// Groups a page's characters into words.
enum WordBuilder {

    /// A gap wider than this many character heights splits a word even with
    /// no space in the text. A space in a typical statement face is about a
    /// quarter of the height; letters within a word sit closer than that.
    static let gapRatio: CGFloat = 0.3

    /// The words a run of characters makes, in the order given.
    ///
    /// - Parameter glyphs: The characters, in text-layer order.
    /// - Returns: The words, each with the box around its characters.
    static func words(from glyphs: [Glyph]) -> [PositionedWord] {
        var words: [PositionedWord] = []
        var text = ""
        var frame = CGRect.null

        func flush() {
            if !text.isEmpty, !frame.isNull { words.append(PositionedWord(text: text, frame: frame)) }
            text = ""
            frame = .null
        }

        for glyph in glyphs {
            if glyph.text.allSatisfy(\.isWhitespace) || glyph.frame.isEmpty {
                flush()
                continue
            }
            if !frame.isNull {
                let height = max(frame.height, glyph.frame.height, 1)
                let gap = glyph.frame.minX - frame.maxX
                let sameLine = abs(glyph.frame.midY - frame.midY) < height / 2
                if !sameLine || gap > height * gapRatio || gap < -height * 2 { flush() }
            }
            text += glyph.text
            frame = frame.isNull ? glyph.frame : frame.union(glyph.frame)
        }
        flush()
        return words
    }
}
