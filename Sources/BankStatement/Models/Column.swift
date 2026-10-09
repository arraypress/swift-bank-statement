//
//  Column.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// A column of a transaction table, as its header row placed it.
struct Column: Sendable, Equatable {
    /// What it holds.
    let kind: ColumnKind
    /// Where its heading sat.
    let frame: CGRect
}
