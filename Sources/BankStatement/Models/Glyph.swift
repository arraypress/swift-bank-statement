//
//  Glyph.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// One character of a PDF's text layer and its box.
struct Glyph: Sendable, Equatable {
    /// The character, as a string — a composed sequence can be more than one
    /// UTF-16 unit.
    let text: String
    /// Its box on the page, origin bottom left.
    let frame: CGRect
}
