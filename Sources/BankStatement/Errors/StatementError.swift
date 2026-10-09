//
//  StatementError.swift
//  BankStatement
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why a statement could not be read.
public enum StatementError: LocalizedError, Equatable {

    /// The file is missing, or is not a PDF.
    case unreadableFile(URL)

    /// The PDF is password-protected.
    case locked(URL)

    /// The PDF has no text to read — a scan, or a photograph. Statements read
    /// by OCR are not supported: the figures are the whole point, and a
    /// recogniser that reads 8 for 3 produces a statement that looks right.
    case noTextLayer(URL?)

    /// No page has a row that reads as a transaction table's header.
    case noTransactionTable(URL?)

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let url):
            return "\(url.lastPathComponent) could not be opened as a PDF."
        case .locked(let url):
            return "\(url.lastPathComponent) is password-protected."
        case .noTextLayer(let url):
            return "\(url?.lastPathComponent ?? "The statement") has no text layer — it is a scan or an image."
        case .noTransactionTable(let url):
            return "No transaction table was found in \(url?.lastPathComponent ?? "the statement")."
        }
    }
}
