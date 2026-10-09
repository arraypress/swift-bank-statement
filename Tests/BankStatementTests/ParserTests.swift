//
//  ParserTests.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The pieces: figures, dates, headings, and the files that are refused.
//

import XCTest
@testable import BankStatement

final class AmountTests: XCTestCase {

    func testEveryPrintingOfOneFigure() {
        for text in ["1,234.56", "1.234,56", "1 234,56", "1'234.56", "£1,234.56", "1,234.56 GBP",
                     "€1.234,56", "1234.56", "+1,234.56"] {
            XCTAssertEqual(text.statementAmount, dec("1234.56"), text)
        }
    }

    func testNegativePrintings() {
        for text in ["-12.50", "12.50-", "(12.50)", "−12.50", "-£12.50", "£-12.50", "($12.50)"] {
            XCTAssertEqual(text.statementAmount, dec("-12.50"), text)
        }
    }

    func testDirectionMarkers() {
        XCTAssertEqual(AmountParser.parse("12.50CR"), PrintedAmount(value: dec("12.50"), marker: .credit))
        XCTAssertEqual(AmountParser.parse("12.50 DR"), PrintedAmount(value: dec("12.50"), marker: .debit))
    }

    func testThingsThatAreNotMoney() {
        // No pence, a percentage, a card number, an ambiguous grouping.
        for text in ["2231", "12", "2.5%", "4417", "1,234,56", "12.5", "12.505", "-", "CR", "03/04"] {
            XCTAssertNil(text.statementAmount, text)
        }
    }

    func testDecimalsAreExact() {
        // The reason for Decimal: 0.1 + 0.2 summed as Double is not 0.3.
        let sum = ["0.10", "0.20"].compactMap(\.statementAmount).reduce(0, +)
        XCTAssertEqual(sum, dec("0.30"))
    }
}

final class DateTests: XCTestCase {

    func testPrintedForms() {
        XCTAssertEqual("12/03/2026".statementDate()?.description, "2026-03-12")
        XCTAssertEqual("12/03/26".statementDate()?.description, "2026-03-12")
        XCTAssertEqual("12.03.2026".statementDate()?.description, "2026-03-12")
        XCTAssertEqual("12 Mar 2026".statementDate()?.description, "2026-03-12")
        XCTAssertEqual("12-Mar-26".statementDate()?.description, "2026-03-12")
        XCTAssertEqual("12th March".statementDate()?.description, "--03-12")
        XCTAssertEqual("Mar 12, 2026".statementDate()?.description, "2026-03-12")
        XCTAssertEqual("2026-03-12".statementDate()?.description, "2026-03-12")
        XCTAssertEqual("03/12/2026".statementDate(order: .monthFirst)?.description, "2026-03-12")
        XCTAssertNil("31/04/2026".statementDate())
        XCTAssertNil("29/02/2026".statementDate())
        XCTAssertNotNil("29/02/2028".statementDate())
        XCTAssertNil("March 2026".statementDate())
    }

    func testOrderIsDecidedByADayOverTwelve() {
        let tokens = ["03/04", "13/04"].compactMap(DateParser.token)
        XCTAssertEqual(DateParser.decideOrder(tokens, fallback: .monthFirst).order, .dayFirst)
        let us = ["04/03", "04/13"].compactMap(DateParser.token)
        XCTAssertEqual(DateParser.decideOrder(us, fallback: .dayFirst).order, .monthFirst)
    }

    func testOrderIsDecidedByWhichReadingStaysInOrder() {
        // Day first: 2 Mar, 1 Apr, 5 Apr — in order. Month first: 3 Feb,
        // 4 Jan, 4 May — not.
        let tokens = ["02/03", "01/04", "05/04"].compactMap(DateParser.token)
        let decision = DateParser.decideOrder(tokens, fallback: .monthFirst)
        XCTAssertEqual(decision.order, .dayFirst)
        XCTAssertTrue(decision.decided)
    }

    func testUndecidableOrderIsReportedAsAGuess() {
        let tokens = ["01/02", "01/03"].compactMap(DateParser.token)
        let decision = DateParser.decideOrder(tokens, fallback: .dayFirst)
        XCTAssertFalse(decision.decided)
    }

    func testYearlessDatesArePlacedBeforeThePeriodEnd() {
        let end = StatementDate(year: 2026, month: 1, day: 14)
        XCTAssertEqual(DateParser.placing(StatementDate(year: nil, month: 12, day: 28), before: end).year, 2025)
        XCTAssertEqual(DateParser.placing(StatementDate(year: nil, month: 1, day: 14), before: end).year, 2026)
        XCTAssertEqual(DateParser.placing(StatementDate(year: nil, month: 1, day: 15), before: end).year, 2025)
    }
}

