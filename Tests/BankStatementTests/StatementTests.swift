//
//  StatementTests.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Whole statements, drawn as PDFs and read back: every transaction, every
//  date, every figure, and the verdict.
//

import XCTest
@testable import BankStatement

final class StatementTests: XCTestCase {

    // MARK: - UK current account

    func testUKStatementReadsEveryTransactionExactly() throws {
        let statement = try StatementReader.read(contentsOf: ukStatement(ukTransactions, opening: dec("1200.00")).file())

        XCTAssertEqual(statement.transactions.count, ukTransactions.count)
        XCTAssertEqual(statement.transactions.map(\.amount), ukTransactions.map(\.amount))
        XCTAssertEqual(statement.transactions.map(\.description),
                       ukTransactions.map { $0.lines.joined(separator: " ") })
        XCTAssertEqual(statement.transactions.map { $0.date?.description },
                       ukTransactions.map { "2026-03-\($0.date.prefix(2))" })
        XCTAssertEqual(statement.reconciliation.status, .reconciled, "\(statement.reconciliation)")
        XCTAssertEqual(statement.openingBalance, dec("1200.00"))
        XCTAssertEqual(statement.openingSource, .stated)
        XCTAssertEqual(statement.closingBalance, ukTransactions.reduce(dec("1200.00")) { $0 + $1.amount })
        XCTAssertEqual(statement.sense, .asset)
        XCTAssertEqual(statement.warnings, [])
    }

    func testUKStatementChecksEveryPrintedBalance() throws {
        let statement = try StatementReader.read(contentsOf: ukStatement(ukTransactions, opening: dec("1200.00")).file())
        // One balance per day with transactions (9 days), the brought-forward
        // row against the summary's opening, and the closing row.
        let days = Set(ukTransactions.map(\.date)).count
        XCTAssertEqual(statement.reconciliation.balancesChecked, days + 2)
        XCTAssertEqual(statement.reconciliation.totalIn, dec("2023.52"))
        XCTAssertEqual(statement.reconciliation.totalOut, dec("2544.64"))
    }

    func testMultiPageStatementJoinsAtCarriedForward() throws {
        let doc = ukStatement(ukTransactions, opening: dec("1200.00"), perPage: 5)
        XCTAssertEqual(doc.pages.count, 3)
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.pageCount, 3)
        XCTAssertEqual(statement.transactions.map(\.amount), ukTransactions.map(\.amount))
        XCTAssertEqual(statement.transactions.map(\.page), [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3])
        XCTAssertEqual(statement.reconciliation.status, .reconciled, "\(statement.reconciliation)")
        XCTAssertEqual(statement.warnings, [])
    }
}
