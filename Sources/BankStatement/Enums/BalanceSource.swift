//
//  BalanceSource.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A worked-out opening balance cannot catch an error in the row it was
//  worked out from — it is that row's balance minus that row's amount, true
//  by construction. Saying which balances were printed and which were derived
//  is how a caller knows how much the reconciliation proved.
//

import Foundation

/// Where a balance came from.
public enum BalanceSource: String, Sendable, Codable {
    /// The statement printed it.
    case stated
    /// It was worked out from a running balance.
    case derived
}
