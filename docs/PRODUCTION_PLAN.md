# CivicSync — Production Rebuild Plan (v2)

**Status:** Proposed · **Date:** 25 Aug 2026 · **Supersedes:** prototype architecture described in `AI_HANDOFF.md`

This document is the single source of truth for the rebuild. It defines the target
architecture, the tenancy model, the ERP master-data doctrine, the domain model, the
data-migration contract, and the phased build order.

Read this before writing any v2 code. Each phase later gets its own **Build Packet**
containing concrete DDL, Go/TypeScript/Dart code, and acceptance tests.

---

## 0. What we are building

CivicSync v2 is a **multi-society residential community operations platform**, sold as a
product to many Resident Welfare Associations. Three surfaces:

| Surface | Users | Technology |
| --- | --- | --- |
| **Admin console** | Office bearers, committee, society staff | Responsive React web app — desktop, tablet, phone browser |
| **Resident app** | Residents (owners + tenants) | Flutter, iOS + Android |
| **API / platform** | Both surfaces, integrations, devices | Go, PostgreSQL |

Product trajectory (design seams now, build later): visitor & gate management, parking
access control, smart electricity meter reads and consumption billing, amenity booking,
helpdesk, staff management.

### The three rules that govern every decision

1. **No hardcoding.** Every enum, list, label, threshold, rate, series and permission is
   master data owned by the society, not a constant in Go or TypeScript.
2. **Data fidelity.** The prototype's data is live. Nothing is lost, altered or
   re-interpreted during migration without an explicit, reviewed mapping rule.
3. **The database is the last line of defence.** Tenant isolation, referential integrity
   and financial invariants are enforced in PostgreSQL, not only in application code.

---

## 1. Tenancy — the recommendation

You asked what I actually think, given: many societies, full data privacy, no cost
over-runs, and a MyGate/Park+ ambition. My recommendation:

> **Pooled multi-tenancy: one PostgreSQL cluster, one shared schema, `org_id` on every
> tenant-owned table, enforced by PostgreSQL Row-Level Security — plus a designed-in
> escape hatch to move any single society onto a dedicated database without changing
> a line of business logic.**

This is the model Linear, Vanta, and most modern B2B SaaS run. Here is the reasoning,
including where it costs you something.

### Why pooled, not database-per-society

**Cost.** A database-per-society model scales cost linearly with customers. Fifty
societies = 50 databases, 50 connection pools, 50 migration runs per release, 50 backup
schedules, 50 restore rehearsals. At the price point an Indian RWA will pay
(₹15–40 per unit per month), linear infrastructure cost destroys the margin before you
reach 20 societies. Pooled multi-tenancy makes marginal cost of the 51st society
approximately zero.

**Operations.** One migration run, one monitoring dashboard, one incident. You are a
small team writing code by hand. Ops load that grows linearly with sales is the thing
that kills solo-founder SaaS, not the code.

**The IoT roadmap makes it non-negotiable.** Smart meter reads and gate/ANPR events are
high-frequency time-series. One meter per unit at 15-minute granularity is ~35,000 rows
per unit per year. These need declarative time-partitioned tables (or TimescaleDB). With
schema-per-society you would maintain N × 12 partitions per year and N sets of retention
policies. With a shared schema, you maintain one partitioned table set, tagged by
`org_id`. This alone rules out schema-per-tenant for your roadmap.

### How privacy is actually guaranteed

"Shared database" must not mean "one bad WHERE clause away from a leak." Five layers:

1. **Row-Level Security, always on.** Every tenant table gets
   `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` **and** `FORCE ROW LEVEL SECURITY`, with a
   policy `USING (org_id = current_setting('app.org_id')::uuid)`.
2. **The application connects as a non-owner, non-superuser role** (`civicsync_app`) that
   has no `BYPASSRLS`. It is structurally incapable of cross-tenant reads. Migrations and
   the control plane use a separate role.
3. **Tenant context is set per transaction**, never per connection:
   `SET LOCAL app.org_id = $1` as the first statement inside every request transaction.
   `SET LOCAL` is transaction-scoped, so it is safe under PgBouncer transaction pooling —
   which is what keeps your connection costs down. A request that fails to set context
   sees zero rows, not all rows. That is the correct failure mode.
