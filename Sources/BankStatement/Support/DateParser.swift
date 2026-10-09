//
//  DateParser.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Dates as statements print them, in two passes: first what the text says
//  — which may be two numbers and no way to know which is the month — and
//  only then, with every date on the statement in hand, what it means.
//  Deciding one date at a time is how 03/04 becomes the 3rd of April on one
//  row and the 4th of March on the next.
//

import Foundation

/// Reads printed dates.
enum DateParser {

    /// What a date's text says, before anything is decided.
    enum Token: Sendable, Equatable {
        /// Two numbers and maybe a year: `03/04/2026`, `03.04`. Which is the
        /// day is not yet known.
        case numeric(first: Int, second: Int, year: Int?)
        /// A day and a named month, maybe a year: `12 Mar`, `Mar 12, 2026`.
        case named(day: Int, month: Int, year: Int?)
        /// Year first, which is never ambiguous: `2026-03-12`.
        case iso(year: Int, month: Int, day: Int)

        /// Whether the token carries its own year.
        var hasYear: Bool {
            switch self {
            case .numeric(_, _, let year), .named(_, _, let year): return year != nil
            case .iso: return true
            }
        }
    }

    /// Month names and their abbreviations, English. Lowercase.
    static let months: [String: Int] = {
        let names = ["january", "february", "march", "april", "may", "june", "july",
                     "august", "september", "october", "november", "december"]
        var table: [String: Int] = [:]
        for (index, name) in names.enumerated() {
            table[name] = index + 1
            table[String(name.prefix(3))] = index + 1
        }
        table["sept"] = 9
        return table
    }()

    // MARK: - Reading

    /// What a date's text says.
    ///
    /// - Parameter text: The date as printed — `03/04/2026`, `3 Mar 26`,
    ///   `12-Mar`, `Mar 12, 2026`, `2026-03-12`.
    /// - Returns: The token, or nil when the text is not a date.
    static func token(_ text: String) -> Token? {
        // A date has a digit and is short; most text asked about is neither.
        guard text.count <= 20, text.contains(where: \.isNumber) else { return nil }
        let body = text.trimmingCharacters(in: .whitespaces).lowercased()

        if let match = body.wholeMatch(of: /(\d{4})-(\d{1,2})-(\d{1,2})/) {
            return valid(.iso(year: Int(match.1)!, month: Int(match.2)!, day: Int(match.3)!))
        }
        if let match = body.wholeMatch(of: /(\d{1,2})[\/.\-](\d{1,2})(?:[\/.\-](\d{4}|\d{2}))?/) {
            return valid(.numeric(first: Int(match.1)!, second: Int(match.2)!,
                                  year: match.3.map { year(String($0)) }))
        }
        if let match = body.wholeMatch(of: /(\d{1,2})(?:st|nd|rd|th)?[ \-]?([a-z]{3,9})\.?(?:[ \-,]+(\d{4}|\d{2}))?/),
           let month = months[String(match.2)] {
            return valid(.named(day: Int(match.1)!, month: month, year: match.3.map { year(String($0)) }))
        }
        if let match = body.wholeMatch(of: /([a-z]{3,9})\.? ?(\d{1,2})(?:st|nd|rd|th)?(?:,? (\d{4}))?/),
           let month = months[String(match.1)] {
            return valid(.named(day: Int(match.2)!, month: month, year: match.3.map { year(String($0)) }))
        }
        return nil
    }

    /// The token if it could be a day of the year, under at least one
    /// reading.
    static func valid(_ token: Token) -> Token? {
        switch token {
        case .iso(_, let month, let day), .named(let day, let month, _):
            return (1...12).contains(month) && (1...31).contains(day) ? token : nil
        case .numeric(let first, let second, _):
            let dayFirst = (1...12).contains(second) && (1...31).contains(first)
            let monthFirst = (1...12).contains(first) && (1...31).contains(second)
            return dayFirst || monthFirst ? token : nil
        }
    }

    /// A printed year, with two digits read as this century.
    static func year(_ text: String) -> Int {
        let value = Int(text) ?? 0
        return text.count == 2 ? 2000 + value : value
    }

    // MARK: - Deciding

