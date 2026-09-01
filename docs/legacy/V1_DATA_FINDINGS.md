# CivicSync v1 — Live Data Findings

Source: Neon `civicsync`, inventory run 2026-08-26.
Snapshot reconciled against: `civicsync_neon_2026-08-25.dump`
(sha256 `5acf3025…bcd99a`, 5.4 MB).

## Headline

The live dataset is **a member register plus a legacy payment history, and almost
nothing else**. Operational modules were built but barely used.

| Entity | Rows | Note |
| --- | --- | --- |
| Members | 370 (361 live, 9 soft-deleted) | The primary asset |
| Users | 370 | One per member, including deleted |
| Payments | 955 | All `provider=legacy`, all `success`, ₹10,72,892 total |
| Payment advice | **1** | Single `lapsed` row, ₹576.15 |
| Payment requests | 1 | ₹501.00, `sent`/`selected` |
| Member documents | 8 | All `allotment_letter` — 5 verified, 3 pending |
| Expense vouchers | 2 | Both `pending_approval` |
| Notices | 1 | |
| Activity logs | 516 | |
| migration_audit | 0 | Legacy import provenance was NOT recorded here |

**Consequence:** the feared "migrate a complex financial state machine with
escalation and reinstatement history" problem does not exist. There is one
escalated advice. The migration is essentially *members + 955 historical
receipts + 8 documents*.

## Schema state — hazard

`schema_migrations.version = 26`, but columns from migrations 027 and 028 are
present (`reinstates_payment_request_member_id`, `payments.payment_reference`).
These were created by `db.RepairCurrentSchema`, not by golang-migrate.

Migration 029 (`organization_settings.google_drive_shared_url`) is **absent on
Neon but present on the local copy**.

> **Do not run `migrate up` against Neon.** Migrations 027/028 will attempt to add
> columns that already exist, fail, and leave `schema_migrations.dirty = true`.
> If the prototype must be advanced, force the version or make those migrations
> idempotent first — and only after a fresh dump.

This is exactly the failure mode that justifies deleting `RepairCurrentSchema` in
v2 and making migrations the sole schema authority.

## Money

All 955 payments are legacy imports, none linked to any advice.

| Period | Count | Amount (₹) |
| --- | --- | --- |
| FY 2023-24 | 363 | 3,75,600 |
| FY 2024-25 | 295 | 4,49,651 |
| FY 2025-26 | 254 | 1,94,300 |
| FY 2026-27 | 39 | 44,145 |
| Legal FY 2025-26 | 3 | 7,996 |
| Membership Fee | 1 | 1,200 |
| **Total** | **955** | **10,72,892** |

`10,72,892.00` is the figure the v2 ledger must reconcile to, to the paisa.

`paid_at` range is 2024-03-30 .. **2027-03-30** — future-dated. Almost certainly a
legacy convention of stamping FY-end dates. Needs confirmation before migration;
future-dated receipts will distort any period reporting built on them.

The single advice: parent request ₹501.00, advice row ₹576.15, status `lapsed`.
Principal and penalty **are** separable (₹501.00 + ₹75.15, a 15% escalation).
With one row, this can be migrated by hand if needed.

## Data quality — the real problem

| Probe | Result | Severity |
| --- | --- | --- |
| Phone not 10 digits | **361 of 361 live members** | Blocking |
| Email missing or malformed | **358 of 361** | Blocking |
| Flat number non-numeric | 4 | Minor |
| Aadhaar stored | 7 | Trivial — drop |
| Duplicate tower+flat | 0 | Clean |
| Duplicate phone | 0 | Clean |
| Members without user | 0 | Clean |
| Orphaned advice / payments | 0 | Clean |
| Paid advice without payment | 0 | Clean |

Referential integrity is perfect. Contact data is not usable.

Contact verification state: 358 members have neither phone nor email verified;
1 has phone only; 2 have both. Only 2 members are `active` — consistent with only
5 verified allotment letters existing.

