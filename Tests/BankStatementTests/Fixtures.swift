//
//  Fixtures.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  Statements drawn as real PDFs with CoreText, so every test goes through
//  PDFKit's text layer exactly as a bank's file would — the layer that, when
//  probed, put every character after a line break under its neighbour.
//
//  The figures are invented. Every balance is computed from the transactions
//  here, so a fixture is consistent by construction, and a test that wants a
//  broken one breaks it on purpose.
//

import CoreGraphics
import CoreText
import Foundation

/// One piece of text on a fixture page.
struct FixtureCell {
    let text: String
    /// The left edge, or the right edge when `right` is true.
    let x: CGFloat
    let right: Bool
}

/// A statement PDF, described row by row.
struct FixtureDocument {
    /// Pages of rows of cells. An empty row is a blank line.
    var pages: [[[FixtureCell]]] = [[]]
    var fontSize: CGFloat = 9
    var lineStep: CGFloat = 13
    var top: CGFloat = 790
    /// A "Page n of m" line at the foot of every page.
    var footers = true

    mutating func add(_ cells: [FixtureCell]) { pages[pages.count - 1].append(cells) }
    mutating func blank() { add([]) }
    mutating func newPage() { pages.append([]) }

    /// Writes the PDF.
    func write(to url: URL) {
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let context = CGContext(url as CFURL, mediaBox: &box, nil)!
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)

        func draw(_ cell: FixtureCell, y: CGFloat) {
            let attributed = NSAttributedString(string: cell.text,
                                                attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
            let line = CTLineCreateWithAttributedString(attributed)
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            context.textPosition = CGPoint(x: cell.right ? cell.x - CGFloat(width) : cell.x, y: y)
            CTLineDraw(line, context)
        }

        for (number, rows) in pages.enumerated() {
            context.beginPDFPage(nil)
            for (index, row) in rows.enumerated() {
                let y = top - CGFloat(index) * lineStep
                for cell in row { draw(cell, y: y) }
            }
            if footers {
                draw(FixtureCell(text: "Page \(number + 1) of \(pages.count)", x: 40, right: false), y: 30)
            }
            context.endPDFPage()
        }
        context.closePDF()
    }

    /// Writes the PDF to a new temporary file.
    func file(_ name: String = "statement") -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bank-statement-tests-\(UUID().uuidString)")
            .appendingPathComponent("\(name).pdf")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        write(to: url)
        return url
    }
}

/// A PDF with a picture and no text — what a scan is.
func imageOnlyPDF() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("bank-statement-tests-\(UUID().uuidString).pdf")
    var box = CGRect(x: 0, y: 0, width: 595, height: 842)
    let context = CGContext(url as CFURL, mediaBox: &box, nil)!
    context.beginPDFPage(nil)
    context.setFillColor(gray: 0.2, alpha: 1)
    for row in 0..<40 { context.fill(CGRect(x: 40, y: 780 - row * 14, width: 400, height: 6)) }
    context.endPDFPage()
    context.closePDF()
    return url
}

// MARK: - Figures

/// Formats a figure the way a statement prints it.
func money(_ value: Decimal, european: Bool = false) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: european ? "de_DE" : "en_GB")
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: abs(value) as NSDecimalNumber)!
}

/// A balance the way a UK statement prints it: an overdraft marked DR.
func balanceText(_ value: Decimal) -> String { money(value) + (value < 0 ? " DR" : "") }

/// Decimal from a literal, exactly.
func dec(_ text: String) -> Decimal { Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))! }

/// A transaction a fixture prints.
struct FixtureTransaction {
    var date: String
    var lines: [String]
    var amount: Decimal
}

// MARK: - The statements

