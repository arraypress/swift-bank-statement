//
//  DateOrder.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  03/04/2026 is the 3rd of April in London and the 4th of March in New York,
//  and the page does not say which. A date with a day over twelve settles it;
//  a statement where every date is twelve or under can only be settled by
//  which reading keeps the dates in order, and failing that, by the caller.
//

import Foundation

/// Which number comes first in a numeric date.
public enum DateOrder: String, Sendable, Codable, CaseIterable {
    /// Decide from the dates, and warn when they do not decide it.
    case automatic
    /// 03/04 is the 3rd of April.
    case dayFirst = "day_first"
    /// 03/04 is the 4th of March.
    case monthFirst = "month_first"
}