4. **Application-layer scoping is still mandatory.** RLS is defence in depth, not a
   substitute for `WHERE org_id = $1`. Both, always.
5. **Encryption and storage isolation.** Sensitive columns (identity numbers, integration
   secrets, gateway keys) use envelope encryption with a **per-organization data key**
   wrapped by a master key in a KMS. Object storage uses a per-tenant key prefix and only
   ever serves short-lived signed URLs. A tenant's documents are cryptographically
   separable even inside a shared bucket.

Layers 1–3 mean an application bug cannot leak data. Layer 5 means even a database dump
does not expose the sensitive fields of every society at once.

### The escape hatch — why this decision is not a trap

Because every row carries `org_id`, moving a society to its own database is a filtered
`pg_dump`, not a re-architecture. To make this operational from day one:

- The **control plane** (a separate schema, `control`) holds a `tenants` directory:
  `org_id`, slug, plan, status, **and the database connection identifier**.
- The API resolves tenant → connection pool through that directory at request time.
  Today every tenant resolves to the same pool. Tomorrow, a bank-grade or
  large enterprise society resolves to its own — same code path, different row.

This gives you a real commercial answer when a society's committee asks "is our data
mixed with other societies?": *"Logically isolated at the database level by mandatory
row-level security, with per-society encryption keys — and on the Enterprise plan, a
physically dedicated database."* That is a sellable answer, and an upsell.

### What this costs you

- **Discipline.** Every new table needs `org_id`, an index leading with `org_id`, an RLS
  policy, and a test that proves cross-tenant reads return nothing. This is mechanical —
  we will enforce it with a CI check that fails the build on any tenant table lacking a
  policy.
- **One noisy neighbour risk.** Mitigated by per-tenant rate limits and connection caps,
  and by the escape hatch for genuinely large societies.
- **Backups are cluster-wide.** Per-society point-in-time restore requires a filtered
  restore procedure. We will script and rehearse it in Phase 8 rather than discovering it
  during an incident.

**Decision: adopt pooled multi-tenancy with RLS. This is the default assumption for the
rest of this document.**

---

## 2. Technology stack

| Layer | Choice | Why |
| --- | --- | --- |
| API language | Go 1.23+ | Your existing knowledge; low memory cost matters for margin |
| HTTP router | `chi` (stdlib `net/http`) | No framework lock-in, standard middleware, trivially testable. Gin remains acceptable if you prefer familiarity — the layering matters more than the router |
| DB driver | `pgx/v5` | Already in use, best-in-class |
| Query layer | `sqlc` | Generates typed Go from real SQL. Prevents the 2,300-line `postgres.go` from happening again — SQL lives in `.sql` files, review is readable |
| Migrations | `golang-migrate` | Already in use, keep it. **`RepairCurrentSchema` is deleted** — migrations become the only schema authority |
| Background jobs | **River** (Postgres-backed queue) | Escalation, billing runs, message outbox, meter ingest. Postgres-backed means **no Redis**, no extra infrastructure cost, and jobs are transactional with your data |
| Auth | JWT access (15 min) + rotating refresh tokens in DB | Fixes the prototype's 24-hour non-revocable token |
| Object storage | Cloudflare R2 (S3-compatible) | Zero egress fees; the cheapest correct answer for document-heavy workloads |
| Observability | `log/slog` structured logs + OpenTelemetry traces | |
| Testing | `testcontainers-go` + real PostgreSQL | RLS, triggers and constraints cannot be tested against mocks |
| Admin web | React 18 + Vite + TypeScript, TanStack Query + TanStack Router | |
| Admin design system | **Keep IBM Carbon** | You have invested in it, and it is genuinely the right family for dense ERP tables and forms. Extend it, do not replace it |
| Mobile | Flutter + Riverpod + `dio` + `go_router` + `freezed` | Your choice; good one for a consumer-facing resident app |
| API contract | **OpenAPI 3.1, contract-first** | Non-negotiable given Flutter — see below |
| CI | GitHub Actions | |

### Contract-first is mandatory here

