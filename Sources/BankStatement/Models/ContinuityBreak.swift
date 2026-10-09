//
//  ContinuityBreak.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A run of statements has a proof of its own: each one opens where the last
//  one closed. A gap means a statement is missing from the run, or one of the
//  two was misread.
//

import Foundation

/// Two consecutive statements whose balances do not join up.
public struct ContinuityBreak: Sendable, Codable, Equatable {
    /// The earlier statement.
    public let previous: URL?
    /// The later statement.
    public let next: URL?
    /// What the earlier one closed with.
    public let closing: Decimal
    /// What the later one opened with.
    public let opening: Decimal

    /// - Parameters:
    ///   - previous: The earlier statement.
    ///   - next: The later statement.
    ///   - closing: Its closing balance.
    ///   - opening: The next one's opening balance.
    public init(previous: URL?, next: URL?, closing: Decimal, opening: Decimal) {
        self.previous = previous
        self.next = next
        self.closing = closing
        self.opening = opening
    }
}
