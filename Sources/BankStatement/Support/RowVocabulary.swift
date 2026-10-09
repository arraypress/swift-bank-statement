//
//  RowVocabulary.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The words that make a row something other than a transaction: a balance
//  brought or carried, an opening or closing figure, a total. A total row
//  sits under the money columns with figures in them and is the easiest way
//  to double a statement's spending.
//

import Foundation

/// Phrases that label balances and totals.
enum RowVocabulary {

    /// Labels for the balance a statement, or a page of one, opens with.
    static let opening = ["balance brought forward", "brought forward", "opening balance", "previous balance",
                          "start balance", "starting balance", "beginning balance", "balance b/f", "b/f",
                          "balance forward", "balance at start", "balance from previous statement"]

    /// Labels for the balance a statement, or a page of one, closes with.
    static let closing = ["balance carried forward", "carried forward", "closing balance", "new balance",
                          "ending balance", "end balance", "balance c/f", "c/f", "balance at end",
                          "statement balance", "balance to next statement"]

    /// Labels for a row of totals.
    static let totals = ["total", "totals", "sub-total", "subtotal", "sub total"]

    /// Wording that only a credit card statement uses.
    static let cardHints = ["credit limit", "minimum payment", "available credit", "minimum amount due",
                            "minimum payment due", "payment due date", "available to spend"]

    /// The kind of balance a row's text labels, if it labels one.
    static func balanceKind(of text: String) -> BalanceMarker.Kind? {
        let body = " " + text.lowercased() + " "
        if closing.contains(where: { body.contains(" \($0) ") }) { return .closing }
        if opening.contains(where: { body.contains(" \($0) ") }) { return .opening }
        return nil
    }

    /// Whether a row's text is a total: it STARTS with the word. Anywhere in
    /// the row would also catch CARD PAYMENT TO TOTAL UK.
    static func isTotal(_ text: String) -> Bool {
        let body = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return totals.contains { body == $0 || body.hasPrefix($0 + " ") || body.hasPrefix($0 + ":") }
    }

    /// Whether text reads like a credit card statement.
    static func soundsLikeCard(_ text: String) -> Bool {
        let body = text.lowercased()
        return cardHints.contains { body.contains($0) }
    }
}
