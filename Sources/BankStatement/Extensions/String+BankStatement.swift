//
//  String+BankStatement.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension String {

    /// The text read as a printed amount — `1,234.56`, `1.234,56`, `(12.50)`,
    /// `12.50 CR` — with a minus or brackets making it negative. A CR or DR
    /// is dropped here: what it means depends on the statement.
    ///
    /// Exactly two decimal places, or nil: a figure without pence is not
    /// read as money.
    var statementAmount: Decimal? { AmountParser.parse(self)?.value }

    /// The text read as a statement date.
    ///
    /// - Parameter order: Which number comes first in a numeric date.
    ///   ``DateOrder/automatic`` reads it day first.
    /// - Returns: The day, without a year if none was printed.
    func statementDate(order: DateOrder = .dayFirst) -> StatementDate? {
        DateParser.token(self).flatMap {
            DateParser.resolve($0, order: order == .automatic ? .dayFirst : order)
        }
    }
}
