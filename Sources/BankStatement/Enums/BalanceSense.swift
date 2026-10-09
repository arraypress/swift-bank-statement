//
//  BalanceSense.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A current account's balance is money you have; a credit card's is money
//  you owe. The same purchase lowers one and raises the other, so the same
//  arithmetic cannot check both.
//

import Foundation

/// Which way a statement's balance moves.
public enum BalanceSense: String, Sendable, Codable, CaseIterable {
    /// The balance is money held: it rises with money in.
    case asset
    /// The balance is money owed: it rises with money spent.
    case liability
}
