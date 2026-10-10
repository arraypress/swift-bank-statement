//
//  AccountSplitter.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  One PDF, several accounts. A bank that keeps a current account and a
//  savings account together prints them as one statement, each under its
//  own heading — "HKD Current Account — 817-890692-838", then the same
//  heading again with "(Continued)" on the next page. Read as one table, the
//  second account's first balance was checked against the first account's
//  last, and an honest statement came back `broken` (bsb-004, a published
//  Hong Kong layout). Here the rows are cut at each heading that names a
//  different account, so each account reconciles on its own.
//

import Foundation

/// Finds the accounts in a statement and the rows belonging to each.
enum AccountSplitter {

    /// "Account" as statements print it.
    static let accountWords = ["account", "konto", "compte", "cuenta", "conta", "rekening", "conto",
                               "戶口", "账户", "帳戶", "口座"]

    /// One account's part of the statement.
    struct Section: Equatable {
        /// The account's digits, which tell one account from another.
        let id: String
        /// What to call it: its name and the last four digits, masked.
        let label: String
        /// Its rows, heading included.
        var rows: [TextRow]
    }

    /// The account a row is the heading of, if it is one.
    ///
    /// A heading names an account and carries a number of eight digits or
    /// more, and carries no money: a transaction that says "transfer to
    /// account 12345678" has an amount on its row, a heading does not.
    static func heading(_ row: TextRow) -> (id: String, label: String)? {
        let text = row.text
        let lowered = text.lowercased()
        guard accountWords.contains(where: { lowered.contains($0) }),
              !row.words.contains(where: { AmountParser.isAmount($0.text) }),
              let match = text.range(of: #"[0-9][0-9\- ]{6,}[0-9]"#, options: .regularExpression) else { return nil }
        let digits = text[match].filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        var name = String(text[..<match.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: " —–-:#").union(.whitespaces))
        if name.isEmpty { name = "Account" }
        return (String(digits), "\(name) ••••\(digits.suffix(4))")
    }

    /// The statement cut at its account headings.
    ///
    /// - Parameter rows: Every row, in reading order.
    /// - Returns: The rows before the first heading — the summary page,
    ///   which every account shares — and one section per account, in the
    ///   order each first appears. A run interrupted by another number — the
    ///   customer number in a page header, measured on bsb-004, cut each
    ///   account into two and three pieces — is joined back to its account.
    ///   A number that heads no table (a summary listing, a page header)
    ///   becomes a section of its own, which the caller drops for having no
    ///   transactions.
    static func split(_ rows: [TextRow]) -> (preamble: [TextRow], sections: [Section]) {
        var preamble: [TextRow] = []
        var sections: [Section] = []
        var current: Int?
        for row in rows {
            if let found = heading(row) {
                if let existing = sections.firstIndex(where: { $0.id == found.id }) {
                    current = existing
                    sections[existing].rows.append(row)
                } else {
                    sections.append(Section(id: found.id, label: found.label, rows: [row]))
                    current = sections.count - 1
                }
            } else if let current {
                sections[current].rows.append(row)
            } else {
                preamble.append(row)
            }
        }
        return (preamble, sections)
    }
}