/// A UK current account: Date | Payment type and details | Paid out | Paid in
/// | Balance. Dates printed on the first row of each day only, a balance on
/// the last row of each day only, descriptions that wrap below the figure,
/// two pages joined by carried and brought forward rows, and a summary box.
func ukStatement(_ transactions: [FixtureTransaction], opening: Decimal,
                 perPage: Int = 100, alterClosing: Decimal? = nil) -> FixtureDocument {
    var doc = FixtureDocument()
    let closing = transactions.reduce(opening) { $0 + $1.amount }

    doc.add([FixtureCell(text: "Current Account Statement", x: 40, right: false)])
    doc.add([FixtureCell(text: "Statement period 1 March to 31 March 2026", x: 40, right: false)])
    doc.blank()
    doc.add([FixtureCell(text: "Opening balance", x: 40, right: false), FixtureCell(text: balanceText(opening), x: 260, right: true)])
    doc.add([FixtureCell(text: "Money in", x: 40, right: false),
             FixtureCell(text: money(transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }), x: 260, right: true)])
    doc.add([FixtureCell(text: "Money out", x: 40, right: false),
             FixtureCell(text: money(-transactions.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount }), x: 260, right: true)])
    doc.add([FixtureCell(text: "Closing balance", x: 40, right: false), FixtureCell(text: balanceText(alterClosing ?? closing), x: 260, right: true)])
    doc.blank()

    func header() {
        doc.add([FixtureCell(text: "Date", x: 40, right: false),
                 FixtureCell(text: "Payment type and details", x: 95, right: false),
                 FixtureCell(text: "Paid out", x: 390, right: true),
                 FixtureCell(text: "Paid in", x: 460, right: true),
                 FixtureCell(text: "Balance", x: 540, right: true)])
    }
    header()
    doc.add([FixtureCell(text: "01 Mar", x: 40, right: false),
             FixtureCell(text: "BALANCE BROUGHT FORWARD", x: 95, right: false),
             FixtureCell(text: balanceText(opening), x: 540, right: true)])

    var running = opening
    var lastDate = ""
    var onPage = 0
    for (index, transaction) in transactions.enumerated() {
        // A page holds 55 rows above its footer; a transaction never splits.
        let full = doc.pages[doc.pages.count - 1].count + transaction.lines.count + 1 > 55
        if index > 0, onPage == perPage || full {
            onPage = 0
            doc.add([FixtureCell(text: "BALANCE CARRIED FORWARD", x: 95, right: false),
                     FixtureCell(text: balanceText(running), x: 540, right: true)])
            doc.newPage()
            header()
            doc.add([FixtureCell(text: "BALANCE BROUGHT FORWARD", x: 95, right: false),
                     FixtureCell(text: balanceText(running), x: 540, right: true)])
            lastDate = ""
        }
        running += transaction.amount
        onPage += 1
        // The last of its day, or the last before a page break — a balance
        // is always printed before a carried-forward row.
        let nextFull = index + 1 < transactions.count
            && doc.pages[doc.pages.count - 1].count + transaction.lines.count + transactions[index + 1].lines.count + 1 > 55
        let lastOfDay = index == transactions.count - 1 || transactions[index + 1].date != transaction.date
            || onPage == perPage || nextFull
        var cells = [FixtureCell(text: transaction.lines[0], x: 95, right: false),
                     FixtureCell(text: money(transaction.amount), x: transaction.amount < 0 ? 390 : 460, right: true)]
        if transaction.date != lastDate { cells.insert(FixtureCell(text: transaction.date, x: 40, right: false), at: 0) }
        if lastOfDay { cells.append(FixtureCell(text: balanceText(running), x: 540, right: true)) }
        doc.add(cells)
        for line in transaction.lines.dropFirst() { doc.add([FixtureCell(text: line, x: 95, right: false)]) }
        lastDate = transaction.date
    }
    doc.add([FixtureCell(text: "31 Mar", x: 40, right: false),
             FixtureCell(text: "BALANCE CARRIED FORWARD", x: 95, right: false),
             FixtureCell(text: balanceText(running), x: 540, right: true)])
    doc.blank(); doc.blank(); doc.blank(); doc.blank(); doc.blank()
    doc.add([FixtureCell(text: "Fixture Bank plc is authorised by the Prudential Regulation Authority. Total 0.00", x: 40, right: false)])
    return doc
}

/// The UK fixture's transactions.
let ukTransactions: [FixtureTransaction] = [
    FixtureTransaction(date: "02 Mar", lines: ["CARD PAYMENT TO TESCO STORES 2231", "ON 01 MAR"], amount: dec("-12.50")),
    FixtureTransaction(date: "02 Mar", lines: ["DIRECT DEBIT EE LIMITED"], amount: dec("-30.00")),
    FixtureTransaction(date: "03 Mar", lines: ["BANK GIRO CREDIT ACME LTD SALARY"], amount: dec("2000.00")),
    FixtureTransaction(date: "05 Mar", lines: ["STANDING ORDER RENT", "REF FLAT 2"], amount: dec("-950.00")),
    FixtureTransaction(date: "05 Mar", lines: ["CARD PAYMENT TO PRET A MANGER"], amount: dec("-4.35")),
    FixtureTransaction(date: "11 Mar", lines: ["FASTER PAYMENT FROM J SMITH", "DINNER SPLIT"], amount: dec("23.10")),
    FixtureTransaction(date: "14 Mar", lines: ["CASH WITHDRAWAL LLOYDS 14MAR"], amount: dec("-60.00")),
    FixtureTransaction(date: "18 Mar", lines: ["DIRECT DEBIT COUNCIL TAX"], amount: dec("-145.00")),
    FixtureTransaction(date: "18 Mar", lines: ["CARD PAYMENT TO TFL TRAVEL CH"], amount: dec("-7.80")),
    FixtureTransaction(date: "22 Mar", lines: ["INTEREST PAID"], amount: dec("0.42")),
    FixtureTransaction(date: "27 Mar", lines: ["CARD PAYMENT TO AMAZON.CO.UK", "AMZN MKTP"], amount: dec("-1234.99")),
    FixtureTransaction(date: "30 Mar", lines: ["TRANSFER TO SAVINGS"], amount: dec("-100.00")),
]