Because the resident app is Dart and the admin is TypeScript, there is no shared type
system. The OpenAPI specification becomes the shared type system:

```
contracts/openapi.yaml           ← hand-written, reviewed, the source of truth
   ├── oapi-codegen         → api/internal/http/gen/       (Go server interfaces + types)
   ├── orval                → admin/src/api/gen/           (TS client + TanStack Query hooks)
   └── openapi-generator    → mobile/lib/api/gen/          (Dart client)
```

CI fails if generated code is out of date with the spec. This one rule eliminates the
entire class of "the mobile app sends a field the backend renamed" bugs, and it is why
`unknown`/`any` API models will not recur.

### Repository layout — a monorepo

```
civicsync/
├── contracts/          OpenAPI spec, JSON schemas, codegen config
├── db/
│   ├── migrations/     golang-migrate SQL (the ONLY schema authority)
│   ├── queries/        sqlc source SQL
│   └── seeds/          system master-data seeds
├── api/                Go service
│   ├── cmd/
│   │   ├── api/            HTTP server
│   │   ├── worker/         River job worker
│   │   └── migrate-legacy/ v1 → v2 ETL
│   └── internal/
│       ├── platform/   tenancy, auth, rbac, audit, config, storage, kms, jobs
│       ├── domain/     pure business types + rules, no SQL, no HTTP
│       ├── app/        use-cases / services (orchestration, transactions)
│       ├── store/      sqlc-generated + hand-written repositories
│       └── http/       handlers, middleware, generated server interfaces
├── admin/              React admin console
├── mobile/             Flutter resident app
├── ops/                Docker Compose, Terraform, runbooks, backup scripts
└── docs/               this plan, ADRs, functional reference
```

**Dependency rule, enforced in CI:** `http → app → domain` and `app → store`.
`domain` imports nothing from the other three. This is the single structural rule that
prevents the prototype's collapse of everything into one repository file.

---

## 3. The ERP doctrine — how "no hardcoding" is implemented

The prototype hardcodes roughly 40 lists across Go constants, SQL `CHECK` constraints and
TypeScript literals: organization roles, document types, voucher types, voucher statuses,
advice statuses, escalation levels, payment providers, towers, unit-number rules, phone
country, financial-year rules, alert types. Every one of these becomes data.

### Four distinct categories — do not confuse them

**1. System codes (closed, code-bearing).**
A small set of values that application logic genuinely branches on — e.g. an invoice is
`open` / `settled` / `written_off`. These live in catalog tables with a stable `code`
column and `is_system = true`. Code references the `code`, never the label. Societies may
**relabel** them and may add non-system siblings, but cannot delete or repurpose them.

**2. Master data (open, society-owned).**
Fully editable by the society: blocks, unit types, document types, charge heads, expense
categories, vendor list, organization roles, parking zones, amenity types, meter types.
Every master table shares the same shape:

```sql
id uuid pk, org_id uuid, code text, name text, description text,
sort_order int, is_system bool, is_active bool,
effective_from date, effective_to date,
attributes jsonb,                          -- per-society extra fields
created_at, created_by, updated_at, updated_by
UNIQUE (org_id, code)
```

`is_active` replaces deletion — master data is **never hard-deleted**, because historical
records reference it. `effective_from/to` allows a society to change a rate or category
from a date without corrupting history.

**3. Parameters (typed settings).**
Two tables instead of ever-growing settings columns:

- `setting_definitions` — key, data type, validation JSON-schema, default, scope
  (`platform` / `org` / `block`), UI group, help text, `is_secret`
- `setting_values` — `org_id`, key, value (jsonb), effective dates, updated_by

Adding a new configurable parameter becomes a seed row plus a UI that renders itself from
the definition. It never requires a schema migration or a new form field.

**4. Permissions (the biggest change from the prototype).**
Today authorization is `if role == "super_admin" || orgRole == "treasurer"` scattered
across handlers. In v2:

```
permissions        (code, module, description)         -- e.g. 'finance.invoice.create'
roles              (org_id, code, name, is_system)     -- President, Treasurer, Guard, Custom
role_permissions   (role_id, permission_id)
memberships        (user_id, org_id, role_id, unit_id?, valid_from, valid_to)
```

