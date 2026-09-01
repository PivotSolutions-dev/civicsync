# CivicSync — Technical Development Planner

**Living document** · Started 26 Aug 2026 · **Companion to** the Build Packets

`RELEASE_PLAN.md` owns scope, capacity and dates. This document owns **what to build,
what to read before building it, and how you know it is done.** Where they touch, this
one links rather than repeats.

Packets 00–03 are detailed. Packets 04–16 are outlined and expanded as each is reached —
detail written eight months early is detail written against assumptions that will change.

---

## How to use this

For every packet:

1. Read the **Required reading** before writing code. It is short and specific — a
   section, not a document.
2. Cut the branch: `git checkout -b packet/NN-name`
3. Build to the **Deliverables**.
4. Verify against the **Exit criteria**. Demonstrable, not "written".
5. Open the PR. CI must be green — **never `--no-verify`, never bypass a check**.
6. **Review checkpoint** with Claude before merging.
7. Squash-merge. Tag if it is a release.

---

## Standing rules — every packet, no exceptions

These are not repeated per packet below. They always apply.

| Rule | Where it is defined | Enforced by |
| --- | --- | --- |
| Every tenant table: `org_id`, FORCE RLS, a policy with `USING` **and** `WITH CHECK` | STANDARDS §8 | `check_rls.sql` |
| Every tenant table carries the full spine (`id`, `org_id`, audit columns, `deleted_at`, `version`) | STANDARDS §8 | `check_spine.sql` |
| Every index on a tenant table leads with `org_id` | STANDARDS §9 | `check_indexes.sql` |
| No `BYTEA` for file content | STANDARDS §2 | `check_no_blobs.sql` |
| No `CHECK (x IN …)` on business values — master data instead | STANDARDS §5 | `check_constraints.sql` |
| Every migration has a working `down` | — | `make migrate-redo` |
| `internal/domain` imports nothing from other layers | ARCHITECTURE_DDD §2 | `check_layers.sh` |
| A module never reads another module's tables | MODULE_REGISTER, boundary rule | `check_module_boundaries.sh` |
| Generated code matches the OpenAPI spec | ADR-0002 | codegen diff |
| Money is `numeric(14,2)`; strings in JSON | STANDARDS §4 | review |
| Mutating endpoints accept `Idempotency-Key` | STANDARDS §11 | review |
| Conventional Commits, scope = module code | REPO_BOOTSTRAP | review |
| Every new table declares its module in a migration comment | MODULE_REGISTER | `check_spine.sql` |

**A packet that adds a CI check is not done until that check is in `make ci` and passing.**

---

## Definition of done — copy per packet

```markdown
- [ ] All deliverables built
- [ ] All exit criteria demonstrated (not "written" — shown)
- [ ] `make ci` green locally
- [ ] Any new CI check added to `make ci` and to the standing-rules table
- [ ] Migrations reversible (`make migrate-redo`)
- [ ] OpenAPI spec updated; generated clients regenerated
- [ ] Domain-layer unit tests for every new aggregate invariant
- [ ] Integration tests for new store queries, including a cross-tenant isolation test
- [ ] `DEVELOPMENT_PLANNER.md` updated with what actually happened
- [ ] `INDEX.md` updated if a document was added or superseded
- [ ] ADR written if a decision was made that would be expensive to reverse
- [ ] Reviewed with Claude
- [ ] PR squash-merged to main, branch deleted
```

---

## Dependency graph

**Revision 2, 26 Aug 2026** — re-sequenced for Release 0.5 (Association Core). See
`RELEASE_PLAN.md` for why.

```
RELEASE 0.5 — Association Core (admin-only, books not billing)

00 Foundation
 └── 01 Platform core ──┬── 02 Identity & access  (resident API built, no UI)
                        └── 03 Files, jobs, messaging
                              └── 04 Admin shell + Master Data Console
                                    └── 05 Registry + ETL 1  ◄── HANDS ON
                                          ├── 06 Documents (BBA gate)
                                          └── 07 Books + legacy archive  ◄── EXCEL RETIRED
                                                └── 08 Notices
                                                      └── RELEASE 0.5

RELEASE 1.0 — Operating Society (post-handover)

07 └── 09 Billing & collection
         ├── 10 Workflow + transfer/tenancy ── 11 Expense vouchers
         ├── 12 Reporting
         └── 13 Resident portal (UI over the Packet 02 API)
                └── 14 Hardening ── 15 GA = RELEASE 1.0
                                      └── 16 Flutter app = RELEASE 1.1
```

