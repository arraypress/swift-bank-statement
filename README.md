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
  `2026-03-12`, and month names in Dutch, French, German, Spanish, Italian and
  Portuguese (`1 mei`, `02 janv. 25`, `22. März`). Day-first or month-first is decided from **all** the dates at
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

| Test set | Result |
|---|---|
| Hand-built layouts — UK out/in/balance, US signed amount, debit/credit with no balance column, comma decimals, credit card, figures on the last line across a new year, three-page carried forward | every transaction, date, description and figure exact; all reconciled |
| **100 generated statements** — 3–60 random transactions, 1–3 line descriptions, random page lengths and overdrafts, fixed seed | **100 / 100** read exactly and reconciled |
| **50 generated misprints** — one figure printed a penny out | **50 / 50** reported `broken` |
| A figure altered; a row dropped | broken at exactly that row, naming it |
| 400 transactions over 11 pages, release build | **0.22 s** end to end, through the CLI |

**Independent layouts: the bankstatemently benchmark.** Five born-digital
statements from [bankstatemently/bank-statement-parsing-benchmark](https://github.com/bankstatemently/bank-statement-parsing-benchmark)
(MIT; fictional banks with synthetic data, built by a third party to carry
the formatting problems of real banks in five countries). Not used to build
the parser, and not copied into this repository — the failures they exposed
are rebuilt from positioned words in `RealLayoutTests`.

| Statement | First run | After the fixes |
|---|---|---|
| bsb-001 — SG, withdrawal/deposit/balance, wrapped descriptions | reconciled, 12/12 | reconciled, 12/12, 13 balances checked |
| bsb-002 — US card, post + trans date, one signed amount | no table found | reconciled, 15/15 |
| bsb-003 — NL, Dutch dates (`1 mei`), `114,83 €`, page 2 with no header | no table found | reconciled, 22/22; in and out match the printed totals |
| bsb-004 — HK, **two accounts** in one statement, bilingual headers | broken at the second account | **both reconciled** (0.3.0: 15 + 11 transactions, read per account) |
| bsb-005 — CA, French, date inside "Détails", `1 200,45 $` | no table found | reconciled, 25/25, 26 balances checked |

**1 of 5 → 4 of 5**, every reconciled one with exactly the benchmark's
transaction count. What each failure was:

- A heading of many words — *Merchant Name or Transaction Description*,
  *Interest Date* — was split into a known phrase and an unknown remainder a
  fifth of a line apart, and the gutter rule refused the row. Headers are now
  read cell by cell, a cell named by the longest heading inside it.
- A card statement printed **0.00 beside every continuation line**. Read as
  transactions they doubled the count to 30 — and it still *reconciled*,
  because a zero changes no sum. The check cannot see that, so the parser
  must: an undated line whose only figures are zero runs on from the line
  above. The one known gap in "every read is checked".
- Dutch and French month names did not parse, so a page with no header —
  continued from its first *dated* row — was lost with two transactions on it.
  Month names now in English, Dutch, French, German, Spanish, Italian and
  Portuguese, accents folded.
- "Balance as of 01.05.2025" and "… 31.05.2025" named the opening and closing
  by date alone; the earlier is now the opening.
- A table with no date column (French: the date leads "Détails") is a header
  when it sets out a description, money and a balance; the date is taken from
  the start of the description.
- A document that spaced every word at 0.6 of a line — the old fixed limit for
  joining `1 200,45` — read its closing balance as 133.60. The limit now
  follows the row's own spacing. Currency marks set after a figure (`114,83 €`)
  join it rather than trailing into the description.
- A header's second line (the same headings in Chinese) became the tail of a
  transaction; a dateless, figureless line right under a header is now part of it.

**Several accounts in one statement (0.3.0).** bsb-004 holds a current and a
savings account under their own headings; read as one table the savings
account's first balance (149,818.96) was checked against the current
account's last and the read failed. `StatementReader.accounts(contentsOf:)`
cuts the rows at each heading that names an account and a number of eight
digits or more, with no money on its row, so a "transfer to account …" line
stays a transaction. A page header repeating the customer number had cut
each account into pieces; pieces of the same account are joined. Each
account reconciles on its own: **5 of 5 benchmark statements now reconcile.**
A statement of one account reads exactly as `read` reads it.

**Real banks' own statements are still UNTESTED**: these are third-party
reproductions of real layouts. The reconciliation is what makes trying a new
bank safe — a misread shows as `broken`, not as wrong numbers — with the one
exception above, now closed for the case that was found.

**A probe that changed the design.** PDFKit's `characterBounds(at:)` drifts one
character per line break away from `PDFPage.string` — on the first probe, index
42 returned the box of character 43, so every word after the first line would
have been placed under its neighbour. `selection(for:)` on a range agrees
with the string, and that is what this reads with — a token at a time, and a
character at a time only for a token too wide to be one word.
`selectionsByLine()` was ruled out the same way: it split one printed row in
two at the gap before the money columns.

**Where the time went.** The first build took 2.1 s for that 400-row
statement, and reading the text layer was not why: profiled, PDFKit took
0.04 s and the rest was Swift `Regex` run on every word of every row — the
header test, the money test, the date search. A digit check before the
money and date patterns, the word "date" before the header test, and looking
for the period outside the table first took it to 0.22 s.

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
- **Headings in English, Dutch, French, German and Spanish only**, and on one
  line: a header that stacks "Money" above "out" is not recognised.
- ~~**Several accounts in one statement**~~ — read per account since 0.3.0. (Was: reported `broken` at the
  second account.)
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