Handlers declare `RequirePermission("finance.invoice.create")`. A society composes its own
roles in the admin console. The prototype's two-level role model (app role + organization
role) collapses into one composable model, and its exact current behaviour is reproduced
as **seeded system roles** so nothing changes for the existing society on day one.

**5. Document numbering series.**
Voucher numbers, receipt numbers, invoice numbers are ERP artefacts. One table:
`number_series (org_id, doc_type, prefix, suffix, padding, next_value, reset_period,
format_template)`, allocated inside the same transaction as the document.

### The Master Data Console

The admin app gets a dedicated **Configuration** module. Every master entity is rendered
from a shared registry, giving each one, for free: list + filter + sort, create/edit,
activate/deactivate, effective dating, reorder, CSV import/export, change history, and a
"where is this used?" impact view before deactivation.

Adding a new master entity = one migration + one registry entry, not a new screen.

---

## 4. Domain model v2

### 4.1 The most important structural fix: separate person from property

The prototype models a member as a person *with* a `tower` and `flat_no` — one row, one
person, one flat, forever. That model cannot express: a tenant, an owner who rents out,
an owner of two flats, a flat sold to a new owner, a resident family, or a co-owner. It
also makes every future module (gate passes, parking, meters) impossible to attach
correctly, because those attach to a **unit**, not a person.

```
organizations
  └── blocks                  (was: "tower", now master data with attributes)
        └── units             (was: "flat_no"; unit_type, floor, carpet_area, parking_slots)
              └── occupancies (unit × party × relationship × valid_from/valid_to)

parties (people)              name, contacts, KYC, identity refs
  └── party_contacts          (phone/email rows, each with its own verification state)
  └── users                   login identity, 0..1 per party
```

`occupancies.relationship` is master data: owner, co-owner, tenant, resident family
member, power-of-attorney. `valid_from/valid_to` means unit history is a first-class
record — you can answer "who lived in A-402 in March 2025" forever. Dues attach to the
**unit**; the payer is resolved through the occupancy that is valid on the charge date.

This is the change that makes the MyGate-class roadmap possible. It is also the migration
step that needs the most care (Section 5).

### 4.2 The second structural fix: a member ledger instead of statuses on a row

The prototype tracks money as a `status` column moving through
`pending → level1 → level2 → level3 → lapsed → reinstate_pending → reinstate_paid`, with
escalation mutating rows during read requests, and a "delete the linked lapsed row"
side effect on reinstatement payment. That is not auditable and it destroys history by
design.

v2 finance:

```
charge_heads        master data: maintenance, water, corpus, penalty, parking, electricity
fee_schedules       charge_head × unit_type/block × amount or rate × effective period
billing_runs        a periodic, idempotent job that generates invoices
invoices            (org, unit, period, due_date, status) — "payment advice" in your language
invoice_lines       (charge_head, description, qty, rate, amount, tax)
ledger_entries      append-only: every debit and credit against a unit account
receipts            money actually received (cash/cheque/UPI/gateway), with number series
payment_attempts    gateway orders, webhooks, signature verification, reconciliation state
adjustments         waivers, write-offs, credit notes — with reason + approver
dunning_policies    master data: escalation stages, penalty %, timing, terminal action
dunning_events      append-only record of every escalation applied to an invoice
```

Outstanding balance becomes a **derived value** (sum of ledger entries), not a status
someone forgot to update. Escalation becomes a **scheduled idempotent job** that writes a
`dunning_event` and a penalty `ledger_entry` — it never runs inside a read request, and
running it twice on the same day is a no-op. The "lapsed / reinstate" behaviour is
preserved exactly, but as ledger relationships and account status, with nothing deleted.

**Nothing in the finance module is ever hard-deleted.** Corrections are reversing entries.
This is the difference between a prototype and a system an auditor will accept.

### 4.3 Full module map

