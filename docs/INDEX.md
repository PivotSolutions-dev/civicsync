# CivicSync — Document Index

**Maintained:** 26 Aug 2026 · **Scope:** every planning, standards and reference document
in this repository.

This is the map. If you are looking for where a decision was made, it is listed here.
If a decision is not written down in one of these files, it has not been made.

---

## If you are new, read in this order

For a future hire, or for yourself in six months. About four hours.

| # | Document | Why here |
| --- | --- | --- |
| 1 | [PRODUCTION_PLAN.md](PRODUCTION_PLAN.md) | What we are building and why. Start here or nothing else makes sense |
| 2 | [RELEASE_PLAN.md](RELEASE_PLAN.md) | Scope of Release 1.0 vs 2.0, the 17 packets, the timeline |
| 3 | [MODULE_REGISTER.md](MODULE_REGISTER.md) | The system's shape: modules, boundaries, ownership |
| 4 | [ARCHITECTURE_DDD.md](ARCHITECTURE_DDD.md) | How code is organised, and what we deliberately do not do |
| 5 | [PLATFORM_ENGINEERING_STANDARDS.md](PLATFORM_ENGINEERING_STANDARDS.md) | The rules, and the CI checks that enforce them |
| 6 | [REGISTRY_OWNERSHIP_MODEL.md](REGISTRY_OWNERSHIP_MODEL.md) | The hardest part of the domain: title, occupancy, membership |
| 7 | [TECH_STACK.md](TECH_STACK.md) | Every technology choice, including the rejected ones |
| 8 | [legacy/V1_DATA_FINDINGS.md](legacy/V1_DATA_FINDINGS.md) | What the live data actually contains |
| 9 | [DEVELOPMENT_PLANNER.md](DEVELOPMENT_PLANNER.md) | Then go build |

---

## Decisions and strategy

| Document | Settles | Status |
| --- | --- | --- |
| [PRODUCTION_PLAN.md](PRODUCTION_PLAN.md) | Product scope, tenancy model, migration strategy, phased approach | Accepted 25 Aug 2026. Stack table superseded by TECH_STACK; §4.1 superseded by REGISTRY_OWNERSHIP_MODEL; §6 superseded by RELEASE_PLAN |
| [RELEASE_PLAN.md](RELEASE_PLAN.md) | Release 0.5 (Association Core) / 1.0 / 1.1 / 2.0 scope, 17 packets, capacity, milestone dates, what to cut if capacity slips | **Rev 3**, 26 Aug 2026 — re-sequenced after the NBCC handover order |
| [TECH_STACK.md](TECH_STACK.md) | Every technology choice and every rejection, with reasons | Accepted 26 Aug 2026 |
| [REPO_BOOTSTRAP.md](REPO_BOOTSTRAP.md) | New repository creation, prototype freeze, carry-over manifest, branch model | Action required |

## Engineering standards

| Document | Settles | Status |
| --- | --- | --- |
| [PLATFORM_ENGINEERING_STANDARDS.md](PLATFORM_ENGINEERING_STANDARDS.md) | Object storage over BYTEA, UUIDv7 keys, typed dimensions, no DDL enums, real encryption, the table spine, indexing and partitioning, keyset pagination, idempotency, the outbox, observability, the one-way doors at 100+ societies, and the nine CI checks | Accepted 26 Aug 2026 |
| [ARCHITECTURE_DDD.md](ARCHITECTURE_DDD.md) | Pragmatic DDD: ubiquitous language, layering, aggregates, value objects, domain events, anti-corruption layers, testing by layer, and why not event sourcing / CQRS / a DI framework | Accepted 26 Aug 2026 |

## Domain and modules

| Document | Settles | Status |
| --- | --- | --- |
| [MODULE_REGISTER.md](MODULE_REGISTER.md) | Module boundaries and ownership, per-society module enablement, permission and event naming, the packet map | Accepted 26 Aug 2026. `memberships` renamed to `role_assignments` per REGISTRY_OWNERSHIP_MODEL |
| [REGISTRY_OWNERSHIP_MODEL.md](REGISTRY_OWNERSHIP_MODEL.md) | Title, occupancy and association membership as three orthogonal relationships; joint vs tenancy-in-common; sale and tenancy workflows; who is liable for which charge | Accepted 26 Aug 2026 |

## Data and migration