// MARK: - Any layout

/// A column of a fixture table: its heading and where it sits.
struct FixtureColumn {
    let title: String
    let x: CGFloat
    let right: Bool
}

/// A one-page statement: lines of text above the table, the table, lines
/// below it. Each table row gives one cell per column, nil for empty.
func tableStatement(above: [String], columns: [FixtureColumn], rows: [[String?]],
                    below: [String] = []) -> FixtureDocument {
    var doc = FixtureDocument()
    for line in above { doc.add(line.isEmpty ? [] : [FixtureCell(text: line, x: 40, right: false)]) }
    doc.add(columns.map { FixtureCell(text: $0.title, x: $0.x, right: $0.right) })
    for row in rows {
        doc.add(zip(columns, row).compactMap { column, text in
            text.map { FixtureCell(text: $0, x: column.x, right: column.right) }
        })
    }
    doc.blank(); doc.blank(); doc.blank(); doc.blank(); doc.blank()
    for line in below { doc.add([FixtureCell(text: line, x: 40, right: false)]) }
    return doc
}

/// A US checking account: Date | Description | Amount | Balance, month-first
/// dates without a year, signed amounts, dollar signs, and the balances in a
/// summary above the table.
func usStatement(alter: (index: Int, amount: String)? = nil, drop: Int? = nil) -> (FixtureDocument, [Decimal]) {
    let opening = dec("1000.00")
    var entries: [(String, String, Decimal)] = [
        ("02/16", "POS PURCHASE WHOLE FOODS #123", dec("-45.20")),
        ("02/18", "PAYROLL DIRECT DEP ACME INC", dec("1500.00")),
        ("02/23", "CHECK 1043", dec("-250.00")),
        ("03/02", "ATM WITHDRAWAL 0042 MAIN ST", dec("-60.00")),
        ("03/09", "ZELLE FROM J SMITH", dec("35.75")),
        ("03/13", "MONTHLY SERVICE FEE", dec("-12.00")),
    ]
    let closing = entries.reduce(opening) { $0 + $1.2 }
    var running = opening
    var rows: [[String?]] = []
    for (index, entry) in entries.enumerated() {
        running += entry.2
        var printed = (entry.2 < 0 ? "-" : "") + money(entry.2)
        if let alter, alter.index == index { printed = alter.amount }
        if index != drop { rows.append([entry.0, entry.1, printed, "$" + money(running)]) }
    }
    if let drop { entries.remove(at: drop) }
    let doc = tableStatement(
        above: ["Everyday Checking", "Statement period: 02/15/2026 to 03/14/2026", "",
                "Beginning balance on 02/15 $" + money(opening), "Ending balance on 03/14 $" + money(closing), ""],
        columns: [FixtureColumn(title: "Date", x: 40, right: false),
                  FixtureColumn(title: "Description", x: 90, right: false),
                  FixtureColumn(title: "Amount", x: 430, right: true),
                  FixtureColumn(title: "Balance", x: 540, right: true)],
        rows: rows)
    return (doc, entries.map(\.2))
}

/// An account with Debit and Credit columns and no running balance at all:
/// the summary's opening and closing are the only proof.
func debitCreditStatement(closing: Decimal? = nil, totals: Bool = false) -> (FixtureDocument, [Decimal]) {
    let amounts = [dec("-89.99"), dec("-15.00"), dec("420.00"), dec("-3.50"), dec("-1200.00")]
    let opening = dec("1500.00")
    let rows: [[String?]] = [
        ["04/02/2026", "ONLINE ORDER 55821", "89.99", nil],
        ["11/02/2026", "STREAMING SUBSCRIPTION", "15.00", nil],
        ["13/02/2026", "REFUND RECEIVED", nil, "420.00"],
        ["20/02/2026", "COFFEE", "3.50", nil],
        ["26/02/2026", "MORTGAGE", "1,200.00", nil],
    ] + (totals ? [[nil, "Totals", "1,308.49", "420.00"]] : [])
    let doc = tableStatement(
        above: ["Account statement", "Date of statement 28/02/2026", "",
                "Opening balance 1,500.00", "Closing balance " + money(closing ?? amounts.reduce(opening, +)), ""],
        columns: [FixtureColumn(title: "Date", x: 40, right: false),
                  FixtureColumn(title: "Details", x: 110, right: false),
                  FixtureColumn(title: "Debit", x: 450, right: true),
                  FixtureColumn(title: "Credit", x: 540, right: true)],
        rows: rows)
    return (doc, amounts)
}