| Module | v2 status | Notes |
| --- | --- | --- |
| Platform: tenancy, RBAC, master data, settings, audit, jobs, files | **Build first** | Everything else depends on it |
| Property registry: blocks, units, occupancies, parties | Build | Replaces `members.tower/flat_no` |
| Identity & access: users, sessions, MFA/OTP, devices | Build | Real OTP, refresh tokens, rate limiting |
| Documents & verification | Port + object storage | Configurable doc types and approval chains |
| Finance | Rebuild on ledger | Highest-value module |
| Expense vouchers & approvals | Rebuild on generic workflow engine | Approval chain becomes configurable |
| Communications: notices, templates, outbox | Rebuild | Multi-channel with retry + delivery receipts |
| Reporting & exports | Rebuild server-side | Real XLSX/PDF, not `document.write` |
| Visitors & gate passes | **Phase 9** | Seams designed now: attaches to `units` |
| Parking | Phase 9 | `parking_slots` already referenced from `units` |
| Smart meters & consumption billing | Phase 10 | Partitioned time-series; billing via `charge_heads` |
| Amenities, helpdesk, staff | Phase 10+ | |

### 4.4 Cross-cutting platform services

- **Audit trail.** Every mutation writes `audit_log` (org, actor, entity, action, before,
  after, request id, IP). Not optional, not per-module.
- **Outbox pattern.** All outbound messages (WhatsApp, SMS, email, push) are written to an
  `outbox` table in the same transaction as the business change, then dispatched by a
  worker with retry and backoff. This is what makes notifications reliable — the
  prototype's fire-and-forget goroutines lose messages on restart.
- **Idempotency.** Every mutating endpoint accepts an `Idempotency-Key`. Essential for a
  mobile app on Indian networks where a request may be sent twice.
- **Soft delete + retention.** `deleted_at` everywhere, with a retention job driven by
  configurable policy (DPDP Act compliance, Section 7).

---

## 5. Data migration with full fidelity

Non-negotiable: **the prototype database is production data.** The migration is a
first-class engineering deliverable with its own tests, not a script run at cutover.

### 5.1 Principles

1. **The v1 database is never written to.** Read-only source, forever archived.
2. **Every migrated row records its origin.** All v2 tables carry
   `source_system text, source_id text, source_hash text`. Traceability is permanent.
3. **The ETL is idempotent and re-runnable.** Keyed on `(source_system, source_id)`.
   Running it twice produces the same result.
4. **Reconciliation gates the cutover.** A migration is not "done" — it is either
   *reconciled* (every check green) or *blocked*.
5. **Rehearse three times** against a copy before touching real cutover.

### 5.2 Step 1 — inventory (do this first, this week)

Run this against the live `bwa_hq` database and send me the output. It shapes every
mapping rule below.

```sql
-- civicsync v1 inventory
SELECT 'members'                  t, count(*) FROM members
UNION ALL SELECT 'members_deleted',   count(*) FROM members WHERE deleted_at IS NOT NULL
UNION ALL SELECT 'users',             count(*) FROM users
UNION ALL SELECT 'member_documents',  count(*) FROM member_documents
UNION ALL SELECT 'docs_with_bytea',   count(*) FROM member_documents WHERE file_data IS NOT NULL
UNION ALL SELECT 'docs_path_only',    count(*) FROM member_documents WHERE file_data IS NULL
UNION ALL SELECT 'payment_requests',  count(*) FROM payment_requests
UNION ALL SELECT 'advice_rows',       count(*) FROM payment_request_members
UNION ALL SELECT 'payments',          count(*) FROM payments
UNION ALL SELECT 'expense_vouchers',  count(*) FROM expense_vouchers
UNION ALL SELECT 'notices',           count(*) FROM notices
UNION ALL SELECT 'activity_logs',     count(*) FROM activity_logs
ORDER BY 1;

-- distributions that drive mapping rules
SELECT status, count(*), sum(amount) FROM payment_request_members GROUP BY 1 ORDER BY 1;
SELECT provider, status, count(*), sum(amount) FROM payments GROUP BY 1,2 ORDER BY 1,2;
SELECT tower, count(*) FROM members WHERE deleted_at IS NULL GROUP BY 1 ORDER BY 1;
SELECT document_type, status, count(*) FROM member_documents GROUP BY 1,2 ORDER BY 1,2;
SELECT status, count(*) FROM expense_vouchers GROUP BY 1;

-- data-quality probes (each of these is a migration decision)
SELECT count(*) FROM members WHERE flat_no !~ '^[0-9]+$';
SELECT count(*) FROM members WHERE phone IS NULL OR phone = '' OR length(phone) <> 10;
SELECT count(*) FROM members WHERE email IS NULL OR email = '' OR email NOT LIKE '%@%';
SELECT count(*) FROM members WHERE aadhaar_number <> '';
SELECT count(*) FROM payment_request_members prm
  LEFT JOIN members m ON m.id = prm.member_id WHERE m.id IS NULL;
SELECT count(*) FROM payments p
  LEFT JOIN payment_request_members prm ON prm.id = p.payment_request_member_id
  WHERE p.payment_request_member_id IS NOT NULL AND prm.id IS NULL;
SELECT count(*) FROM payment_request_members
  WHERE status IN ('reinstate_pending','reinstate_paid')
    AND reinstates_payment_request_member_id IS NULL;
```

