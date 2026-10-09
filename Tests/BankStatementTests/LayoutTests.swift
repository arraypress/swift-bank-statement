//
//  LayoutTests.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The other ways statements are laid out — US, debit and credit columns,
//  comma decimals, a credit card, figures on the last line — each read back
//  exactly and reconciled.
//

import XCTest
@testable import BankStatement

final class LayoutTests: XCTestCase {

    func testUSStatementReadsMonthFirstAndSignedAmounts() throws {
        let (doc, amounts) = usStatement()
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.transactions.map(\.amount), amounts)
        XCTAssertEqual(statement.dateOrder, .monthFirst)
        XCTAssertEqual(statement.transactions.map { $0.date?.description },
                       ["2026-02-16", "2026-02-18", "2026-02-23", "2026-03-02", "2026-03-09", "2026-03-13"])
        XCTAssertEqual(statement.transactions[0].description, "POS PURCHASE WHOLE FOODS #123")
        XCTAssertEqual(statement.transactions[0].balance, dec("954.80"))
        XCTAssertEqual(statement.reconciliation.status, .reconciled, "\(statement.reconciliation)")
        // Six running balances, plus the stated ending balance.
        XCTAssertEqual(statement.reconciliation.balancesChecked, 7)
        XCTAssertEqual(statement.openingSource, .stated)
        XCTAssertEqual(statement.closingBalance, dec("2168.55"))
    }

    func testDebitCreditStatementReconcilesAgainstTheSummaryAlone() throws {
        let (doc, amounts) = debitCreditStatement()
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.transactions.map(\.amount), amounts)
        XCTAssertEqual(statement.transactions.map(\.balance), Array(repeating: nil, count: amounts.count))
        XCTAssertEqual(statement.dateOrder, .dayFirst)
        XCTAssertEqual(statement.transactions.first?.date?.description, "2026-02-04")
        XCTAssertEqual(statement.reconciliation.status, .reconciled, "\(statement.reconciliation)")
        XCTAssertEqual(statement.reconciliation.balancesChecked, 1)
    }

    func testDebitCreditStatementWithAWrongClosingIsBroken() throws {
        let (doc, _) = debitCreditStatement(closing: dec("611.50"))
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.reconciliation.status, .broken)
        XCTAssertEqual(statement.reconciliation.firstBreak?.kind, .closingBalance)
        XCTAssertEqual(statement.reconciliation.firstBreak?.printed, dec("611.50"))
        XCTAssertEqual(statement.reconciliation.firstBreak?.calculated, dec("611.51"))
    }

    func testATotalsRowIsNotATransaction() throws {
        let (doc, amounts) = debitCreditStatement(totals: true)
        let statement = try StatementReader.read(contentsOf: doc.file())
        XCTAssertEqual(statement.transactions.map(\.amount), amounts)
        XCTAssertEqual(statement.reconciliation.status, .reconciled)
    }

    func testEuropeanCommaDecimals() throws {
        let (doc, amounts) = europeanStatement()
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.transactions.map(\.amount), amounts)
        XCTAssertEqual(statement.transactions.last?.balance, dec("3244.95"))
        XCTAssertEqual(statement.transactions.map { $0.date?.description },
                       ["2026-02-03", "2026-02-15", "2026-02-16", "2026-02-28"])
        XCTAssertEqual(statement.reconciliation.status, .reconciled, "\(statement.reconciliation)")
        XCTAssertEqual(statement.reconciliation.balancesChecked, 4)
    }

    func testCardStatementIsReadFromTheHoldersSide() throws {
        let (doc, amounts) = cardStatement()
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.sense, .liability)
        XCTAssertEqual(statement.transactions.map(\.amount), amounts)
        XCTAssertEqual(statement.transactions.map(\.description),
                       ["PAYMENT RECEIVED - THANK YOU", "AMAZON MARKETPLACE", "COSTA COFFEE", "BRITISH AIRWAYS"])
        // The posting date column is dropped; the transaction date is kept,
        // and March is placed in the year of the April statement date.
        XCTAssertEqual(statement.transactions.first?.date?.description, "2026-03-25")
        XCTAssertEqual(statement.openingBalance, dec("512.30"))
        XCTAssertEqual(statement.closingBalance, dec("202.39"))
        XCTAssertEqual(statement.reconciliation.status, .reconciled, "\(statement.reconciliation)")
    }

    func testFiguresOnTheLastLineAndAPeriodAcrossTheNewYear() throws {
        let (doc, amounts) = amountLastStatement()
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.transactions.map(\.amount), amounts)
        XCTAssertEqual(statement.transactions.map(\.description),
                       ["CARD PURCHASE HAMLEYS LONDON", "DIRECT DEBIT GYM MEMBERSHIP", "TRANSFER IN FROM SAVINGS"])
        XCTAssertEqual(statement.transactions.map { $0.date?.description },
                       ["2025-12-20", "2026-01-02", "2026-01-09"])
        XCTAssertEqual(statement.reconciliation.status, .reconciled, "\(statement.reconciliation)")
    }
}