final class LayoutPieceTests: XCTestCase {

    func row(_ words: [(String, CGFloat)], y: CGFloat = 700) -> TextRow {
        TextRow(page: 1, words: words.map { text, x in
            PositionedWord(text: text, frame: CGRect(x: x, y: y, width: CGFloat(text.count) * 5, height: 9))
        })
    }

    func testAHeaderRowIsFoundWithTightColumns() throws {
        let columns = try XCTUnwrap(HeaderMatcher.columns(in: row([
            ("Date", 40), ("Description", 100), ("Paid", 330), ("out", 352), ("Paid", 380), ("in", 402), ("Balance", 450),
        ])))
        XCTAssertEqual(columns.map(\.kind), [.date, .description, .moneyOut, .moneyIn, .balance])
    }

    func testASentenceInTheSmallPrintIsNotAHeader() {
        // Every word a space apart: prose, even though it names a date, an
        // amount and a balance.
        let words = "the date and amount of each payment reduce your balance".split(separator: " ")
        var x: CGFloat = 40
        let prose = row(words.map { word in defer { x += CGFloat(word.count) * 5 + 2.5 }; return (String(word), x) })
        XCTAssertNil(HeaderMatcher.columns(in: prose))
    }

    func testHeadingsAreNormalised() {
        XCTAssertEqual(HeaderMatcher.kind(of: "Paid out (£)"), .moneyOut)
        XCTAssertEqual(HeaderMatcher.kind(of: "Amount GBP"), .amount)
        XCTAssertEqual(HeaderMatcher.kind(of: "Withdrawals ($)"), .moneyOut)
        XCTAssertNil(HeaderMatcher.kind(of: "Reference"))
    }

    func testSplitFiguresAreRejoined() {
        let merged = RowBuilder.mergingMoney(row([("1", 400), ("234,56", 407), ("12.50", 460), ("CR", 487), ("£", 500), ("3.00", 506)]).words)
        XCTAssertEqual(merged.map(\.text), ["1 234,56", "12.50CR", "£3.00"])
    }

    func testADescriptionNumberIsNotJoinedToAFigure() {
        let merged = RowBuilder.mergingMoney(row([("STORE", 100), ("2231", 130), ("12.50", 300)]).words)
        XCTAssertEqual(merged.map(\.text), ["STORE", "2231", "12.50"])
    }
}

final class RefusalTests: XCTestCase {

    func testAScanHasNoTextLayer() {
        let url = imageOnlyPDF()
        XCTAssertThrowsError(try StatementReader.read(contentsOf: url)) { error in
            XCTAssertEqual(error as? StatementError, .noTextLayer(url))
        }
    }

    func testALetterIsNotAStatement() {
        let doc = tableStatement(above: ["Dear customer,", "Your new card is on its way."], columns: [], rows: [])
        let url = doc.file()
        XCTAssertThrowsError(try StatementReader.read(contentsOf: url)) { error in
            XCTAssertEqual(error as? StatementError, .noTransactionTable(url))
        }
    }

    func testAFileThatIsNotAPDF() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-statement-\(UUID()).pdf")
        try Data("hello".utf8).write(to: url)
        XCTAssertThrowsError(try StatementReader.read(contentsOf: url)) { error in
            XCTAssertEqual(error as? StatementError, .unreadableFile(url))
        }
    }
}

final class VocabularyTests: XCTestCase {

    func testTotalsAreRowsThatStartWithTheWord() {
        XCTAssertTrue(RowVocabulary.isTotal("Totals"))
        XCTAssertTrue(RowVocabulary.isTotal("Total payments in"))
        XCTAssertTrue(RowVocabulary.isTotal("TOTAL: "))
        XCTAssertFalse(RowVocabulary.isTotal("CARD PAYMENT TO TOTAL UK"))
        XCTAssertFalse(RowVocabulary.isTotal("TOTALENERGIES"))
    }

    func testBalanceLabels() {
        XCTAssertEqual(RowVocabulary.balanceKind(of: "BALANCE BROUGHT FORWARD"), .opening)
        XCTAssertEqual(RowVocabulary.balanceKind(of: "Balance carried forward"), .closing)
        XCTAssertNil(RowVocabulary.balanceKind(of: "BALANCE TRANSFER FEE"))
    }
}
