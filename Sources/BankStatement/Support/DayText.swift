//
//  DayText.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A day as text: ISO 8601, `2026-03-12`, and for a day with no year the
//  form ISO 8601 itself gives it, `--03-12` — rather than a year invented to
//  fill the gap.
//

import Foundation

/// Writes and reads days as ISO 8601 text.
enum DayText {

    /// The day as `2026-03-12`, or `--03-12` without a year.
    static func format(_ date: StatementDate) -> String {
        let monthDay = String(format: "%02d-%02d", date.month, date.day)
        guard let year = date.year else { return "--" + monthDay }
        return String(format: "%04d-", year) + monthDay
    }

    /// The day `format` wrote, or nil.
    static func parse(_ text: String) -> StatementDate? {
        if let match = text.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/) {
            return StatementDate(year: Int(match.1), month: Int(match.2)!, day: Int(match.3)!)
        }
        if let match = text.wholeMatch(of: /--(\d{2})-(\d{2})/) {
            return StatementDate(year: nil, month: Int(match.1)!, day: Int(match.2)!)
        }
        return nil
    }
}
