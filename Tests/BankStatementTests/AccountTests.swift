//
//  AccountTests.swift
//  BankStatementTests
//
//  Created by David Sherlock on 2026.
//
//  Several accounts in one statement. bsb-004, a published Hong Kong
//  layout, holds a current and a savings account under their own headings;
//  read as one table the second account's balances were checked against
//  the first's and an honest statement came back broken. Rebuilt here from
//  a fixture with the same shape: two headed accounts, a page header that
//  carries another long number between them, and a transfer whose
//  description names an account — which must not start one.
//

import XCTest
@testable import BankStatement

final class AccountTests: XCTestCase {

    private func cell(_ text: String, _ x: CGFloat, right: Bool = false) -> FixtureCell {
        FixtureCell(text: text, x: x, right: right)
    }

    /// One account's table: a heading, the column header, an opening row,
    /// transactions and running balances.
    private func account(_ name: String, number: String, opening: Decimal, moves: [(String, String, Decimal)],
                         into document: inout FixtureDocument) {
        document.add([cell("\(name) — \(number)", 40)])
        document.add([cell("Date", 40), cell("Description", 110), cell("Withdrawal", 400, right: true),
                      cell("Deposit", 470, right: true), cell("Balance", 550, right: true)])
        document.add([cell("01 Nov 2024", 40), cell("Balance brought forward", 110), cell(money(opening), 550, right: true)])
        var balance = opening
        for (date, text, amount) in moves {
            balance += amount
            document.add([cell(date, 40), cell(text, 110),
                          cell(money(amount), amount < 0 ? 400 : 470, right: true), cell(money(balance), 550, right: true)])
        }
        document.blank()
    }

    private func twoAccounts() -> URL {
        var document = FixtureDocument()
        document.add([cell("Statement of account  Customer number 4412-889031", 40)])
        document.add([cell("Statement period 1 Nov 2024 to 30 Nov 2024", 40)])
        document.blank()
        account("HKD Current Account", number: "817-890692-838", opening: dec("42580.00"), moves: [
            ("03 Nov 2024", "Salary ACME LTD", dec("25000.00")),
            ("05 Nov 2024", "Transfer to account 817-890692-002", dec("-10000.00")),
            ("09 Nov 2024", "Octopus top up", dec("-500.00")),
        ], into: &document)
        document.newPage()
        // Every page repeats the customer number: another long number between
        // one account and the next.
        document.add([cell("Customer number 4412-889031", 40)])
        document.blank()
        account("USD Savings Account", number: "817-890692-002", opening: dec("150000.00"), moves: [
            ("05 Nov 2024", "Transfer from current account", dec("1282.05")),
            ("30 Nov 2024", "Interest", dec("312.40")),
        ], into: &document)
        return document.file("two-accounts")
    }

    func testEachAccountReconcilesOnItsOwn() throws {
        let accounts = try StatementReader.accounts(contentsOf: twoAccounts())
        XCTAssertEqual(accounts.map(\.account), ["HKD Current Account ••••2838", "USD Savings Account ••••2002"])
        XCTAssertEqual(accounts.map(\.reconciliation.status), [.reconciled, .reconciled])
        XCTAssertEqual(accounts.map(\.transactions.count), [3, 2],
                       "a transfer that names an account is a transaction, not a heading")
        XCTAssertEqual(accounts[0].openingBalance, dec("42580.00"))
        XCTAssertEqual(accounts[1].openingBalance, dec("150000.00"))
    }

    func testReadAsOneTheTwoAccountsDoNotAddUp() throws {
        // What 0.2.0 did, kept as the contrast: the accounts' balances meet.
        XCTAssertNotEqual(try StatementReader.read(contentsOf: twoAccounts()).reconciliation.status, .reconciled)
    }

    func testAStatementOfOneAccountIsUnchanged() throws {
        var document = FixtureDocument()
        document.add([cell("Statement period 1 Nov 2024 to 30 Nov 2024", 40)])
        account("Current Account", number: "12-34-56 87654321", opening: dec("100.00"), moves: [
            ("03 Nov 2024", "Coffee", dec("-3.50")),
        ], into: &document)
        let url = document.file("one-account")
        let accounts = try StatementReader.accounts(contentsOf: url)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertNil(accounts[0].account, "one account needs no label")
        XCTAssertEqual(accounts[0], try StatementReader.read(contentsOf: url))
    }

    func testAHeadingNeedsAnAccountWordANumberAndNoMoney() {
        func row(_ text: String) -> TextRow {
            TextRow(page: 1, words: text.split(separator: " ").enumerated().map {
                PositionedWord(text: String($1), frame: CGRect(x: CGFloat($0) * 40, y: 700, width: 35, height: 9))
            })
        }
        XCTAssertEqual(AccountSplitter.heading(row("USD Savings Account — 817-890692-002"))?.label, "USD Savings Account ••••2002")
        XCTAssertNil(AccountSplitter.heading(row("Transfer to account 817-890692-002 1,000.00")), "money on the row")
        XCTAssertNil(AccountSplitter.heading(row("Account 1234")), "too few digits")
        XCTAssertNil(AccountSplitter.heading(row("Reference 817-890692-002")), "no account word")
    }
}
