//
//  Continuity.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Checks that a run of statements joins up.
enum Continuity {

    /// Every pair of consecutive statements whose balances do not meet.
    static func breaks(in statements: [Statement]) -> [ContinuityBreak] {
        let ordered = statements.sorted { lhs, rhs in
            let left = lhs.periodEnd ?? lhs.transactions.last?.date
            let right = rhs.periodEnd ?? rhs.transactions.last?.date
            switch (left, right) {
            case let (left?, right?): return left < right
            case (nil, _?): return true
            default: return false
            }
        }
        return zip(ordered, ordered.dropFirst()).compactMap { previous, next in
            guard let closing = previous.closingBalance, let opening = next.openingBalance,
                  closing != opening else { return nil }
            return ContinuityBreak(previous: previous.source, next: next.source,
                                   closing: closing, opening: opening)
        }
    }
}