| Document | Settles | Status |
| --- | --- | --- |
| [DATA_PROVENANCE.md](DATA_PROVENANCE.md) | Where the live data lives, which copies are authoritative, snapshot checksums, backup rules | **Living document — append every snapshot** |
| [legacy/V1_DATA_FINDINGS.md](legacy/V1_DATA_FINDINGS.md) | What the prototype database actually contains: 370 members, 955 receipts, ₹10,72,892, the schema hazard, what is test data | Accepted 26 Aug 2026 |
| [legacy/FUNCTIONAL_REFERENCE.md](legacy/FUNCTIONAL_REFERENCE.md) | The prototype's complete behaviour. **The acceptance-test specification for Release 1.0** | Reference. Inherited from the prototype |
| [legacy/inventory-2026-08-26.csv](legacy/inventory-2026-08-26.csv) | Raw inventory output the findings are derived from | Evidence |

## Commercial and compliance

| Document | Settles | Status |
| --- | --- | --- |
| [COMMERCIAL_STRUCTURE.md](COMMERCIAL_STRUCTURE.md) | Who registers what: Pivot vs the society. Why payments must never route through Pivot. DPDP roles. Per-society onboarding checklist | Accepted, two items pending professional confirmation |
| [CHANNEL_STRATEGY.md](CHANNEL_STRATEGY.md) | WhatsApp-first, DLT deferred. One WABA with society as a template parameter. Webhook org resolution. Template inventory. Consent and quality protection | Accepted 26 Aug 2026 |
| [COLLECTION_STRATEGY.md](COLLECTION_STRATEGY.md) | Zero-cost UPI as the default, payment intents and the four identifiers, payment modes as master data, the reported-payment state, statement reconciliation, refunds, why UPI has no acknowledgement, and the `CollectionProvider` port that makes a future gateway an adapter | Rev 2, 26 Aug 2026. Supersedes COMMERCIAL_STRUCTURE §4's gateway-by-default assumption |
| [CUTOVER_PLAN.md](CUTOVER_PLAN.md) | The Pivot → association engagement: ten meetings, related-party governance, opening-balance approach, Go/No-Go criteria, the cut-over certificate, and Pivot's commitments | **Living document.** Target go-live 1 Apr 2027 |
| [MESSAGING_COMPLIANCE.md](MESSAGING_COMPLIANCE.md) | TRAI DLT process, documents, fees, template rules and traps; Meta WABA onboarding, pricing, tiers, quality rating | Reference. DLT deferred by CHANNEL_STRATEGY — retained for when it is needed |

## Build packets

| Document | Covers | Status |
| --- | --- | --- |
| [DEVELOPMENT_PLANNER.md](DEVELOPMENT_PLANNER.md) | All 17 packets: objective, required reading, deliverables, CI checks, exit criteria, review points | **Living document** |
| [packets/BUILD_PACKET_00.md](packets/BUILD_PACKET_00.md) | Foundation — monorepo, tenancy, CI guards, ADRs. Revision 2: Fiber v3, PostgreSQL 18 | Ready to build |

Packets 01–16 are written one at a time, as each is reached.

## Architecture decision records

| ADR | Decision |
| --- | --- |
| [adr/0001-pooled-multi-tenancy-with-rls.md](adr/0001-pooled-multi-tenancy-with-rls.md) | Pooled multi-tenancy with row-level security |
| [adr/0002-contract-first-openapi.md](adr/0002-contract-first-openapi.md) | Contract-first OpenAPI |
| [adr/0003-ledger-based-finance.md](adr/0003-ledger-based-finance.md) | Ledger-based finance |

ADRs are created in Packet 00. Add one whenever a decision would be expensive to reverse
and a future reader would ask "why on earth did they do that?"

## Operational scripts

| Path | Purpose |
| --- | --- |
| `ops/migration/legacy/v1_discover.sql` | Reports a CivicSync database's schema and migration version |
| `ops/migration/legacy/v1_inventory.sql` | Version-safe inventory: counts, money totals, data-quality probes |
| `ops/migration/legacy/v1_followup.sql` | Aggregate-only probes: phone and email shapes, document bytes, payment dating |
| `ops/checks/*` | The CI guards. See PLATFORM_ENGINEERING_STANDARDS §15 |

## Superseded, kept for history

