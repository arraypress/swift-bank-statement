# Swift Bank Statement

Read bank and credit card statement PDFs into transactions — and **prove the
reading**. Every statement prints its own check: each running balance, and the
closing balance, is the sum of what came before it. This library adds the
transactions up and compares them with every balance printed. A statement that
does not add up is reported as one, with the first row where it stopped
agreeing, instead of being handed back looking right.

PDFKit and Foundation only: on-device, no network, no keys, no dependencies.

## Why the check is the point

Pulling a table off a PDF is easy to get *nearly* right, and nearly right is
the dangerous kind of wrong: one dropped row in four hundred looks exactly like
a correct answer. Reading the file, you would not notice. The running balances
would.

- **Exact arithmetic.** Every figure is a `Decimal`, never a `Double`, and
  balances are compared with `==`. There is no tolerance — a tolerance is a
  place for a missing penny to hide.
- **Every printed balance is checked**: running balances (including the
  once-a-day kind most UK banks print), balances carried forward and brought
  forward between pages, and the closing balance in the summary.
- **A worked-out opening balance is not counted as proof.** With no opening
  balance printed, the first running balance becomes the baseline — and it
  agrees with itself by construction, so it is not counted as checked. A
  statement that prints only one balance comes back `unverifiable`, not
  `reconciled`.
- **Runs of statements are checked too**: `continuity(of:)` sorts them by
  period and reports each place where one closed on a figure the next did not
  open on — a missing month, or a misread.

## Usage

```swift
import BankStatement

let statement = try StatementReader.read(contentsOf: url)

switch statement.reconciliation.status {
case .reconciled:   print("\(statement.transactions.count) transactions, every balance agrees")
case .broken:       print(statement.reconciliation.firstBreak!)   // the row, the printed figure, the sum
case .unverifiable: print(statement.reconciliation.reason!)
}

for transaction in statement.transactions {
    print(transaction.date ?? "—", transaction.description, transaction.amount, transaction.balance ?? "")
}
```

- **`amount`** is from the account holder's side: money in is positive,
  money out negative, whatever the columns are called. A card purchase is
  negative even though it raised the balance the card company prints.
- **`balance`** is as printed, signed: an overdraft (`DR`) is negative.
- **`date`** is a calendar day, not an instant. It encodes as `2026-03-12`,
  or as `--03-12` when the statement never prints a year, rather than with an
  invented one.

What the caller knows can be passed in:

```swift
var options = StatementOptions()
options.dateOrder = .monthFirst    // 03/04 is the 4th of March
options.sense = .liability         // a card: the balance is money owed
options.year = 2026                // for yearless dates on a statement that prints no full date
let statement = try StatementReader.read(contentsOf: url, options: options)
```

Words from somewhere other than a PDF's text layer — an OCR pass — can enter
at the second stage, `StatementReader.read(pages:)`, as positioned words.

## What it understands

- **Header-driven columns.** The table is found by its header row, and each
  figure belongs to the heading it sits under. Headings are matched as phrases
  (`Paid out`, `Money in`, `Withdrawals and other debits`, `Payment type and
  details`…) in UK, Irish, US and card wordings, with currency marks and
  brackets ignored. A row is only a header when its headings are set apart
  like columns: a sentence in the small print that says "date", "amount" and
  "balance" has a space between every word.
- **Columns:** separate out/in columns, a single signed amount, debit/credit,
  with or without a running balance; a card's posting date beside its
  transaction date (dropped).
- **Figures:** `1,234.56`, `1.234,56`, `1 234,56`, `1'234.56`, minus either
  side, brackets, currency marks, `CR`/`DR` attached or set apart.
- **Dates:** `12/03/2026`, `12.03.26`, `12 Mar 2026`, `12-Mar`, `Mar 12, 2026`,
  `2026-03-12`. Day-first or month-first is decided from **all** the dates at
  once: a number over twelve settles it, and failing that, the reading that
  keeps the dates in order. When nothing on the page decides it, the result
  carries a warning saying which was assumed. Yearless dates are placed in the
  year that puts them before the end of the statement period — "28 Dec" on a
  statement ending in January is the previous December.
- **Wrapped descriptions**, whether the statement prints the figure on a
  transaction's first line or its last — decided once per statement, from how
  its dated rows are laid out.
- **Dates printed once per day**: a row with no date takes the one above it.
- **Multi-page tables**, with or without a repeated header, joined at their
  carried-forward rows; footers and small print below a table are left out.
- **Which way the balance moves**: whichever reading makes the balances agree,
  and a card's wording ("credit limit", "minimum payment") when both do.

## Measured

All on synthetic statements drawn as real PDFs with CoreText and read back
through PDFKit, so every test exercises the same text layer a bank's file does.
Figures are invented; balances are computed, so every fixture is consistent
unless a test breaks it on purpose.

| | |
|---|---|
| Hand-built layouts — UK out/in/balance, US signed amount, debit/credit with no balance column, comma decimals, credit card, figures on the last line across a new year, three-page carried forward | every transaction, date, description and figure exact; all reconciled |
| **100 generated statements** — 3–60 random transactions, 1–3 line descriptions, random page lengths and overdrafts, fixed seed | **100 / 100** read exactly and reconciled |
| **50 generated misprints** — one figure printed a penny out | **50 / 50** reported `broken` |
| A figure altered; a row dropped | broken at exactly that row, naming it |
| 400 transactions over 16 pages | 2.2 s (debug build) |

**Real bank statements are UNTESTED.** Everything above is synthetic. Until
this has been run on real statements from real banks, treat a new bank's
layout as unproven — the reconciliation is what makes that safe to try,
because a misread shows up as `broken` rather than as wrong numbers.

**A probe that changed the design.** PDFKit's `characterBounds(at:)` drifts one
character per line break away from `PDFPage.string` — on the first probe, index
42 returned the box of character 43, so every word after the first line would
have been placed under its neighbour. `selection(for:)` on a one-character
range agrees with the string, and that is what this reads with.
`selectionsByLine()` was ruled out the same way: it split one printed row in
two at the gap before the money columns.

**A test that changed a regex.** Swift's `\b` follows Unicode's word rules,
which read `234,56` as a single word — so the rule that rejoins `1 234,56`
never fired until a test asked for it.

## What it does not do

- **Scanned statements.** A PDF with no text layer is refused
  (`noTextLayer`). OCR'd figures are exactly where a misread 8 for 3 hides,
  and supporting them is a separate decision — the `read(pages:)` seam is
  where it would enter, and the reconciliation would still apply.
- **Currencies without minor units.** A figure must have two decimal places to
  count as money — the one rule that keeps "CARD 4417" and "STORE 2231" out of
  the amount columns. Yen statements are the cost.
- **English headings only**, and headings on one line: a header that stacks
  "Money" above "out" is not recognised.
- **A card statement with a "Payments" column** reads it as money out, which on
  a card it is not; the reconciliation breaks rather than passing.
- **Rotated pages.**
- **A row starting with the word "Total"** is skipped as a totals row — a
  merchant called TOTAL UK on a row with no date would be too, and the next
  balance would report it missing.

## Requirements

macOS 13+ / iOS 16+, Swift 6. The floor is Swift's `Regex`, which the figure
and date parsers are written in.

## License

MIT — see LICENSE.