**`registry` (05) is the hinge.** Everything downstream depends on it; it depends on
nothing. It is also the association's first hands-on moment. Get the model right there —
it is the most expensive thing to change later.

---

# Packet 00 — Foundation

| | |
| --- | --- |
| **Objective** | A running, empty platform with the tenancy primitives and CI guards in place |
| **Modules** | `platform.tenancy` |
| **Estimate** | 5 days · ~1.5 weeks at 4 days/wk · target **mid Sep 2026** |
| **Depends on** | Repository bootstrap complete |
| **Blocks** | Everything |

### Required reading

| Read | For |
| --- | --- |
| [REPO_BOOTSTRAP.md](REPO_BOOTSTRAP.md) — all | Do this first. Packet 00's Step 1 points here |
| [packets/BUILD_PACKET_00.md](packets/BUILD_PACKET_00.md) — all | The packet itself |
| [TECH_STACK.md](TECH_STACK.md) — Backend table | Exact libraries and versions |
| [PLATFORM_ENGINEERING_STANDARDS.md](PLATFORM_ENGINEERING_STANDARDS.md) §1, §15 | Why RLS is shaped this way; the check list |
| [ARCHITECTURE_DDD.md](ARCHITECTURE_DDD.md) §2, §7 | Layering and directory layout |
| ADR-0001 (you write it in this packet) | Tenancy rationale |

### Deliverables

- Monorepo skeleton per ARCHITECTURE_DDD §7
- `docker-compose.yml`: PostgreSQL 18, Redis, MinIO, Mailpit, Gotenberg
- Migration 000001: `app` / `control` / `telemetry` schemas, `app.current_org_id()`,
  `app.touch_updated_at()`, `control.tenants`, `control.plan_modules`,
  `control.org_modules`
- Migration 000002: `civicsync_app` role, grants, default privileges, control-plane revoke
- Go service on **Fiber v3**: config, logging, `reqctx`, `database.InTenantTx`, problem+json
  error handler, `/health`
- CI checks: `check_rls.sql`, `check_no_blobs.sql`, `check_layers.sh`
- Makefile, GitHub Actions workflow
- ADR-0001, ADR-0002, ADR-0003

### New CI checks

`check_rls.sql` · `check_no_blobs.sql` · `check_layers.sh` · `make migrate-redo`

### Exit criteria

- [ ] `make up && make migrate-up` works from a clean checkout
- [ ] `curl localhost:8080/health` → `{"status":"ok"}`
- [ ] `make ci` green
- [ ] `civicsync_app` has `rolsuper = f` **and** `rolbypassrls = f`
- [ ] Three ADRs committed

### Review checkpoint

The role-flags check, and anything that did not compile as written.

### Parallel, non-code

Udyam ✅ · **Meta WABA** ✅ · Razorpay Partner enquiry · CA conversation on
`COMMERCIAL_STRUCTURE.md` §7 item 1

---

# Packet 01 — Platform core

| | |
| --- | --- |
| **Objective** | The ERP substrate: nothing hardcoded, everything audited, tenancy provably enforced |
| **Modules** | `platform.masterdata`, `.settings`, `.audit`, `.numbering` |
| **Estimate** | 12 days · ~3.5 weeks · target **early Oct 2026** |
| **Depends on** | 00 |
| **Blocks** | Everything after |

### Required reading

| Read | For |
| --- | --- |
| STANDARDS §3, §4, §5, §6, §8, §9 | Keys, money, no DDL enums, settings, the spine, indexing and partitioning |
| MODULE_REGISTER Part 1, "Module enablement" | What the platform layer owns |
| ARCHITECTURE_DDD §4 | Value objects — `Money` lands here |
| STANDARDS §12 | The outbox pattern |

### Deliverables

- **The table-spine convention**, applied and enforced: `check_spine.sql`,
  `check_indexes.sql`, `check_constraints.sql` with its allowlist
