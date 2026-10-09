//
//  Statement+Summary.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension Statement {

    /// Whether every printed balance agreed with the transactions.
    var isReconciled: Bool { reconciliation.status == .reconciled }

    /// The first and last transaction dates.
    var dateRange: ClosedRange<StatementDate>? {
        let dates = transactions.compactMap(\.date)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        return first...last
    }
}
