//
//  RealLayoutTests.swift
//  BankStatementTests
//
//  Created by David Sherlock on 2026.
//
//  Each failure found by running the parser on the bankstatemently
//  benchmark (MIT; fictional banks laid out like real ones in SG, US, NL,
//  HK and CA), rebuilt here from positioned words so the fix is pinned
//  without shipping anyone's PDF. The benchmark itself went from 1 of 5
//  statements reconciled to 4 of 5.
//

import CoreGraphics
import XCTest
@testable import BankStatement

final class RealLayoutTests: XCTestCase {

    /// A row of words at given x positions, each `space` points after the
    /// last when no x is given — so a heading's words sit a space apart and
    /// columns a gutter apart, as on a page.
    private func row(_ cells: [(String, CGFloat)], y: CGFloat = 700, space: CGFloat = 2) -> TextRow {
        var words: [PositionedWord] = []
        for (text, x) in cells {
            var cursor = x
            for word in text.split(separator: " ") {
                let width = CGFloat(word.count) * 5
                words.append(PositionedWord(text: String(word), frame: CGRect(x: cursor, y: y, width: width, height: 9)))
                cursor += width + space
            }
        }
        return TextRow(page: 1, words: words)
    }

    // MARK: - Headers

    func testAHeadingIsAllOfItsWords() throws {
        // bsb-002: "Merchant Name or" sat a fifth of a line from "Transaction
        // Description" and was taken for a column of its own.
        let columns = try XCTUnwrap(HeaderMatcher.columns(in: row([
            ("Post Date", 40), ("Trans Date", 100), ("Merchant Name or Transaction Description", 160), ("$ Amount", 450),
        ])))
        XCTAssertEqual(columns.map(\.kind), [.otherDate, .date, .description, .amount])
    }

    func testASecondDateHeadingIsNotTheDate() throws {
        // bsb-003: "Interest Date" beside "Date".
        let columns = try XCTUnwrap(HeaderMatcher.columns(in: row([
            ("Date", 40), ("Interest Date", 80), ("Counterparty", 150), ("Description", 230), ("Amount", 480),
        ])))
        XCTAssertEqual(columns.map(\.kind), [.date, .otherDate, .other, .description, .amount])
    }

    func testAFrenchHeaderWithNoDateColumn() throws {
        // bsb-005: the dates live at the start of "Détails".
        let columns = try XCTUnwrap(HeaderMatcher.columns(in: row([
            ("Détails", 40), ("Chèques et débits ($)", 260), ("Dépôts et crédits ($)", 370), ("Solde ($)", 480),
        ])))
        XCTAssertEqual(columns.map(\.kind), [.description, .moneyOut, .moneyIn, .balance])
    }

    func testDutchAndGermanHeadings() throws {
        XCTAssertEqual(try XCTUnwrap(HeaderMatcher.columns(in: row([
            ("Datum", 40), ("Omschrijving", 100), ("Af", 380), ("Bij", 420), ("Saldo", 480),
        ]))).map(\.kind), [.date, .description, .moneyOut, .moneyIn, .balance])
        XCTAssertEqual(try XCTUnwrap(HeaderMatcher.columns(in: row([
            ("Buchungstag", 40), ("Verwendungszweck", 120), ("Soll", 380), ("Haben", 420), ("Saldo", 480),
        ]))).map(\.kind), [.date, .description, .moneyOut, .moneyIn, .balance])
    }

    // MARK: - Dates

    func testMonthsInSixMoreLanguages() {
        XCTAssertEqual(DateParser.token("1 mei"), .named(day: 1, month: 5, year: nil))
        XCTAssertEqual(DateParser.token("02 janv. 25"), .named(day: 2, month: 1, year: 2025))
        XCTAssertEqual(DateParser.token("22. März 2025"), .named(day: 22, month: 3, year: 2025))
        XCTAssertEqual(DateParser.token("15 févr."), .named(day: 15, month: 2, year: nil))
        XCTAssertEqual(DateParser.token("3 dic 2025"), .named(day: 3, month: 12, year: 2025))
        XCTAssertEqual(DateParser.token("9 settembre"), .named(day: 9, month: 9, year: nil))
    }

    // MARK: - Balances

    func testBalancesNamedOnlyByTheirDates() throws {
        // bsb-003 printed no "opening" or "closing" anywhere.
        let rows = [row([("Balance as of 31.05.2025:", 40), ("14.674,96 €", 200)]),
                    row([("Balance as of 01.05.2025:", 40), ("15.320,00 €", 200)], y: 720)]
        let stated = BalanceFinder.stated(in: rows)
        XCTAssertEqual(stated.opening?.value, Decimal(string: "15320.00"))
        XCTAssertEqual(stated.closing?.value, Decimal(string: "14674.96"))
    }

    func testFrenchBalanceLabels() {
        XCTAssertEqual(RowVocabulary.balanceKind(of: "Solde d'ouverture 1 janvier 2025"), .opening)
        XCTAssertEqual(RowVocabulary.balanceKind(of: "Solde de fermeture 31 janvier 2025"), .closing)
    }

    // MARK: - Rows

    func testAZeroLineIsTheDescriptionRunningOn() {
        // bsb-002 printed 0.00 beside every continuation line; read as
        // transactions they doubled the count and still "reconciled".
        let header = row([("Date", 40), ("Description", 100), ("Amount", 450)], y: 720)
        let charge = row([("09/01", 40), ("UBER TRIP", 100), ("531.56", 450)], y: 705)
        let more = row([("Chevron station #0441", 100), ("0.00", 450)], y: 690)
        let entries = TableParser.parse([header, charge, more]).entries
        XCTAssertEqual(entries.count, 1)
        guard case .transaction(let only)? = entries.first else { return XCTFail("no transaction") }
        XCTAssertEqual(only.description, "UBER TRIP Chevron station #0441")
    }

    func testAHeadersSecondLineIsNotADescription() {
        // bsb-004: the same headings in Chinese, under the English ones.
        let header = row([("Date", 40), ("Transaction Details", 100), ("Withdrawal", 380), ("Balance", 470)], y: 720)
        let second = row([("日期", 40), ("進支詳情", 100), ("提取", 380), ("結餘", 470)], y: 708)
        let first = row([("1 Sep", 40), ("Faster payment", 100), ("153.01", 380), ("42,426.99", 470)], y: 694)
        let entries = TableParser.parse([header, second, first]).entries
        guard case .transaction(let only)? = entries.first else { return XCTFail("no transaction") }
        XCTAssertEqual(only.description, "Faster payment")
    }

    func testADateInsideTheDescriptionIsTheDate() {
        let header = row([("Détails", 40), ("Débits", 260), ("Crédits", 370), ("Solde", 480)], y: 720)
        let raw = row([("02 janv. 25 SKIP PLATS", 40), ("151,30", 260), ("10 598,70", 480)], y: 705)
        let line = TextRow(page: 1, words: RowBuilder.mergingMoney(raw.words))   // as the row builder hands it on
        let cells = CellAssigner.cells(of: line, columns: HeaderMatcher.columns(in: header)!)
        XCTAssertEqual(cells.date, "02 janv. 25")
        XCTAssertEqual(cells.description, ["SKIP", "PLATS"])
    }

    func testWidelySpacedFiguresAreStillJoined() {
        // bsb-005 set every space at 0.6 of a height — the old fixed limit.
        let wide = row([("Solde de fermeture = 11 133,60 $", 40)], space: 5.4)
        let words = RowBuilder.mergingMoney(wide.words).map(\.text)
        XCTAssertTrue(words.contains("11 133,60$"), "\(words)")
    }
}
