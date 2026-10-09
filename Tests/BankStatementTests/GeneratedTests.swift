//
//  GeneratedTests.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  A hundred statements nobody chose: random transactions, random wrapping,
//  random page lengths, from a fixed seed so a failure can be reproduced.
//  Hand-built fixtures test the cases someone thought of; these test the
//  ones nobody did.
//

import XCTest
@testable import BankStatement

/// A small deterministic generator — the same statements on every run.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class GeneratedTests: XCTestCase {

    static let words = ["TESCO", "STORES", "AMAZON", "DIRECT", "DEBIT", "CARD", "PAYMENT", "TO", "FROM",
                        "LONDON", "GB", "REF", "1043", "ACME", "LTD", "SALARY", "TRANSFER", "SAVINGS",
                        "COUNCIL", "TAX", "TFL", "TRAVEL", "2231", "ON", "MAR", "PRET", "A", "MANGER"]

    func transactions(count: Int, using generator: inout SeededGenerator) -> [FixtureTransaction] {
        var day = 2
        return (0..<count).map { _ in
            if Int.random(in: 0..<3, using: &generator) == 0 { day = min(day + Int.random(in: 1...3, using: &generator), 31) }
            let lines = (0..<Int.random(in: 1...3, using: &generator)).map { _ in
                (0..<Int.random(in: 1...4, using: &generator))
                    .map { _ in Self.words.randomElement(using: &generator)! }.joined(separator: " ")
            }
            let pence = Int.random(in: 1...250_000, using: &generator)
            let sign = Int.random(in: 0..<4, using: &generator) == 0 ? 1 : -1
            return FixtureTransaction(date: String(format: "%02d Mar", day), lines: lines,
                                      amount: Decimal(sign * pence) / 100)
        }
    }

    func testAHundredGeneratedStatementsReadExactly() throws {
        var generator = SeededGenerator(state: 20261010)
        var exact = 0
        for index in 0..<100 {
            let items = transactions(count: Int.random(in: 3...60, using: &generator), using: &generator)
            let opening = Decimal(Int.random(in: 0...500_000, using: &generator)) / 100
            let doc = ukStatement(items, opening: opening, perPage: Int.random(in: 8...40, using: &generator))
            let statement = try StatementReader.read(contentsOf: doc.file("generated-\(index)"))

            let amountsMatch = statement.transactions.map(\.amount) == items.map(\.amount)
            let textMatches = statement.transactions.map(\.description) == items.map { $0.lines.joined(separator: " ") }
            XCTAssertTrue(amountsMatch, "statement \(index): amounts")
            XCTAssertTrue(textMatches, "statement \(index): descriptions")
            XCTAssertEqual(statement.reconciliation.status, .reconciled, "statement \(index): \(statement.reconciliation)")
            if amountsMatch && textMatches && statement.isReconciled { exact += 1 }
        }
        XCTAssertEqual(exact, 100)
    }

    func testEveryGeneratedMisprintIsCaught() throws {
        // One figure in each statement printed a penny out: every one of
        // them must fail to reconcile.
        var generator = SeededGenerator(state: 7)
        for index in 0..<50 {
            var items = transactions(count: Int.random(in: 3...40, using: &generator), using: &generator)
            let doc = ukStatement(items, opening: dec("500.00"), perPage: 30)
            let victim = Int.random(in: 0..<items.count, using: &generator)
            items[victim].amount += items[victim].amount < 0 ? dec("-0.01") : dec("0.01")
            // Reprint with the wrong figure but the balances of the right ones.
            var misprinted = doc
            misprinted.pages = doc.pages.map { rows in
                rows.map { cells in
                    cells.map { cell in
                        cell.text == money(items[victim].amount - (items[victim].amount < 0 ? dec("-0.01") : dec("0.01")))
                            && (cell.x == 390 || cell.x == 460)
                            ? FixtureCell(text: money(items[victim].amount), x: cell.x, right: cell.right) : cell
                    }
                }
            }
            let statement = try StatementReader.read(contentsOf: misprinted.file("misprint-\(index)"))
            XCTAssertEqual(statement.reconciliation.status, .broken, "statement \(index) hid a misprint")
        }
    }

    func testReadingSpeed() throws {
        var generator = SeededGenerator(state: 99)
        let items = transactions(count: 400, using: &generator)
        let url = ukStatement(items, opening: dec("100.00"), perPage: 40).file("long")
        let start = Date()
        let statement = try StatementReader.read(contentsOf: url)
        let seconds = Date().timeIntervalSince(start)
        XCTAssertEqual(statement.transactions.count, 400)
        XCTAssertTrue(statement.isReconciled)
        print("READ \(statement.pageCount) pages, \(statement.transactions.count) transactions in \(String(format: "%.3f", seconds)) s")
    }
}