- **Master-data framework** — the shared table shape, a `master_registry` describing each
  master entity, effective dating, `is_active`, CSV import/export, impact ("where is this
  used?")
- **Settings framework** — `setting_definitions` + `setting_values`, JSON-schema
  validation, scope, `is_secret`
- **Audit log** — append-only, monthly partitions, before/after, actor, request id
- **Number series** — `number_series`, allocation inside the caller's transaction
- **Outbox** — partitioned, with a River worker that publishes and marks
- **Partition management job** — creates the next three months, drops beyond retention
- **Module enablement** — seed `plan_modules`, enforce `org_modules` in middleware
- Two seeded societies for testing
- `Money` value object, `shopspring/decimal`, JSON as string

### New CI checks

`check_spine.sql` · `check_indexes.sql` · `check_constraints.sql`

### Exit criteria

- [ ] An automated test proves society A cannot read a single row of society B **at the
      SQL level, with application code deliberately bypassed** — connect as
      `civicsync_app`, set `app.org_id` to A, select from a table full of B's rows,
      assert zero
- [ ] A test proves a transaction that forgets to set `app.org_id` sees **zero** rows,
      not all rows
- [ ] A master entity can be added end to end: migration + registry row, nothing else
- [ ] A setting can be added as a seed row with no schema change
- [ ] `audit_log` records a before/after for every mutation in the packet
- [ ] Number series allocates correctly under concurrency (test with parallel goroutines)
- [ ] An outbox event survives a worker restart
- [ ] Partitions exist for the next three months
- [ ] Disabled module → `404`, and its permissions cannot be granted

### Review checkpoint

**The most important review of the project.** The isolation tests, the spine convention,
and the master-data framework. Everything downstream inherits these — a mistake here is
paid for seventeen times.

### Parallel, non-code

DPA template drafted · resident T&Cs and privacy policy drafted (needed before Packet 02
captures consent)

---

# Packet 02 — Identity and access

| | |
| --- | --- |
| **Objective** | People can log in, and the system knows exactly what each may do |
| **Modules** | `platform.identity`, `platform.access` |
| **Estimate** | 12 days · ~3 weeks · target **late Oct 2026** |
| **Depends on** | 01 |
| **Blocks** | 04 and everything with a UI |

### Required reading

| Read | For |
| --- | --- |
| MODULE_REGISTER Part 1 — identity, access | Table ownership |
| STANDARDS §7, §11, §13 | Envelope encryption, idempotency, error format |
| CHANNEL_STRATEGY Part 1 | **The OTP fallback chain — this shapes the auth flow** |
| REGISTRY_OWNERSHIP_MODEL §5, "Access scoping matters here" | **Why role assignments must be unit-scoped** |
| COMMERCIAL_STRUCTURE §5 | DPDP roles; what consent must be captured |

### Deliverables

- `users`, `credentials`, `sessions`, `refresh_tokens`, `devices`
- Argon2id for new passwords; bcrypt verification retained for migrated hashes, upgraded
  on next login
- 15-minute access tokens; **rotating** refresh tokens with reuse detection
- **OTP chain: WhatsApp → email → society-issued activation code.** Provider-neutral;
  **no OTP value in any API response, ever**
- `permissions`, `roles`, `role_permissions`, **`role_assignments`** (renamed from
  `memberships` — see REGISTRY_OWNERSHIP_MODEL §4)
- **`role_assignments` scopeable to an organization *or* a unit**, so a tenant sees their
  unit and a non-resident owner sees theirs
- `RequirePermission("module.entity.action")` middleware
- Seeded system roles reproducing the prototype's five combinations
- Rate limiting and lockout, Redis-backed
- Envelope encryption service + `org_secrets`
- Consent capture on contacts: channel, timestamp, wording shown

**Release 0.5 scope note.** Only office bearers log in at first — perhaps five people.
Build the resident capability anyway: **resident API endpoints implemented and tested,
resident UI not built.** That is ~2 of this packet's 12 days and it turns the portal
(Packet 13) and the Flutter app (Packet 16) into pure frontend work. A convenient side
effect: you test the whole WhatsApp auth chain on five known people instead of 370.

### Exit criteria

- [ ] Login works with password and with OTP
- [ ] A real WhatsApp OTP is delivered to a real handset
- [ ] Email OTP fallback works
- [ ] A society-issued activation code works with no external dependency at all
- [ ] No OTP appears in any response body or log
- [ ] Refresh rotation works; a reused token invalidates the family
- [ ] A permission test matrix passes: every role × every endpoint
- [ ] A unit-scoped assignment sees only that unit's data — proven by test
- [ ] Resident-scoped API endpoints return correct data for a seeded resident account,
      with no UI involved
- [ ] Rate limiting blocks brute force
- [ ] A secret round-trips through envelope encryption and is never returned by any API

### Review checkpoint

Auth is where security bugs live. Expect a thorough pass: token lifecycle, the permission
matrix, and the OTP paths.

### Parallel, non-code

WhatsApp authentication template submitted for approval

---

# Packet 03 — Files, jobs, messaging, integration

| | |
| --- | --- |
| **Objective** | The platform can hold files, do work in the background, talk to people, and be talked to by other systems |
| **Modules** | `platform.files`, `.jobs`, `.messaging`, `.integration` |
| **Estimate** | 8 days · ~2 weeks · target **mid Nov 2026** |
| **Depends on** | 01, 02 |
| **Blocks** | 06 documents, 07 books export, 08 notices |

### Required reading

| Read | For |
| --- | --- |
| STANDARDS §2 | **Object storage — the full upload/download mechanism** |
| STANDARDS §11, §12 | Idempotent jobs; outbox, webhooks, device ingest |
| CHANNEL_STRATEGY Parts 3, 4, 7 | **Webhook org resolution, template inventory, exactly what to build** |
| ARCHITECTURE_DDD §6 | Anti-corruption layers for every provider |
| TECH_STACK — Backend, India integrations | Libraries and providers |

### Deliverables

- **Object storage**: `ObjectStore` interface, S3 adapter (R2 and MinIO), pre-signed
  PUT/GET, server-assigned keys, SHA-256 verification, `status='pending'` sweep,
  tombstone-then-purge deletion
- **River worker**: `cmd/worker`, schedules, idempotency keys, advisory locks, retries
  with backoff
- **`MessageChannel` interface** with a **WhatsApp adapter built**, and **email built**
  (it is the OTP fallback — not optional), **SMS stubbed**
- `message_templates` — org-scoped, provider template name, category, language, parameter
  schema, DLT fields null for now
- Outbox dispatcher → `notification_deliveries`, recording `wamid` and status transitions
- **Webhook handler with the three-case `resolveOrg`** from CHANNEL_STRATEGY Part 3
- `conversation_sessions` with the 24-hour service window
- Per-society and per-resident send caps, Redis-backed
- Gotenberg adapter for PDF

**Deferred to Release 1.0:** partner `api_keys` and outbound `webhook_subscriptions`.
Nothing integrates with CivicSync yet, and the outbox and callback machinery they build
on is already here. Removes ~2 days.

### Exit criteria

- [ ] A file round-trips to MinIO by pre-signed URL — **bytes never pass through the API**
- [ ] Uploading with a mismatched SHA-256 is rejected
- [ ] An abandoned `pending` upload is swept
- [ ] A job scheduled twice for the same business key runs once
- [ ] A job survives a worker restart mid-run
- [ ] A WhatsApp template message is delivered to a real handset, and its status webhook
      is recorded against the correct org
- [ ] An inbound reply resolves to the right org via `party_contacts`
- [ ] Gotenberg renders an HTML template to PDF and stores it in object storage

### Review checkpoint

The pre-signed upload flow and the webhook resolution logic. Both are easy to get subtly
wrong and expensive to fix once data exists.

### Parallel, non-code

Remaining WhatsApp templates submitted · Razorpay Partner onboarding started

---

# Packets 04–16 — outline

Expanded into full detail as each is reached. Estimates and dates from
[RELEASE_PLAN.md](RELEASE_PLAN.md) Part 3.

---

# RELEASE 0.5 — Association Core

Admin-only. Books, not billing. The association's Excel ledger is the thing being
replaced.

---

## Packet 04 — Admin shell + Master Data Console · 10 days · early Dec 2026

One registry-driven UI giving every master entity CRUD, effective dating,
activate/deactivate, reorder and change history — so no later packet builds a
configuration screen.

**Required reading:** TECH_STACK (Admin console) · STANDARDS §5, §6, §10 (keyset
pagination, server-side everything) · MODULE_REGISTER ("The Master Data Console")

**Release 0.5 trim:** defer CSV import/export and impact analysis to Release 1.0. Ships
list, create, edit, activate/deactivate, reorder, history.

**Exit:** every master entity from Packet 01 is manageable without a bespoke screen · a
new master entity needs one registry row, no new UI · lists are server-paginated with
keyset cursors, with filter, sort and grouping · usable on a phone browser.

> **Demo this to the association in December**, empty as it is. Four silent months is the
> biggest non-technical risk in the plan.

---

## Packet 05 — Registry + ETL pass 1 · 15 days · early Jan 2027 — **HANDS ON**

**The hinge packet, and the association's first real use.** Blocks, unit types, units,
parties, contacts, **title, occupancy, association membership** — plus migration of the
370 members and the Registry Verification worklist.

**Required reading:** REGISTRY_OWNERSHIP_MODEL — **all of it** · ARCHITECTURE_DDD §1, §3
· legacy/V1_DATA_FINDINGS §"Property structure" and §"Migration impact" ·
DATA_PROVENANCE

**This ETL is production, not a fixture.** From here the migrated data is the
association's real record.

**Exit:** 370 members reconciled into parties, units, ownerships, occupancies and
memberships · every migrated row carries `source_system`, `source_id` and
`source_confidence='assumed'` · **password hashes are NOT migrated** — authentication is
WhatsApp OTP and the prototype's hashes have no continuity value · temporal `EXCLUDE`
constraints reject overlaps in test · the verification worklist is usable by the
committee · **you have reviewed 20 randomly sampled units side by side against the v1
snapshot**.

---

## Packet 06 — Documents · 7 days · mid Jan 2027

Configurable document types, upload to R2, verification workflow, expiry, retention —
and the **mandatory-document gate**.

**Required reading:** STANDARDS §2 · MODULE_REGISTER (`documents`) ·
legacy/FUNCTIONAL_REFERENCE ("Legal Document Verification")

**Why this matters now:** the **BBA (Builder Buyer Agreement) is each member's proof of
allotment for the NBCC claim process.** This is the association's most valuable near-term
use of the platform, not a compliance checkbox.

**Exit:** document requirements are configurable per membership or occupancy type, not
hardcoded · a member record cannot reach "complete" without its mandatory documents
verified · downloads are permission-checked signed URLs · a retention job honours policy ·
**no document migration** — v1's eight are test data.

---

## Packet 07 — Books + opening balances · 16 days · **late Feb 2027** — **EXCEL RETIRED**

**Bookkeeping, not billing.** The association records what came in and what went out and
produces statements an auditor accepts.

**Built before notices deliberately** — it is the only packet with a hard external date
(1 April 2027, the start of FY 2027-28), and this ordering buys five weeks of parallel
run instead of three.

**Required reading:** ADR-0003 · STANDARDS §4 · ARCHITECTURE_DDD §3, §4 ·
COLLECTION_STRATEGY §5 (payment modes) · legacy/V1_DATA_FINDINGS ("Money") ·
**CUTOVER_PLAN.md** · the association's Excel workbook (obtained November)

### The approach: opening balances, not history

The prototype holds **receipts but no expenses** — an inherently unbalanced record — and
the committee's expense history is incomplete. History therefore **is not migrated into
the ledger**. Instead the books open at a cut-off with a certified statement of affairs.
The ledger balances by construction, because the balancing figure is itself an account:

```
Opening entry, 1 April 2027
  Dr  Bank — current account            (per bank statement)
  Dr  Cash in hand                      (treasurer's certified count)
  Dr  Receivable from members           (nil, unless the committee can state it)
      Cr  Payable to vendors
      Cr  Advances received from members
      Cr  General Fund                  ← derived balancing figure, not certified
```

**Design the chart of accounts properly and map their Excel into it.** Do not mirror the
workbook's structure — it is messy, and mirroring it imports the mess.

### The legacy archive — deliberately not `receipts`

The 955 prototype payments go into a **separate `legacy_payment_records` table**, outside
the finance aggregates entirely. A `Receipt` in the new system is a document that posts to
the ledger; these do not post. Keeping them apart means no query, statement or total
carries an "except the legacy ones" caveat that someone eventually forgets.

Surfaced on the member page and in exports as a labelled section: *"Payment records prior
to 1 April 2027 — historical reference, not part of the current books."*

### Scope

- Chart of accounts: income and expense heads, master data
- `unit_accounts`, `ledger_entries` — append-only, balance derived
- **Opening entry** with the six components above, and a General Fund account
- **Manual receipt entry** by the treasurer: date, member, mode, amount, reference
- **Manual expense entry** — no approval workflow yet, that is Packet 11
- `payment_modes` seeded; **`payment_processing_fee` charge head seeded** so the ledger
  can express a gateway fee before any gateway exists
- **ETL: 955 legacy payments → `legacy_payment_records`**, read-only
- Statements: **Receipts & Payments**, **Income & Expenditure**, **Balance Sheet**
- Per-member ledger statement, with the legacy section clearly separated
- Export to XLSX via the Packet 03 machinery

### Exit criteria

- [ ] `legacy_payment_records` totals **₹10,72,892.00 exactly**, 955 rows, every v1
      payment id present once as a `source_id` — migration fidelity
- [ ] **No legacy record posts to the ledger.** Proven by test: ledger totals are
      unaffected by the archive
- [ ] The opening entry balances, and the General Fund is derived rather than entered
- [ ] The three statements agree with each other and with the ledger
- [ ] `period` strings are parsed into `financial_year_id` + `charge_head_id` with the
      original preserved in `source_metadata`
- [ ] **The cut-over certificate is generated** — a one-page statement of affairs as at
      the cut-off date, referencing the bank statement, exportable as PDF and storable in
      the document vault
- [ ] **The treasurer has reproduced one month of their Excel from CivicSync and
      confirmed it matches**
- [ ] Nothing is hard-deleted; corrections are reversing entries

> The last two are the real exit. Until the treasurer trusts the numbers and the committee
> has a signed certificate, the Excel does not go away.

**See `CUTOVER_PLAN.md`** for the committee approvals, parallel run and go-live sequence
that surround this packet.

---

## Packet 08 — Notices · 6 days · early Mar 2027

**Required reading:** CHANNEL_STRATEGY — all · MODULE_REGISTER (`communication`)

**Release 0.5 trim:** no resident portal to read notices in, so delivery is WhatsApp plus
an admin-side board. Audience selection, delivery receipts and opt-out all build now.

**Moved after Books** to protect the 1 April date. The association has a WhatsApp group
and can live without a notice board for another month; it cannot live without a clean
financial-year opening.

**Exit:** a notice delivers over WhatsApp with a delivery receipt recorded · audiences are
computed from membership and occupancy, not a static list · per-category opt-out is
honoured · send caps enforced.

---

**← RELEASE 0.5**

---

# RELEASE 1.0 — Operating Society

Begins when NBCC handover progresses and the association starts running a building.

---

## Packet 09 — Billing & collection · 18 days · mid Apr 2027

Fee schedules, invoices, invoice lines, billing runs, payment intents, zero-cost UPI,
bank statement reconciliation, adjustments, dunning policies and the escalation job.

**Required reading:** **COLLECTION_STRATEGY — all** · COMMERCIAL_STRUCTURE §4 (**money
settles to the society, never Pivot**) · STANDARDS §11 · REGISTRY_OWNERSHIP_MODEL §6
(`liable_party`) · legacy/FUNCTIONAL_REFERENCE ("Payment Escalation")

**Exit:** a billing run produces invoices for every liable unit and is a no-op run twice ·
a UPI intent link opens a real UPI app with the amount locked · an expired intent cannot
be paid at a stale amount · a reported payment **never settles on the resident's word
alone** · statement import auto-matches on UTR + amount + date · the reconciliation
console handles all four exception types including a twice-scanned QR · **the
`CollectionProvider` port, `provider_callbacks` pipeline and conformance suite are built,
with plain UPI passing** · the dunning job is provably idempotent.

---

## Packet 10 — Workflow engine + transfer and tenancy · 10 days · early May 2027

**Required reading:** REGISTRY_OWNERSHIP_MODEL §5 · MODULE_REGISTER (`platform.workflow`)

**Exit:** approval chains configurable per society without code · an ownership transfer
cannot go effective with unsettled dues unless overridden with a recorded reason · the
effective step is atomic · tenancy activation closes the prior occupancy and grants
correctly scoped access.

---

## Packet 11 — Expense vouchers · 7 days · late May 2027

**Required reading:** MODULE_REGISTER (`expense`) · legacy/FUNCTIONAL_REFERENCE
("Expense Vouchers")

**Exit:** approval chains configurable by amount threshold · only cancelled vouchers
deletable · printable voucher via Gotenberg · numbering from `number_series` · vouchers
post to the ledger built in Packet 08.

---

## Packet 12 — Reporting & dashboards · 8 days · early Jun 2027

**Required reading:** STANDARDS §10, §13 · MODULE_REGISTER (`reporting`)

**Exit:** a 20,000-row export runs as a background job returning a signed URL · real XLSX
and PDF · reports read module query interfaces, not raw tables · member register, dues
ageing, collection summary and voucher register all produced.

---

## Packet 13 — Resident portal · 8 days · late Jun 2027

Web UI over the resident API built in Packet 02. **Frontend only** — if this packet needs
backend work, Packet 02 was done wrong.

**Required reading:** TECH_STACK (Admin console — same stack) · the OpenAPI spec

**Exit:** a resident logs in by WhatsApp OTP and sees their unit, documents, ledger,
notices and dues · a multi-unit owner can switch units · a tenant sees their unit and
nothing of the society's finances · works on a phone browser.

---

## Packet 14 — Hardening · 10 days · mid Jul 2027

**Required reading:** STANDARDS §13 (budgets) · COMMERCIAL_STRUCTURE §5 (DPDP) ·
ADR-0001 ("Consequences")

**Exit:** k6 load test against a seeded 20,000-unit dataset meets the §13 budgets ·
`EXPLAIN` assertions pass on critical queries · `govulncheck` and `gitleaks` clean ·
**a per-society filtered restore rehearsed end to end** · DPDP review complete: consent,
retention, erasure, breach runbook · operations runbook written · committee UAT signed
off.

---

## Packet 15 — General availability · 5 days · late Jul 2027 — **RELEASE 1.0**

**Exit:** tagged `v1.0.0` · v1 snapshot retained and verified · rollback path exercised,
not merely documented · hypercare for two weeks.

---

## Packet 16 — Flutter resident app · 20 days · early Sep 2027 — **RELEASE 1.1**

Built after go-live, against a stable API and real usage feedback. **Also carries the
Razorpay adapter** deferred from Packet 09 — it must pass the conformance suite written
there — and **Android auto-capture of the UPI response** (COLLECTION_STRATEGY §6.2). iOS
and web keep manual UTR entry; no library can change that.

**Required reading:** TECH_STACK (Mobile) · ADR-0002 · CHANNEL_STRATEGY Part 1

**Exit:** onboarding with the full OTP fallback chain · unit switcher for multi-unit
owners · dues, payment, receipts, documents, notices · push via FCM · offline-tolerant
caching · on TestFlight and Play internal testing · used by real residents.

---

## Progress log

Append after each packet. What actually happened, not what was planned.

| Packet | Started | Merged | Est. | Actual | Notes |
| --- | --- | --- | ---: | ---: | --- |
| 00 | 2026-09-01 | 2026-09-01 | 5 | ~1 | Merged as `755c2f7`. **Not a fair velocity signal** — Claude wrote the scaffolding and Go; from Packet 01 the domain code is hand-written, so treat 5 days as the realistic baseline. Four plan corrections, all fixed in the packet: PG18 wants one mount at `/var/lib/postgresql` not `/data`; host port moved to 5433 (Homebrew PostgreSQL held 5432 and shadowed the container); Go module path `.../civicsync/api` not `.../CivicSync/api`; `golangci-lint-action` replaced by a pinned binary + `make lint` so CI runs the same command as local. Fiber v3 compiled first time. |