| Document | Replaced by |
| --- | --- |
| `legacy/TECHNICAL_OVERVIEW.md` | PLATFORM_ENGINEERING_STANDARDS + ARCHITECTURE_DDD |
| `legacy/DEPLOYMENT_STRATEGY.md` | To be replaced by an operations runbook in Packet 15 |
| `legacy/SAAS_EVOLUTION.md` | ADR-0001 and PLATFORM_ENGINEERING_STANDARDS §16 |
| `legacy/OPERATIONS_RUNBOOK.md` | To be replaced in Packet 15 |
| `AI_HANDOFF.md` *(prototype repo only)* | This corpus |

---

## Where decisions live

When you cannot remember where something was settled:

| Question | Document |
| --- | --- |
| Why one database for all societies? | ARCHITECTURE — ADR-0001, ENGINEERING_STANDARDS §1 |
| Why UUIDs and not bigserial? | ENGINEERING_STANDARDS §3 |
| Why aren't files in the database? | ENGINEERING_STANDARDS §2 |
| Why can't I add a CHECK constraint enum? | ENGINEERING_STANDARDS §5 |
| What must every new table have? | ENGINEERING_STANDARDS §8 |
| Which module owns this table? | MODULE_REGISTER Part 1–2 |
| Can module A read module B's tables? | MODULE_REGISTER, "the boundary rule" |
| Where does this code go — domain, app, store or http? | ARCHITECTURE_DDD §2 |
| What is an aggregate here? | ARCHITECTURE_DDD §3, REGISTRY_OWNERSHIP_MODEL §7 |
| Owner vs tenant vs member? | REGISTRY_OWNERSHIP_MODEL §1 |
| Who pays for what? | REGISTRY_OWNERSHIP_MODEL §6 |
| Which library for X? | TECH_STACK |
| Why not event sourcing? | ARCHITECTURE_DDD §9.1 |
| When do we shard? | ENGINEERING_STANDARDS §16 |
| Who registers with Meta — us or the society? | COMMERCIAL_STRUCTURE §3 |
| Can we collect maintenance into our account? | COMMERCIAL_STRUCTURE §4. **No** |
| Do we need a payment gateway? | COLLECTION_STRATEGY §1. Not for Release 1.0 |
| How do we collect at zero cost? | COLLECTION_STRATEGY §4 |
| How does a UPI payment get reconciled? | COLLECTION_STRATEGY §4.3 |
| Which reference do we match payments on? | COLLECTION_STRATEGY §4.6. The UTR |
| Does UPI acknowledge a payment like a gateway? | COLLECTION_STRATEGY §6.1. No — acknowledgement is a service you buy |
| How do we add a payment gateway later? | COLLECTION_STRATEGY §7 |
| Why don't we migrate the old expense history? | CUTOVER_PLAN §2, PLANNER Packet 07. There isn't any — books open with balances |
| What does the committee have to approve, and when? | CUTOVER_PLAN §3-4 |
| How do we handle my family being on the committee? | CUTOVER_PLAN §5 |
| What happens on 1 April 2027? | CUTOVER_PLAN §6 |
| How does one WABA serve 100 societies? | CHANNEL_STRATEGY Part 2 |
| Which database is the live one? | DATA_PROVENANCE |
| What is actually in the live data? | legacy/V1_DATA_FINDINGS.md |
| What should the app do? | legacy/FUNCTIONAL_REFERENCE.md |
| What am I building next? | DEVELOPMENT_PLANNER |
| What is in Release 0.5 vs 1.0? | RELEASE_PLAN Parts 1-2 |
| Why is billing not in the first release? | RELEASE_PLAN, "What changed, and why" |

---

## Decision log

Chronological, so a reversal is visible as a reversal.