Also produce the immutable snapshot that everything is verified against:

```bash
pg_dump --format=custom --no-owner --file=civicsync_v1_$(date +%F).dump "$DB_URL"
shasum -a 256 civicsync_v1_*.dump > civicsync_v1_$(date +%F).sha256
```

### 5.3 Step 2 — mapping rules (the ones that need your judgement)

| v1 | v2 | Rule and the decision you must confirm |
| --- | --- | --- |
| `members.tower` | `blocks` | Distinct non-deleted towers become blocks. **Confirm the display names.** |
| `members.flat_no` | `units` | One unit per `(tower, flat_no)`, including for soft-deleted members, so history keeps its unit. Non-numeric flat numbers (probe above) get a manual mapping table |
| `members` (person part) | `parties` | Name, contacts, KYC |
| `members` (link part) | `occupancies` | Every existing member becomes relationship `owner`, `valid_from = members.created_at`, `valid_to = deleted_at`. **Confirm: are any current members actually tenants?** If yes, we need a list before migrating |
| `members.status` | `occupancies` validity + `unit_accounts.status` | Active/inactive is an account state, not a person state |
| `members.aadhaar_number` | `party_identity_refs`, encrypted | **Recommend storing only last 4 digits + document image.** See Section 7 |
| `users` | `users` + `memberships` | App role + org role → seeded system role. Bcrypt hashes carry over **unchanged** — no one is forced to reset their password |
| `member_documents` | `documents` in R2 | `file_data` bytea → R2 object; `file_path`-only rows → read from `UPLOAD_DIR` and upload. SHA-256 recorded for every file. **Any row with neither is reported, never silently dropped** |
| `payment_requests` + `payment_request_members` | `invoices` + `invoice_lines` + `ledger_entries` | One advice row → one invoice with one line against a `maintenance` charge head |
| advice `status` | invoice status + `dunning_events` | `pending`→open; `level1/2/3_esc`→open + N dunning events reconstructed from timestamps; `paid`→settled; `cancelled`→cancelled; `lapsed`→open + account `lapsed`; `reinstate_*`→open/settled with `reinstates_invoice_id` link preserved |
| escalation penalty amounts | `ledger_entries` of type `penalty` | The compounded amount currently baked into `amount` is split into principal + penalty **where reconstructible**; where it is not, it is migrated as a single line with a note. **This needs the inventory output to decide** |
| `payments` | `receipts` + `ledger_entries` + `payment_attempts` | `provider='legacy'` preserved as receipt mode `legacy_import` |
| `expense_vouchers` | `expense_vouchers` + `approval_instances` | Voucher types and statuses become master data seeded from the distinct values found |
| `notices` | `announcements` + attachments in R2 | |
| `activity_logs` | `audit_log` | Migrated verbatim into an archive partition |
| singleton settings tables | `setting_values` | Each column becomes one definition + one value row |

### 5.4 Step 3 — reconciliation report

`cmd/migrate-legacy --verify` produces a report that must be **all green** before cutover:

- Row counts: v1 vs v2 per entity, including soft-deleted
- **Money:** total invoiced, total received, total outstanding — v1 sum must equal v2
  ledger sum **to the paisa**, overall and per unit
