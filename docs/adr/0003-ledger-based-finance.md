# ADR-0003: Ledger-based finance

- Status: Accepted
- Date: 2026-08-26

## Context

The prototype tracked dues as a `status` column moving through nine states, mutated
escalation during read requests, and deleted the linked lapsed row when a reinstatement
was paid. Balances were not derivable and history was destroyed by design.

The live-data inventory (2026-08-26) found 955 legacy receipts totalling ₹10,72,892 and
exactly one advice row, so converting to a ledger carries little migration risk. The
prototype holds receipts but **no expenses**, so the record is inherently unbalanced.

## Decision

Money is modelled as append-only `ledger_entries` against a unit account, with
`invoices`, `invoice_lines`, `receipts`, `adjustments` and `dunning_events` as documents
that produce entries. Outstanding balance is derived, never stored as status. Nothing is
hard-deleted; corrections are reversing entries. Escalation runs as an idempotent
scheduled job writing a `dunning_event` and a penalty entry.

**History is not migrated.** The books open at a cut-off with a certified statement of
affairs, the General Fund being the derived balancing figure. The 955 legacy receipts
become a read-only `legacy_payment_records` archive outside the ledger.

## Consequences

- Any balance can be explained by replaying entries — an auditor requirement, and at
  100 societies the money in scope makes this a liability question, not a nicety.
- Running escalation twice in a day is a no-op.
- More tables and more write discipline than a status column.
- Reporting reads `financial_year`/`period`, never inferred from `paid_at` — v1 uses
  FY-end dating, including dates in 2027.