| Date | Decision | Recorded in |
| --- | --- | --- |
| 25 Aug 2026 | Rebuild rather than refactor; prototype frozen | PRODUCTION_PLAN |
| 25 Aug 2026 | Pooled multi-tenancy with RLS, not database-per-society | PRODUCTION_PLAN §1, ADR-0001 |
| 25 Aug 2026 | Go backend, responsive React admin, Flutter resident app | PRODUCTION_PLAN, later refined by TECH_STACK |
| 26 Aug 2026 | Live data is Neon `civicsync`; snapshot taken and checksummed | DATA_PROVENANCE |
| 26 Aug 2026 | Financial migration risk downgraded — one advice row, 955 clean receipts | legacy/V1_DATA_FINDINGS |
| 26 Aug 2026 | Documents are test data; document migration scope is zero | legacy/V1_DATA_FINDINGS |
| 26 Aug 2026 | PostgreSQL 18 for native `uuidv7()` | ENGINEERING_STANDARDS §3 |
| 26 Aug 2026 | Object storage for all file content; no BYTEA | ENGINEERING_STANDARDS §2 |
| 26 Aug 2026 | Telemetry gets its own schema and pool from migration 1 | ENGINEERING_STANDARDS §16 |
| 26 Aug 2026 | Modules have hard boundaries and per-society enablement | MODULE_REGISTER |
| 26 Aug 2026 | Pragmatic DDD; no event sourcing, no CQRS by default, no DI framework | ARCHITECTURE_DDD §9 |
| 26 Aug 2026 | **Reversed:** chi → Fiber v3, to align with the other project | TECH_STACK |
| 26 Aug 2026 | Redis for ephemeral state only; jobs stay in PostgreSQL | TECH_STACK |
| 26 Aug 2026 | gRPC deferred to device ingest | TECH_STACK |
| 26 Aug 2026 | **Corrected:** title, occupancy and membership are three separate facts | REGISTRY_OWNERSHIP_MODEL |
| 26 Aug 2026 | 17 packets; capacity 4 days/week; Flutter app decoupled to Release 1.1 | RELEASE_PLAN |
| 26 Aug 2026 | New repository; prototype frozen but **not archived** until cutover | REPO_BOOTSTRAP |
| 26 Aug 2026 | `main` trunk with packet branches; releases are tags, not branches | REPO_BOOTSTRAP |
| 26 Aug 2026 | Messaging registers at platform level; payments at society level | COMMERCIAL_STRUCTURE |
| 26 Aug 2026 | **Reversed:** DLT deferred; WhatsApp-first with email and society-issued code fallbacks | CHANNEL_STRATEGY |
| 26 Aug 2026 | One WABA, one template set, society as a parameter; per-society WABA is enterprise tier | CHANNEL_STRATEGY |
| 26 Aug 2026 | **Reversed:** payment gateway is not the default. Zero-cost UPI with statement reconciliation is; Razorpay deferred to Release 1.1 | COLLECTION_STRATEGY |
| 26 Aug 2026 | Payment modes are master data — UPI, bank transfer, cash, cheque, gateway | COLLECTION_STRATEGY §5 |
| 26 Aug 2026 | Gateway readiness: build the `CollectionProvider` port, callback pipeline, fee modelling and conformance suite in 1.0; defer checkout, mandates and settlement reconciliation | COLLECTION_STRATEGY §7 |
| 26 Aug 2026 | **Re-sequenced:** NBCC handover order means billing is not urgent but the member register, BBA documents, notices and **books** are. Release 0.5 (Association Core) inserted | RELEASE_PLAN rev 3 |
| 26 Aug 2026 | Prototype **retired outright**, no bridge. The Neon snapshot is the migration source | RELEASE_PLAN |
| 26 Aug 2026 | Release 0.5 is admin-only, but the **resident API is built and tested** — only the UI is deferred | RELEASE_PLAN, PLANNER Packet 02 |
| 26 Aug 2026 | ETL runs early and is **production, not a fixture**. Password hashes are not migrated — auth is WhatsApp OTP | PLANNER Packets 05, 07 |
| 26 Aug 2026 | **Books open with certified balances, not migrated history.** The prototype holds receipts but no expenses; the General Fund is the derived balancing figure | PLANNER Packet 07, CUTOVER_PLAN §2 |
| 26 Aug 2026 | 955 legacy receipts become a **read-only `legacy_payment_records` archive**, outside the ledger — not `receipts` | PLANNER Packet 07 |
| 26 Aug 2026 | **Go-live 1 April 2027**, opening FY 2027-28. The project's only hard date. Books built before notices to buy five weeks of parallel run | CUTOVER_PLAN §1, RELEASE_PLAN |

---

## Maintenance rules

1. **A new document is added to this index in the same commit.** An unindexed document
   is one nobody will find.
2. **When a document supersedes part of another, say so in both** — a note at the top of
   the superseded section, and a Status entry here. Silent supersession is how two
   documents come to disagree.
3. **Add a Decision log row whenever a decision is made or reversed.** Reversals stay
   visible; they are the most useful rows in the table.
4. **Living documents** — DATA_PROVENANCE, DEVELOPMENT_PLANNER, this index — are appended
   to, never rewritten.