- Per-status counts match the v1 distribution after applying mapping rules
- Every v1 id appears exactly once as a `source_id` in v2
- Every v1 document has a v2 object with a matching SHA-256, or an explicit exception row
- Zero orphaned references
- Every user can still authenticate (hash comparison test against a known set)
- Spot-check: 20 randomly sampled members rendered side by side, v1 vs v2, reviewed by you

### 5.5 Step 4 — cutover

1. Rehearsal 1 on a restored copy — fix mapping bugs
2. Rehearsal 2 — reconciliation must be green
3. Rehearsal 3 — timed, scripted, with the rollback path exercised
4. Announce a maintenance window
5. Freeze v1 writes → final `pg_dump` → run ETL → run `--verify` → manual sign-off
6. Cut DNS/config to v2; keep v1 running read-only for 30 days
7. Rollback trigger: any red reconciliation check, or a sign-off you do not give

---

## 6. Build phases

Each phase ends with something demonstrable and tested. I will produce a **Build Packet**
per phase — DDL, code, tests, and a checklist — when you are ready to start it.

### Phase 0 — Foundation *(1 week)*
- Tag and archive the prototype; commit the outstanding WIP (migration 029) so nothing is lost
- Run the Section 5.2 inventory; take and checksum the v1 snapshot
- Create the v2 monorepo skeleton and the dependency-rule CI check
- Docker Compose: Postgres + MinIO (R2 stand-in) + mailpit, one command to a working dev environment
- CI: fmt, vet, lint, build, test, migration up/down check, RLS-policy coverage check
- Write ADR-001 (tenancy), ADR-002 (contract-first), ADR-003 (ledger-based finance)

**Exit:** `docker compose up` gives a working empty platform; CI is green.

### Phase 1 — Platform core *(3 weeks)*
Tenancy + RLS, control-plane schema, the master-data framework, settings framework, RBAC,
audit log, River worker, R2 storage adapter, KMS envelope encryption, OpenAPI skeleton and
codegen pipeline, structured errors.

**Exit:** two seeded societies exist; an automated test proves society A cannot read any
row belonging to society B, at the SQL level, with application code deliberately bypassed.

### Phase 2 — Identity & access *(2 weeks)*
Users, credentials, refresh-token rotation, real OTP (provider-neutral: MSG91 / WhatsApp /
SMTP behind one interface), rate limiting, lockout, device registration, permission
middleware. Admin login + resident login.

**Exit:** login works on web and from a Flutter smoke-test client; OTP is really delivered;
no code appears in an API response.

### Phase 3 — Property & people registry *(2 weeks)*
Blocks, unit types, units, parties, contacts, occupancies. Admin CRUD screens.
**First ETL pass** migrating members into this structure, with reconciliation.

**Exit:** the live society's members and flats exist in v2, reconciled, reviewed by you.

### Phase 4 — Documents *(1.5 weeks)*
Configurable document types, upload to R2 with checksum and virus-scan hook, configurable
verification workflow, signed-URL download with permission checks, retention policy.
Second ETL pass migrating documents.

**Exit:** every v1 document is in R2 with a matching hash; the activation gate works.

### Phase 5 — Finance core *(4 weeks — the big one)*
Charge heads, fee schedules, unit accounts, billing runs, invoices, ledger, receipts,
adjustments, dunning policies + the scheduled escalation job, Razorpay **with webhooks,
capture and reconciliation**, receipt numbering, statements.
Third ETL pass migrating all financial history.

**Exit:** money reconciles to the paisa against v1; a real ₹1 Razorpay payment completes
end to end including webhook; escalation runs as a job and is provably idempotent.

### Phase 6 — Operations modules *(3 weeks)*
Generic approval-workflow engine → expense vouchers rebuilt on it. Announcements with the
outbox + WhatsApp/SMS/email/push channels. Server-side XLSX and PDF reporting. Admin
dashboard.

**Exit:** vouchers, notices and reports work with configurable types and approval chains.

### Phase 7 — Admin console completion *(3 weeks, overlaps 5–6)*
Full responsive React app: shell, Master Data Console, all module screens, a rebuilt data
grid with **server-side** paging/filter/sort/export, role-driven navigation.

**Exit:** an office bearer can run the society end to end from a phone browser.