    /// Which way round numeric dates are, decided from all of them at once.
    ///
    /// A first number over twelve can only be a day; a second over twelve can
    /// only be a day. Failing that, statements list transactions in date
    /// order, so the reading that keeps them in order wins. Failing THAT —
    /// every date twelve or under, and both readings in order — nothing on
    /// the page decides it, and the answer is a guess the caller is told
    /// about.
    ///
    /// - Parameters:
    ///   - tokens: Every date token on the statement, in table order.
    ///   - fallback: The order to assume when nothing decides it.
    /// - Returns: The order, and whether the dates themselves decided it.
    static func decideOrder(_ tokens: [Token], fallback: DateOrder) -> (order: DateOrder, decided: Bool) {
        var firstOver12 = 0, secondOver12 = 0, numericCount = 0
        for case .numeric(let first, let second, _) in tokens {
            numericCount += 1
            if first > 12 { firstOver12 += 1 }
            if second > 12 { secondOver12 += 1 }
        }
        guard numericCount > 0 else { return (fallback, true) }
        if firstOver12 > secondOver12 { return (.dayFirst, true) }
        if secondOver12 > firstOver12 { return (.monthFirst, true) }

        let dayFirstInOrder = isNonDecreasing(tokens.compactMap { resolve($0, order: .dayFirst) })
        let monthFirstInOrder = isNonDecreasing(tokens.compactMap { resolve($0, order: .monthFirst) })
        if dayFirstInOrder != monthFirstInOrder { return (dayFirstInOrder ? .dayFirst : .monthFirst, true) }
        return (fallback, false)
    }

    /// Whether dates never go backwards, ignoring a missing year.
    ///
    /// A yearless list is allowed to wrap once, December to January, which a
    /// statement spanning the new year does.
    static func isNonDecreasing(_ dates: [StatementDate]) -> Bool {
        var wraps = 0
        for (previous, next) in zip(dates, dates.dropFirst()) where next < previous {
            guard previous.year == nil, next.year == nil, previous.month == 12, next.month == 1 else { return false }
            wraps += 1
        }
        return wraps <= 1
    }

    /// What a token means, read in the given order.
    ///
    /// - Returns: The date, or nil when that reading is not a real date —
    ///   13/02 read month-first.
    static func resolve(_ token: Token, order: DateOrder) -> StatementDate? {
        let date: StatementDate
        switch token {
        case .iso(let year, let month, let day):
            date = StatementDate(year: year, month: month, day: day)
        case .named(let day, let month, let year):
            date = StatementDate(year: year, month: month, day: day)
        case .numeric(let first, let second, let year):
            date = order == .monthFirst
                ? StatementDate(year: year, month: first, day: second)
                : StatementDate(year: year, month: second, day: first)
        }
        return isReal(date) ? date : nil
    }

    /// Whether a day exists — the 31st of April does not, and the 29th of
    /// February only sometimes.
    static func isReal(_ date: StatementDate) -> Bool {
        guard (1...12).contains(date.month), date.day >= 1 else { return false }
        let lengths = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard date.day <= lengths[date.month - 1] else { return false }
        if date.month == 2, date.day == 29, let year = date.year {
            return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        }
        return true
    }

    /// Gives a yearless date the year that puts it on or before the anchor
    /// and less than a year before it.
    ///
    /// A statement ending on the 14th of January 2026 that lists "28 Dec"
    /// means December 2025; one ending on the 31st of March means March of
    /// the same year. The anchor is the end of the period, so the date is
    /// placed in the year before it whenever its day of the year comes later.
    ///
    /// - Parameters:
    ///   - date: The date, with or without a year.
    ///   - anchor: The latest date the statement covers.
    /// - Returns: The date with a year; unchanged if it had one.
    static func placing(_ date: StatementDate, before anchor: StatementDate) -> StatementDate {
        guard date.year == nil, let anchorYear = anchor.year else { return date }
        let later = (date.month, date.day) > (anchor.month, anchor.day)
        let placed = StatementDate(year: later ? anchorYear - 1 : anchorYear, month: date.month, day: date.day)
        // The 29th of February in a year without one is a misread, not a date.
        return isReal(placed) ? placed : date
    }

    // MARK: - Finding

    /// Every full date — one carrying its own year — in a run of words.
    ///
    /// Tries one to four words at each position, longest first, so
    /// `31 March 2026` is one date and not a day, a month and a stray year.
    ///
    /// - Parameters:
    ///   - words: The words, in reading order.
    ///   - order: How to read a numeric date.
    /// - Returns: The dates found.
    static func fullDates(in words: [String], order: DateOrder) -> [StatementDate] {
        var found: [StatementDate] = []
        var index = 0
        while index < words.count {
            var advanced = false
            // A date starts with a digit or a month's name.
            let first = words[index].lowercased()
            guard first.first?.isNumber == true || months[String(first.prefix(3))] != nil else {
                index += 1
                continue
            }
            for length in stride(from: min(4, words.count - index), through: 1, by: -1) {
                let text = words[index..<index + length].joined(separator: " ")
                if let token = token(text), token.hasYear, let date = resolve(token, order: order) {
                    found.append(date)
                    index += length
                    advanced = true
                    break
                }
            }
            if !advanced { index += 1 }
        }
        return found
    }
}