**Implication for the resident mobile app:** phone number is the login identity.
With zero usable phone numbers, the app cannot onboard anyone. Collecting valid
resident contact details is a *society business process*, not an engineering task,
and it must run in parallel with the build rather than being discovered at launch.

## Property structure

| Tower | Live members |
| --- | --- |
| T1 | 87 |
| T2 | 90 |
| T3 | 87 |
| T4 | 92 |
| SHOP4 | 1 |
| UNASSIGNED | 4 |

`SHOP4` is a commercial unit and `UNASSIGNED` is a placeholder — both confirm that
v2 needs `unit_type` as master data (residential / commercial / unassigned) rather
than assuming every unit is a flat.

## Documents

8 documents for 361 members — 2% coverage. All allotment letters. No blank file
paths. Whether the bytes live in `file_data` or only as filesystem paths is still
unconfirmed (follow-up query pending). If any are path-only, those bytes were on an
ephemeral host filesystem and are probably already lost.

## Roles in use

| App role | Organization role | Count |
| --- | --- | --- |
| member | Executive Member | 365 |
| admin | General Secretary | 1 |
| admin | Joint Treasurer | 2 |
| super_admin | President | 1 |
| super_admin | Treasurer | 1 |

Five distinct role combinations. These seed the v2 system roles directly.

## Revisions to the migration plan

1. **Downgrade financial migration risk.** No escalation history, no reinstatement
   chains, one advice row. Migrate 955 receipts as opening ledger entries.
2. **Promote contact-data remediation to a first-class workstream**, owned by the
   society, started immediately.
3. **Members were bulk-created 2026-05-31 to 06-01** — the register itself came from
   the legacy import, so the legacy BWA source may hold contact data this database
   lost. Worth checking `bwa_hq` before assuming the data never existed.
4. **Drop Aadhaar entirely** — only 7 rows. No reason to carry the liability.
5. **Unit types are needed from day one** (SHOP4, UNASSIGNED).

---

## Owner clarifications — 2026-08-26

Recorded from Sidhant, and they downgrade two findings above:

**Contact data is not a data-loss problem.** The RWA holds the real phone numbers
and emails. The values in this database were whatever was available at import time,
plus 3–4 known residents' real details used for platform testing. The society will
verify and correct contacts once it has hands-on use of the app.

Revised implication: contact remediation is an **onboarding workflow requirement**,
not a pre-migration blocker. What v2 must provide is bulk contact import/edit,
per-contact verification state, and a resident self-service correction path — which
the design already carries. Migrate the existing values as-is, unverified.

**`paid_at` values in 2027 are an FY-end convention**, not bad data. Migrate the
dates verbatim; do not "correct" them. v2 must derive reporting periods from an
explicit financial-year field rather than inferring them from payment timestamps —
`period` and `financial_year` are authoritative, `paid_at` is not.

Both are now settled. Neither blocks Phase 0.

## Owner clarification — documents

All 8 `member_documents` rows are **dummy files used for platform testing**. No real
allotment letters, no legal documents, nothing with retention or evidentiary value.

Consequence: **document migration scope is zero.** Do not build an ETL stage for
`member_documents` or `notices.attachment_data`. v2 starts with an empty document
store and real documents are collected through the new upload path.

This removes the last unknown from the migration. Final ETL scope is:

| Source | Rows | Destination |
| --- | --- | --- |
| `members` | 370 | `parties` + `units` + `occupancies` + `unit_accounts` |
| `users` | 370 | `users` + `memberships` |
| `payments` | 955 | `receipts` + opening `ledger_entries` (₹10,72,892) |
| `payment_requests` / `payment_request_members` | 1 + 1 | one `invoice` + `dunning_event` (may be done by hand) |
| `activity_logs` | 516 | `audit_log` archive partition |
| `expense_vouchers`, `notices`, `member_documents`, settings | — | **not migrated**; test data only |

Everything else in the prototype database is test data and is deliberately discarded.
