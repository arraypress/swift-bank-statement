//
//  StatementDate.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A calendar day, not an instant. A statement's "12 Mar" has no time and no
//  time zone, and a `Date` would invent both — then print the 11th for anyone
//  west of the bank. The year is optional because a statement that never
//  prints one leaves nothing honest to fill it with.
//

import Foundation

/// A day as a statement prints it.
public struct StatementDate: Sendable, Equatable, Hashable, Comparable {
    /// The year, or nil when the statement never says which.
    public let year: Int?
    /// The month, 1–12.
    public let month: Int
    /// The day of the month, 1–31.
    public let day: Int

    /// - Parameters:
    ///   - year: The year, if known.
    ///   - month: The month, 1–12.
    ///   - day: The day, 1–31.
    public init(year: Int?, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: StatementDate, rhs: StatementDate) -> Bool {
        (lhs.year ?? 0, lhs.month, lhs.day) < (rhs.year ?? 0, rhs.month, rhs.day)
    }
}