### Phase 8 — Resident Flutter app *(4 weeks)*
Onboarding + OTP, unit switcher for multi-unit owners, dues and payment, receipts,
documents, notices, push notifications, profile, offline-tolerant caching, store release.

**Exit:** app on TestFlight and Play internal testing, used by real residents of the pilot
society.

### Phase 9 — Cutover *(1.5 weeks)*
Rehearsals, parallel run, go-live, 30-day v1 read-only retention, hypercare.

### Phase 10+ — Roadmap modules
Visitors & gate passes → parking → smart meters & consumption billing → amenities →
helpdesk → staff & payroll. Each attaches to `units` and bills through `charge_heads`,
which is exactly why Phases 1–5 are worth doing properly.

**Indicative total to cutover: ~22–24 focused weeks.** Phases 5–8 overlap in practice.

---

## 7. Compliance, security and cost

### DPDP Act 2023 — this applies to you
You will hold personal data of thousands of residents across societies. Each society is a
Data Fiduciary; you are a Data Processor. Build in from Phase 1, not later:

- Consent capture with purpose and timestamp, and a withdrawal mechanism
- Configurable retention policy per data category, with an enforcing job
- Data-subject access and erasure requests as an admin function
- Breach-notification runbook
- Processing agreement template for each society

**On Aadhaar specifically:** storing full Aadhaar numbers carries real legal exposure
under the Aadhaar Act and is rarely necessary for RWA operations. **My recommendation:
store only the last four digits plus the document image, and drop the full number during
migration** (the original stays in the archived v1 dump). Tell me if a society genuinely
requires otherwise and we will design encrypted storage with access logging instead.

### Security baseline
Argon2id for new passwords (bcrypt hashes migrate as-is and upgrade on next login),
15-minute access tokens with rotating refresh tokens, per-tenant and per-IP rate limits,
`Idempotency-Key` on mutations, signed URLs only for files, envelope encryption for
secrets, CSP and strict CORS, dependency scanning in CI, and an annual penetration test
once you have paying societies.

### Cost model at ~50 societies
Managed Postgres with autoscaling (~$70–120/mo), one or two API containers plus a worker
(~$40–60/mo), R2 (~$5–15/mo), messaging billed per use, Sentry and uptime monitoring on
free or cheap tiers. **Roughly $150–250/month to serve 50 societies** — because it is
pooled. The same load on database-per-society is 5–10× that.

---

## 8. What happens to the prototype

- **Freeze and tag it.** Commit the outstanding WIP first — migration 029 and the twelve
  modified files — so nothing in flight is lost.
- **Keep it running** for the live society until Phase 9 cutover. Bug fixes only; no new
  features, or you will be building the same thing twice.
- **Harvest, do not port.** `DOCS/FUNCTIONAL_REFERENCE.md` is genuinely valuable — it
  becomes the acceptance-test specification for v2. The Carbon stylesheet and the
  understanding embedded in the escalation and reinstatement rules carry forward. The Go
  and React source does not.

---

## 9. Open questions for you

1. **Live data location.** `backend/.env` points at `localhost:5432/bwa_hq`. Is that the
   production data, or is there a deployed Neon/Render database that is the real source?
   The migration plan needs the authoritative one.
2. **Tenants.** Are any current members actually tenants rather than owners? If so I need
   the list before Phase 3, because the occupancy model migrates them differently.
3. **Aadhaar.** Confirm the last-4-only recommendation in Section 7.
4. **Escalation history.** Once the inventory runs, we decide whether penalty amounts can
   be split from principal or must migrate as a combined line.
5. **Pilot scope.** Does the pilot society go live on v2 alone, or do you want a second
   society onboarded before cutover to prove multi-tenancy in production?
6. **Your available hours per week.** The phase estimates assume roughly full-time. Tell
   me your real capacity and I will re-sequence so that each phase still ends in something
   usable.

---

## 10. Immediate next steps

1. Commit and tag the prototype WIP
2. Run the Section 5.2 inventory and send me the output
3. Answer Section 9
4. I produce **Build Packet 0** — repo skeleton, Docker Compose, CI, ADRs — with code you
   can type in directly
```
