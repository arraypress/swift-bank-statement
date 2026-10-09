//
//  StatementDate+Codable.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension StatementDate: Codable, CustomStringConvertible {

    /// `2026-03-12`, or `--03-12` when the statement printed no year.
    public var description: String { DayText.format(self) }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let date = DayText.parse(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a day: \(text)")
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(DayText.format(self))
    }
}
