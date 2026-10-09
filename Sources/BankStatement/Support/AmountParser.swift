//
//  AmountParser.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Money as a statement prints it, read into a `Decimal` and never a
//  `Double`: 0.1 + 0.2 is not 0.3 in binary floating point, and a
//  reconciliation that compares sums of four hundred binary fractions has to
//  forgive an error, which means it can no longer tell a rounding error from
//  a missing penny. Decimal sums are exact, so the comparison is `==`.
//
//  A figure must have exactly two decimal places to count as money. That one
//  rule is what keeps "TESCO STORES 2231" and "CARD 4417" out of the amount
//  columns, and every statement this was built against prints pence and
//  cents. Currencies without minor units (yen) are the cost.
//

import Foundation

/// Reads printed money.
enum AmountParser {

    /// Currency symbols and codes that may lead or trail a figure.
    static let currencyMarks = ["£", "$", "€", "¥", "₹", "GBP", "USD", "EUR", "CHF", "CAD", "AUD", "NZD", "US$", "A$", "C$"]

    /// Reads a printed figure.
    ///
    /// Accepts `1,234.56`, `1.234,56`, `1 234,56`, `1'234.56`, a leading or
    /// trailing minus, brackets, a currency mark either side, and a `CR` or
    /// `DR` suffix — attached or not.
    ///
    /// - Parameter text: The figure as printed.
    /// - Returns: The amount, or nil when the text is not money.
    static func parse(_ text: String) -> PrintedAmount? {
        // Every word of every row is asked; most have no digit at all.
        guard text.count <= 24, text.contains(where: \.isASCIIDigit) else { return nil }
        var body = text.trimmingCharacters(in: .whitespaces).uppercased()
        guard !body.isEmpty else { return nil }

        var marker: PrintedAmount.Marker?
        for candidate in [PrintedAmount.Marker.credit, .debit] where body.hasSuffix(candidate.rawValue) {
            marker = candidate
            body = String(body.dropLast(2)).trimmingCharacters(in: .whitespaces)
        }

        var negative = false
        if body.hasPrefix("("), body.hasSuffix(")") {
            negative = true
            body = String(body.dropFirst().dropLast())
        }
        body = stripCurrency(body)
        for minus in ["-", "−", "–"] {
            if body.hasPrefix(minus) {
                negative = true
                body = String(body.dropFirst())
            } else if body.hasSuffix(minus) {
                negative = true
                body = String(body.dropLast())
            }
        }
        if body.hasPrefix("+") { body = String(body.dropFirst()) }
        // A sign can sit outside the currency mark as well as inside it.
        body = stripCurrency(body)

        guard let magnitude = magnitude(of: body) else { return nil }
        return PrintedAmount(value: negative ? -magnitude : magnitude, marker: marker)
    }

    /// Whether the text reads as money.
    static func isAmount(_ text: String) -> Bool { parse(text) != nil }

    /// The digits of a figure with no sign, as a Decimal.
    ///
    /// The decimal separator is whichever of `.` and `,` sits third from the
    /// end; everything else that groups digits — commas, dots, apostrophes,
    /// spaces of any width — is thrown away, but only where it sits between
    /// groups of three.
    static func magnitude(of body: String) -> Decimal? {
        let pattern = /^(\d{1,3}(?:[,.' \u{00A0}\u{202F}]\d{3})+|\d+)([.,])(\d{2})$/
        guard let match = body.wholeMatch(of: pattern) else { return nil }
        let whole = String(match.1).filter(\.isASCIIDigit)
        let grouping = String(match.1).first { !$0.isASCIIDigit }
        // 1,234,56 is not a figure: the grouping mark and the decimal mark
        // must differ when there is grouping at all.
        if let grouping, String(grouping) == String(match.2) { return nil }
        return Decimal(string: "\(whole).\(match.3)", locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The text with a currency mark removed from either end.
    static func stripCurrency(_ text: String) -> String {
        var body = text
        for mark in currencyMarks.sorted(by: { $0.count > $1.count }) {
            if body.hasPrefix(mark) { body = String(body.dropFirst(mark.count)) }
            if body.hasSuffix(mark) { body = String(body.dropLast(mark.count)) }
        }
        return body.trimmingCharacters(in: .whitespaces)
    }
}

private extension Character {
    /// 0–9 only — `isNumber` also accepts ½ and Arabic-Indic digits.
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