/// A euro account printed with comma decimals and dotted dates.
func europeanStatement() -> (FixtureDocument, [Decimal]) {
    let amounts = [dec("-1234.56"), dec("2500.00"), dec("-19.99"), dec("-0.50")]
    var running = dec("2000.00")
    var rows: [[String?]] = []
    let dates = ["03.02.2026", "15.02.2026", "16.02.2026", "28.02.2026"]
    let descriptions = ["Miete Februar", "Gehalt ACME GmbH", "Online Shop", "Kontoführung"]
    for index in amounts.indices {
        running += amounts[index]
        rows.append([dates[index], descriptions[index],
                     (amounts[index] < 0 ? "-" : "") + money(amounts[index], european: true),
                     money(running, european: true)])
    }
    let doc = tableStatement(
        above: ["Kontoauszug / Statement", "Opening balance 2.000,00 EUR", ""],
        columns: [FixtureColumn(title: "Date", x: 40, right: false),
                  FixtureColumn(title: "Description", x: 110, right: false),
                  FixtureColumn(title: "Amount", x: 450, right: true),
                  FixtureColumn(title: "Balance", x: 540, right: true)],
        rows: rows)
    return (doc, amounts)
}

/// A credit card: two date columns, one amount column, purchases unsigned
/// and the payment marked CR as a separate word; the whole sum on one line.
func cardStatement() -> (FixtureDocument, [Decimal]) {
    // From the holder's side: purchases are money out.
    let amounts = [dec("512.30"), dec("-64.99"), dec("-8.40"), dec("-129.00")]
    let doc = tableStatement(
        above: ["Platinum Card Statement", "Statement date 21 April 2026", "Credit limit £5,000.00", "",
                "Previous balance £512.30 Payments £512.30 New balance £202.39", ""],
        columns: [FixtureColumn(title: "Trans date", x: 40, right: false),
                  FixtureColumn(title: "Post date", x: 100, right: false),
                  FixtureColumn(title: "Description", x: 160, right: false),
                  FixtureColumn(title: "Amount", x: 540, right: true)],
        rows: [["25 Mar", "26 Mar", "PAYMENT RECEIVED - THANK YOU", "512.30 CR"],
               ["28 Mar", "30 Mar", "AMAZON MARKETPLACE", "64.99"],
               ["02 Apr", "03 Apr", "COSTA COFFEE", "8.40"],
               ["15 Apr", "16 Apr", "BRITISH AIRWAYS", "129.00"]])
    return (doc, amounts)
}

/// A statement that prints the date on a transaction's first line and its
/// figure on the last, with the period crossing the new year.
func amountLastStatement() -> (FixtureDocument, [Decimal]) {
    let amounts = [dec("-40.00"), dec("-15.25"), dec("300.00")]
    var doc = FixtureDocument()
    let cells: [[FixtureCell]] = [
        [FixtureCell(text: "Statement period 15 December 2025 to 14 January 2026", x: 40, right: false)],
        [FixtureCell(text: "Previous balance 100.00", x: 40, right: false)],
        [],
        [FixtureCell(text: "Date", x: 40, right: false), FixtureCell(text: "Description", x: 100, right: false),
         FixtureCell(text: "Money out", x: 450, right: true), FixtureCell(text: "Money in", x: 540, right: true)],
        [FixtureCell(text: "20 Dec", x: 40, right: false), FixtureCell(text: "CARD PURCHASE", x: 100, right: false)],
        [FixtureCell(text: "HAMLEYS LONDON", x: 100, right: false), FixtureCell(text: "40.00", x: 450, right: true)],
        [FixtureCell(text: "02 Jan", x: 40, right: false), FixtureCell(text: "DIRECT DEBIT", x: 100, right: false)],
        [FixtureCell(text: "GYM MEMBERSHIP", x: 100, right: false), FixtureCell(text: "15.25", x: 450, right: true)],
        [FixtureCell(text: "09 Jan", x: 40, right: false), FixtureCell(text: "TRANSFER IN", x: 100, right: false)],
        [FixtureCell(text: "FROM SAVINGS", x: 100, right: false), FixtureCell(text: "300.00", x: 540, right: true)],
        [], [], [], [], [],
        [FixtureCell(text: "New balance 344.75", x: 40, right: false)],
    ]
    for row in cells { doc.add(row) }
    return (doc, amounts)
}
