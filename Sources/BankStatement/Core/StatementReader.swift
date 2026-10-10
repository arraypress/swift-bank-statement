//
//  StatementReader.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//
//  The front door. A PDF's text layer becomes pages of positioned words
//  (`PageText`), the words become a statement (`StatementParser`), and the
//  statement is checked against itself (`Reconciler`). Each stage is
//  reachable on its own, so words from somewhere other than a PDF — an OCR
//  pass — can enter at the second.
//

import Foundation
import PDFKit

/// Reads bank and card statements, and proves the reading.
///
/// ```swift
/// let statement = try StatementReader.read(contentsOf: url)
/// statement.reconciliation.status        // .reconciled
/// statement.transactions.count           // 42
/// statement.transactions[0].amount       // -12.50: money out is negative
///
/// // A year of statements, checked as a run.
/// let year = try urls.map { try StatementReader.read(contentsOf: $0) }
/// StatementReader.continuity(of: year)   // [] when each opens where the last closed
/// ```
public enum StatementReader {

    /// Reads a statement PDF.
    ///
    /// - Parameters:
    ///   - url: The PDF.
    ///   - options: What the caller knows that the statement might not say.
    /// - Returns: The statement, with its reconciliation.
    /// - Throws: Any ``StatementError``.
    public static func read(contentsOf url: URL,
                            options: StatementOptions = StatementOptions()) throws -> Statement {
        guard let document = PDFDocument(url: url) else { throw StatementError.unreadableFile(url) }
        guard !document.isLocked else { throw StatementError.locked(url) }
        return try read(document, source: url, options: options)
    }

    /// Reads a statement already open.
    ///
    /// - Parameters:
    ///   - document: The PDF.
    ///   - source: Where it came from, for the result.
    ///   - options: What the caller knows.
    /// - Returns: The statement.
    /// - Throws: Any ``StatementError``.
    public static func read(_ document: PDFDocument, source: URL? = nil,
                            options: StatementOptions = StatementOptions()) throws -> Statement {
        try read(pages: PageText.pages(of: document), source: source ?? document.documentURL, options: options)
    }

    /// Reads a statement from words already placed on pages — from an OCR
    /// pass, or built by hand.
    ///
    /// - Parameters:
    ///   - pages: Every page's words, in PDF points, origin bottom left.
    ///   - source: Where they came from.
    ///   - options: What the caller knows.
    /// - Returns: The statement.
    /// - Throws: Any ``StatementError``.
    public static func read(pages: [StatementPage], source: URL? = nil,
                            options: StatementOptions = StatementOptions()) throws -> Statement {
        try StatementParser.parse(pages, source: source, options: options)
    }

    /// Reads every account a statement PDF holds, each reconciled on its own.
    ///
    /// A bank that keeps several accounts together prints them in one
    /// statement under separate headings; read as one table, the second
    /// account's balances were checked against the first's. A statement of
    /// one account comes back as one element, read exactly as
    /// ``read(contentsOf:options:)`` reads it.
    ///
    /// - Parameters:
    ///   - url: The PDF.
    ///   - options: What the caller knows.
    /// - Returns: One statement per account, labelled when there are several.
    /// - Throws: Any ``StatementError``.
    public static func accounts(contentsOf url: URL,
                                options: StatementOptions = StatementOptions()) throws -> [Statement] {
        guard let document = PDFDocument(url: url) else { throw StatementError.unreadableFile(url) }
        guard !document.isLocked else { throw StatementError.locked(url) }
        return try accounts(pages: PageText.pages(of: document), source: url, options: options)
    }

    /// Reads every account from words already placed on pages.
    public static func accounts(pages: [StatementPage], source: URL? = nil,
                                options: StatementOptions = StatementOptions()) throws -> [Statement] {
        try StatementParser.parseAccounts(pages, source: source, options: options)
    }

    /// The words of every page of a PDF, with their positions.
    ///
    /// - Parameter document: The PDF.
    /// - Returns: One entry per page; an image-only page has no words.
    public static func pages(of document: PDFDocument) -> [StatementPage] {
        PageText.pages(of: document)
    }

    /// Where a run of statements fails to join up.
    ///
    /// Sorted by period first, so the order they are passed in does not
    /// matter. A statement with no opening or closing balance is skipped
    /// over rather than reported.
    ///
    /// - Parameter statements: The statements.
    /// - Returns: Every pair where one closed on a figure the next did not
    ///   open on.
    public static func continuity(of statements: [Statement]) -> [ContinuityBreak] {
        Continuity.breaks(in: statements)
    }
}
