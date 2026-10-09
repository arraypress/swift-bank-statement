//
//  ReconciliationTests.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The promise: a misread statement does not come back looking right. Each
//  fixture here is broken on purpose — a figure misprinted, a row missing —
//  and the break has to be found, and found at the right row.
//

import XCTest
@testable import BankStatement

final class ReconciliationTests: XCTestCase {

    func testAnAlteredFigureBreaksAtItsRow() throws {
        let (doc, _) = usStatement(alter: (index: 2, amount: "-25.00"))
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.reconciliation.status, .broken)
        let found = try XCTUnwrap(statement.reconciliation.firstBreak)
        XCTAssertEqual(found.kind, .runningBalance)
        XCTAssertEqual(found.transactionIndex, 2)
        XCTAssertEqual(found.description, "CHECK 1043")
        XCTAssertEqual(found.printed, dec("2204.80"))
        XCTAssertEqual(found.calculated, dec("2429.80"))
    }

    func testADroppedRowBreaksAtTheNextBalance() throws {
        let (doc, amounts) = usStatement(drop: 3)
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.transactions.map(\.amount), amounts)
        XCTAssertEqual(statement.reconciliation.status, .broken)
        let found = try XCTUnwrap(statement.reconciliation.firstBreak)
        XCTAssertEqual(found.transactionIndex, 3)
        XCTAssertEqual(found.description, "ZELLE FROM J SMITH")
        XCTAssertEqual(found.printed - found.calculated, dec("-60.00"))
    }

    func testAWrongClosingBalanceInTheSummaryBreaks() throws {
        let doc = ukStatement(ukTransactions, opening: dec("1200.00"), alterClosing: dec("677.89"))
        let statement = try StatementReader.read(contentsOf: doc.file())

        XCTAssertEqual(statement.reconciliation.status, .broken)
        XCTAssertEqual(statement.reconciliation.firstBreak?.kind, .closingBalance)
    }

    func testOneBalanceAndNoOpeningProvesNothing() {
        // A single running balance becomes the baseline it is compared with.
        let entries: [TableEntry] = [
            .transaction(RawTransaction(dateText: "01/03", description: "A",
                                        amount: PrintedAmount(value: dec("-5.00"), marker: nil),
                                        balance: PrintedAmount(value: dec("95.00"), marker: nil), page: 1)),
        ]
        let outcome = Reconciler.reconcile(entries, sense: .asset, statedOpening: nil, statedClosing: nil)
        XCTAssertEqual(outcome.reconciliation.status, .unverifiable)
        XCTAssertEqual(outcome.reconciliation.balancesChecked, 0)
        XCTAssertEqual(outcome.opening?.0, dec("100.00"))
        XCTAssertEqual(outcome.opening?.1, .derived)
    }

    func testNoBalancesAtAllIsUnverifiable() {
        let entries: [TableEntry] = [
            .transaction(RawTransaction(dateText: nil, description: "A",
                                        moneyOut: PrintedAmount(value: dec("5.00"), marker: nil), page: 1)),
        ]
        let outcome = Reconciler.reconcile(entries, sense: .asset, statedOpening: nil, statedClosing: nil)
        XCTAssertEqual(outcome.reconciliation.status, .unverifiable)
        XCTAssertEqual(outcome.amounts, [dec("-5.00")])
    }

    func testAnOverdraftPrintedDRIsNegative() {
        XCTAssertEqual(Reconciler.balance(PrintedAmount(value: dec("12.00"), marker: .debit), sense: .asset), dec("-12.00"))
        XCTAssertEqual(Reconciler.balance(PrintedAmount(value: dec("12.00"), marker: .credit), sense: .liability), dec("-12.00"))
    }

    func testContinuityFindsAGapBetweenStatements() {
        func statement(_ name: String, month: Int, opening: Decimal, closing: Decimal) -> Statement {
            Statement(source: URL(fileURLWithPath: name), pageCount: 1, transactions: [],
                      openingBalance: opening, openingSource: .stated, closingBalance: closing, closingSource: .stated,
                      periodEnd: StatementDate(year: 2026, month: month, day: 28), sense: .asset, dateOrder: .dayFirst,
                      reconciliation: Reconciliation(status: .reconciled, balancesChecked: 1, totalIn: 0, totalOut: 0,
                                                     firstBreak: nil, reason: nil),
                      warnings: [])
        }
        let run = [statement("mar.pdf", month: 3, opening: dec("150"), closing: dec("90")),
                   statement("jan.pdf", month: 1, opening: dec("0"), closing: dec("100")),
                   statement("feb.pdf", month: 2, opening: dec("100"), closing: dec("150"))]
        XCTAssertEqual(StatementReader.continuity(of: run), [])

        let gap = [run[1], run[0]]   // February missing
        let breaks = StatementReader.continuity(of: gap)
        XCTAssertEqual(breaks.count, 1)
        XCTAssertEqual(breaks.first?.previous?.lastPathComponent, "jan.pdf")
        XCTAssertEqual(breaks.first?.closing, dec("100"))
        XCTAssertEqual(breaks.first?.opening, dec("150"))
    }
}
