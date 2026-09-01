# CivicSync v2 — Platform Engineering Standards

**Status:** Accepted · **Date:** 26 Aug 2026 · **Governs:** every migration, query and
endpoint from Build Packet 01 onward.

The production plan says *what* to build. This document says *how*, at the level of
mechanism. Where the prototype made a choice that will not survive scale, this names
the choice, explains why it fails, and fixes it.

Every rule here is enforceable — by a CI check, a code-review question, or a test.
Rules that cannot be enforced are opinions, and opinions do not belong in a standard.

---

## 0. What "scale" means here, numerically

Design targets are not aspirations; they set which decisions matter.

| Horizon | Societies | Units | Residents |
| --- | --- | --- | --- |
| Pilot | 1 | ~370 | ~500 |
| Year 1 | 10 | ~4,000 | ~10,000 |
| Year 3 | 50 | ~20,000 | ~50,000 |

At the Year-3 target, annual row production:

| Data | Volume per year | Driver |
| --- | --- | --- |
| Smart meter readings @ 15 min | **~700 million** | 20,000 units × 96/day |
| Gate / visitor / ANPR events | ~50 million | ~7 per unit per day |
| Ledger entries | ~1 million | 12 invoices + receipts + penalties per unit |
| Invoices | ~240,000 | |
| Documents | ~100,000 objects, **~200 GB** | ~5 per unit at ~2 MB |
| Audit log | ~20 million | |

Two conclusions follow immediately, and they drive most of this document:

1. **The database will be dominated by machine-generated time-series**, not by
   business records. Partitioning and retention are not optimisations to add later;
   they are the shape of the schema.
2. **200 GB of documents cannot live in PostgreSQL.** This is not a preference.

---

## 1. What the prototype got wrong

Not criticism — this is the checklist of what refactoring must actually change. Each
was found in the live schema or the live data.

| Prototype mechanism | Why it fails at scale | v2 standard |
| --- | --- | --- |
| `member_documents.file_data BYTEA`, `notices.attachment_data BYTEA` | Every byte enters WAL, replication, and every backup. 200 GB of PDFs makes restores hours long and replicas fragile. No CDN, no range requests, no streaming | §2 Object storage only |
| `bigserial` primary keys exposed in URLs | Enumerable (`/members/1` … `/members/370` leaks membership size and enables scraping); requires DB round-trip before an ID exists; collides on merge/import | §3 UUIDv7 |
| `payments.period` holding `'FY 2023-24'`, `'Legal FY 2025-26'`, `'Membership Fee'` | One text column conflating financial year *and* charge type. Unqueryable, unaggregatable, unvalidatable — reporting is string matching | §4 Typed dimensions |
| `status TEXT CHECK (status IN (...))` on nine tables | Every new value is a migration with an `ALTER TABLE` and a table rewrite risk. Societies cannot add their own | §5 Lookup tables |
| `organization_settings` / `payment_escalation_settings` with `id DEFAULT 1` | Singleton row tables. Each new setting is a schema migration. No history, no scoping, no validation | §6 Settings as data |
| `key_secret_encrypted`, `api_key_encrypted` storing **plaintext** | A column named `_encrypted` that isn't creates false confidence — worse than no encryption | §7 Real envelope encryption |
| `MarkOverdueMembersInactive` mutating rows during **read** requests | Non-deterministic, non-idempotent, unauditable, and it makes `GET` requests take write locks | §11 No write on read |
| Client-side `DataTable` loading all rows, then filtering/sorting/exporting in the browser | Works at 370 members, dies at 20,000. Exports are bounded by browser memory | §10 Server-side everything |
| 30-second polling for alerts, per client | 50,000 residents polling = 1,600 req/s of mostly-empty responses | §12 Events, not polling |
| WhatsApp relay in fire-and-forget goroutines | Messages lost on deploy or restart, with no record that they were lost | §12 Transactional outbox |
| No `created_by` / `updated_by` on most tables | "Who changed this?" is unanswerable — fatal for a system handling society money | §8 Table spine |
| `RepairCurrentSchema` patching schema outside migrations | Live evidence: Neon reports migration 26 while carrying columns from 27 and 28. Schema state is now unknowable without inspection | Deleted. Migrations are the only authority |

---

## 2. Files never live in the database

**Rule: PostgreSQL stores metadata about a file. The bytes live in object storage.
No `BYTEA` columns for user content. No base64 strings. No exceptions.**

### Why

A 2 MB PDF written to `BYTEA` is written to the WAL, shipped to every replica, and
included in every backup — for the life of the row. It is TOASTed and compressed on
every read. It cannot be served by a CDN, cannot support HTTP range requests, cannot be
streamed, and forces the whole object through Go's heap on both upload and download.
At 200 GB the practical consequences are: multi-hour restores, replication lag spikes
on bulk uploads, and an API that OOMs under concurrent downloads.

### The mechanism

Bytes never pass through the API. The client talks to object storage directly using
short-lived pre-signed URLs; the API only authorises and records.

**Upload:**

```
1. Client  → API    POST /v1/documents:presign  {filename, mime, size, purpose}
2. API              authorise; validate mime + size against policy;
                    insert `documents` row with status='pending'
                    issue pre-signed PUT (5 min TTL) to a key the client cannot choose
3. Client  → R2     PUT the bytes directly
4. Client  → API    POST /v1/documents/{id}:complete  {etag, sha256}
5. API              verify object exists and size/etag match; status='stored';
                    enqueue virus scan; emit document.stored event
```

**Download:** permission check, then issue a pre-signed GET with a short TTL and
`Content-Disposition`. The API returns a URL, never the file. This is also why the
prototype's `openAuthenticatedBlob` pattern disappears.

### Object keys

```
org/{org_id}/{entity}/{entity_id}/{document_id}/{version}/{sanitised_filename}
```

Keys are assigned by the server and are immutable. Clients never choose a key — that is
how you get path traversal and cross-tenant overwrites. Per-tenant prefixes mean an
R2 bucket policy or a per-tenant credential can enforce isolation at the storage layer
too.

### The metadata table

```sql
CREATE TABLE documents (
    id             uuid PRIMARY KEY DEFAULT uuidv7(),
    org_id         uuid NOT NULL REFERENCES control.tenants(org_id),
    document_type_id uuid NOT NULL REFERENCES document_types(id),   -- master data
    owner_type     text NOT NULL,          -- 'unit' | 'party' | 'voucher' | 'notice'
    owner_id       uuid NOT NULL,
    storage_bucket text NOT NULL,
    storage_key    text NOT NULL,
    version        int  NOT NULL DEFAULT 1,
    file_name      text NOT NULL,
    mime_type      text NOT NULL,
    size_bytes     bigint NOT NULL CHECK (size_bytes > 0),
    sha256         bytea NOT NULL,
    status         text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','stored','quarantined','deleted')),
    scan_status    text NOT NULL DEFAULT 'unscanned',
    uploaded_by    uuid,
    uploaded_at    timestamptz NOT NULL DEFAULT now(),
    deleted_at     timestamptz,
    UNIQUE (storage_bucket, storage_key)
);
```

`sha256` gives deduplication, integrity verification, and a migration reconciliation
key. `status='pending'` rows older than an hour are swept — that is how abandoned
uploads are reclaimed.

**Deletion is a tombstone plus an async purge**, never a synchronous delete. Legal
documents may be under retention policy; the purge job honours it.

Local development uses MinIO with the identical S3 API, so there is no code path that
exists only in production.

---

## 3. Keys and identifiers

**Rule: two key strategies, chosen by table role. Never `bigserial` on anything
exposed through the API.**

### Business entities → `uuid` v7

```sql
id uuid PRIMARY KEY DEFAULT uuidv7()
```

PostgreSQL 18 provides `uuidv7()` natively. UUIDv7 is time-ordered, so unlike v4 it
appends to B-tree indexes instead of scattering writes across the whole index — which
is what makes random UUIDs a performance problem at volume. It is also unguessable,
generatable client-side before a round-trip, and collision-free across the ETL, seeds
and multiple environments.

**v2 targets PostgreSQL 18.** Neon supports it. This replaces the `postgres:17-alpine`
line in Build Packet 00's `docker-compose.yml` with `postgres:18-alpine`.

### High-volume append-only tables → `bigint identity`

```sql
id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY
```

For `ledger_entries`, `meter_readings`, `gate_events`, `audit_log`, `outbox`. These are
never addressed individually by an external caller, and at hundreds of millions of rows
the 8 bytes saved per row per index matters — across PK plus two indexes on 700M rows,
that is roughly 17 GB. They are queried by `(org_id, time)` range, not by id.

### Natural keys stay unique, always

`UNIQUE (org_id, code)` on every master table. The surrogate key is for joins; the
natural key is for humans and for idempotent imports.

---

## 4. Money and typed dimensions

**Rule: money is `NUMERIC`, currency is explicit, and JSON carries amounts as strings.**

```sql
amount        numeric(14,2) NOT NULL,
currency_code char(3)       NOT NULL DEFAULT 'INR'
```

Never `float`/`double` — binary floating point cannot represent 0.10, and society
accounts must balance exactly. `numeric(14,2)` holds up to 999 billion, comfortable for
a corpus fund.

**In JSON, amounts are strings:** `{"amount": "1072892.00"}`. A JSON number becomes a
float64 in JavaScript and a `double` in Dart. `10725.15` will eventually render as
`10725.149999999999` in the resident's app. Strings are the only safe transport, and
this is settled in the OpenAPI spec, not per-endpoint.

### The `period` lesson

The live data contains `'FY 2023-24'`, `'Legal FY 2025-26'` and `'Membership Fee'` in
one text column — a financial year, a financial year qualified by expense type, and a
charge type. No query can aggregate that reliably.

v2 splits every such column into typed dimensions:

```sql
financial_year_id uuid NOT NULL REFERENCES financial_years(id),
charge_head_id    uuid NOT NULL REFERENCES charge_heads(id),
period_start      date NOT NULL,
period_end        date NOT NULL
```

**Generalised rule: if a text column's values encode more than one fact, it is at
least two columns.** During migration, the 955 legacy `period` values are parsed once,
mapped explicitly, and the original string is preserved in `source_metadata` so the
mapping stays auditable.

---

## 5. No enumerations in DDL

**Rule: no `CHECK (x IN (...))` on business values, and no PostgreSQL `ENUM` types.**

`ALTER TYPE ... ADD VALUE` cannot run inside a transaction block and cannot be undone.
A `CHECK` constraint means every new voucher category is a schema migration — which is
precisely the "no hardcoding" requirement failing.

Business values live in master tables with a foreign key (§3 of the production plan).
The narrow exception is a **structural** state the code branches on — `documents.status`
above — where the set is closed by the code itself, not by the society. Those stay as
`CHECK`, and the rule for telling them apart is: *if a society could plausibly want a
different value, it is master data.*

**CI enforces this**: a check fails the build on any new `CHECK (... IN ...)` constraint
outside an allowlist recorded in `ops/checks/allowed_check_constraints.txt`. Adding to
the allowlist requires a reviewer to agree the value is structural.

---

## 6. Settings are data

No more singleton tables. `setting_definitions` (key, type, JSON-schema validation,
default, scope, UI group, `is_secret`) plus `setting_values` (org, key, jsonb value,
effective dates, updated_by).

A new configurable parameter becomes a seed row. The admin UI renders itself from the
definitions. No migration, no form field, no deploy.

---

## 7. Secrets are actually encrypted

**Rule: no column named `*_encrypted` may contain plaintext.**

Envelope encryption:

- A master key lives in a KMS (or as a deployment secret at pilot scale).
- Each organization has a data key (DEK), stored wrapped by the master key.
- Secret values are encrypted with AES-256-GCM using the org's DEK.
- Stored as ciphertext + nonce + `key_version`, so keys can be rotated without
  re-encrypting everything at once.

```sql
CREATE TABLE org_secrets (
    id          uuid PRIMARY KEY DEFAULT uuidv7(),
    org_id      uuid NOT NULL REFERENCES control.tenants(org_id),
    purpose     text NOT NULL,              -- 'razorpay.key_secret', 'whatsapp.token'
    ciphertext  bytea NOT NULL,
    nonce       bytea NOT NULL,
    key_version int  NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    rotated_at  timestamptz,
    UNIQUE (org_id, purpose)
);
```

Secrets are **never** returned by any API, in any form, to any role. The admin UI shows
`configured: true` and a "replace" action. This is also what makes per-org key
separation meaningful: a database dump alone does not expose fifty societies'
payment credentials.

---

## 8. Every table's spine

Every tenant table carries the same skeleton. Non-negotiable, checked in CI.

```sql
id         uuid PRIMARY KEY DEFAULT uuidv7(),
org_id     uuid NOT NULL REFERENCES control.tenants(org_id),
-- ... business columns ...
created_at timestamptz NOT NULL DEFAULT now(),
created_by uuid,
updated_at timestamptz NOT NULL DEFAULT now(),
updated_by uuid,
deleted_at timestamptz,
version    int NOT NULL DEFAULT 1
```

Plus, for every one of them:

```sql
ALTER TABLE t ENABLE ROW LEVEL SECURITY;
ALTER TABLE t FORCE  ROW LEVEL SECURITY;
CREATE POLICY t_tenant ON t USING (org_id = app.current_org_id())
                            WITH CHECK (org_id = app.current_org_id());
CREATE INDEX ON t (org_id, created_at DESC);
CREATE TRIGGER t_touch BEFORE UPDATE ON t
    FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
```

`WITH CHECK` matters as much as `USING` — without it, a tenant can *write* a row
belonging to another tenant even though it cannot read one back.

`version` powers optimistic concurrency (§11). `deleted_at` means every query on a
soft-deleting table filters it, and every unique index becomes partial:
`UNIQUE (org_id, code) WHERE deleted_at IS NULL`.

---

## 9. Indexing and partitioning

**Rule: every index on a tenant table leads with `org_id`.**

RLS adds `org_id = …` to every query. An index that does not lead with `org_id` cannot
serve it efficiently, so the planner falls back to a scan filtered by policy — which is
how a "secure" system becomes an unusably slow one.

**Time-series tables are declaratively partitioned by month from day one:**

```sql
CREATE TABLE meter_readings (
    id          bigint GENERATED ALWAYS AS IDENTITY,
    org_id      uuid NOT NULL,
    meter_id    uuid NOT NULL,
    reading_at  timestamptz NOT NULL,
    value       numeric(14,3) NOT NULL,
    source      text NOT NULL,
    PRIMARY KEY (id, reading_at)
) PARTITION BY RANGE (reading_at);

CREATE INDEX ON meter_readings USING brin (reading_at);
CREATE INDEX ON meter_readings (org_id, meter_id, reading_at DESC);
CREATE UNIQUE INDEX ON meter_readings (org_id, meter_id, reading_at);  -- idempotent ingest
```

BRIN rather than B-tree on the time column: on naturally time-ordered data BRIN is
roughly 1/1000th the size and adequate for range scans. Retention is a partition
`DROP` — instant — rather than a `DELETE` of 60 million rows.

Applies to `meter_readings`, `gate_events`, `audit_log`, `outbox`, and
`notification_deliveries`. A monthly job creates the next three partitions and drops
those past retention.

**Aggregates are precomputed.** "Consumption this month per unit" must never scan raw
readings. Rollup tables (`meter_consumption_daily`, `meter_consumption_monthly`) are
written by the ingest job. Billing reads rollups.

---

## 10. Reads

**Keyset pagination. Never `OFFSET`.**

```sql
WHERE org_id = $1 AND (created_at, id) < ($2, $3)
ORDER BY created_at DESC, id DESC
LIMIT $4
```

`OFFSET 10000` makes PostgreSQL fetch and discard 10,000 rows. Keyset pagination is
O(log n) at any depth and is stable when rows are inserted mid-scroll. Cursors are
opaque base64 tokens; page size is capped server-side.

**All filtering, sorting, searching and exporting is server-side.** The prototype's
`DataTable` fetched everything and worked in the browser. Sort fields come from an
explicit allowlist — never interpolated into SQL. Exports stream: the server generates
XLSX/PDF and returns a pre-signed URL, so a 20,000-row export is a background job, not
a browser tab that dies.

**Every list endpoint declares its query shape and has an index that serves it.** A
new list endpoint without a matching index is an incomplete endpoint.

**`EXPLAIN` assertions on critical queries in tests.** A handful of tests seed ~100k
rows and assert the plan contains no `Seq Scan` on a large table. This catches the
index that quietly stopped being used two refactors ago.

---

## 11. Writes

**Idempotency.** Every mutating endpoint accepts `Idempotency-Key`. Key plus request
hash plus response are stored; a replay returns the stored response. Mandatory for a
mobile app on Indian mobile networks, where a payment request being sent twice is
routine.

**Optimistic concurrency.** Updates carry the `version` they read:
`UPDATE ... SET version = version + 1 WHERE id = $1 AND version = $2`. Zero rows
affected returns `409 Conflict`. Two committee members editing the same member no
longer silently overwrite each other.

**No writes on read paths. Ever.** All state transitions — escalation, billing runs,
reminders, meter rollups — are River jobs. Jobs are idempotent, keyed on a business
identity such as `(org_id, invoice_id, dunning_stage, run_date)`, so a retry or a
double-schedule is a no-op. Billing runs take a PostgreSQL advisory lock per org so two
runs cannot overlap.

**Bulk writes use `pgx.CopyFrom`.** The ETL and meter ingest insert row-by-row nowhere.

**Statement timeouts everywhere.** `SET statement_timeout` per connection; a runaway
report cannot hold a connection for ten minutes.

---

## 12. Integration is a first-class feature

This is what "integrable" has to mean concretely, and it is mostly one pattern.

**Transactional outbox.** Every business change writes a domain event to `outbox` in
the same transaction. A River worker publishes them. The event is committed with the
data or not at all — which is why the prototype's fire-and-forget goroutines lose
messages and this does not.

```sql
CREATE TABLE outbox (
    id             bigint GENERATED ALWAYS AS IDENTITY,
    org_id         uuid NOT NULL,
    event_type     text NOT NULL,          -- 'invoice.issued', 'payment.received'
    aggregate_type text NOT NULL,
    aggregate_id   uuid NOT NULL,
    payload        jsonb NOT NULL,
    occurred_at    timestamptz NOT NULL DEFAULT now(),
    published_at   timestamptz,
    attempts       int NOT NULL DEFAULT 0,
    PRIMARY KEY (id, occurred_at)
) PARTITION BY RANGE (occurred_at);
```

Every outbound channel is a subscriber: WhatsApp, SMS, email, push, webhooks, and
later the analytics pipeline. Adding a channel adds a subscriber, not a change to
business logic.

**Outbound webhooks** so a society's accountant or a third-party integrator can
subscribe: HMAC-SHA256 signature over the raw body, a timestamp header to prevent
replay, exponential-backoff retries, and a delivery log the admin can inspect. At-least-
once delivery, with event ids so consumers can deduplicate.

**Inbound API access** for integrators: per-org API keys with scopes, stored hashed,
rate-limited per key, every call in the audit log. Same OpenAPI contract as the first-
party clients — no privileged private API.

**Device ingest** as its own path, because IoT is not a REST CRUD workload: device
identity with per-device credentials, batch endpoints accepting hundreds of readings,
idempotency by `(meter_id, reading_at)` so replays after connectivity loss are free,
and back-pressure via `429` rather than unbounded queueing.

**Real-time to clients** replaces polling: Server-Sent Events for the admin console,
FCM/APNs for mobile. The prototype's per-client 30-second poll does not survive 50,000
residents.

---

## 13. Observability and budgets

- **Structured logs** (`slog` JSON) with `request_id`, `org_id`, `user_id` on every line.
- **OpenTelemetry traces** with `org_id` as a span attribute, so a slow society is
  findable.
- **`pg_stat_statements` enabled**, reviewed for the top queries by total time each
  release.
- **RFC 9457 `application/problem+json`** for every error, with a stable `type` URI.
  The prototype returned ad-hoc shapes; clients could not branch on them.

Performance budgets, asserted in CI where practical:

| Operation | Budget (p95) |
| --- | --- |
| List endpoint, 50 rows | < 150 ms |
| Detail endpoint | < 100 ms |
| Write endpoint | < 250 ms |
| Meter batch ingest, 1,000 readings | < 2 s |
| Monthly billing run, 400 units | < 30 s |

A budget without a test is a wish. The list and write budgets get load tests against a
seeded 20,000-unit dataset before go-live.

---

## 14. What this changes in the plan

1. **PostgreSQL 18, not 17.** Native `uuidv7()`. Update Packet 00's compose file.
2. **Packet 01 grows** to include the table spine, the CI checks for it, and the
   `documents` + object-storage adapter, which was previously Phase 4. Storage must be
   right before anything writes a file.
3. **Partitioning and outbox arrive in Packet 01**, not with the IoT modules. Retro-
   fitting partitions onto a populated table is an outage.
4. **Load testing becomes a phase exit criterion**, not a pre-launch afterthought.
5. **Document migration is deleted from the ETL** — all 8 prototype documents are test
   data.

---

## 15. Enforcement

| Standard | How it is enforced |
| --- | --- |
| Tenant isolation (§8) | `ops/checks/check_rls.sql` — CI |
| Layer purity | `ops/checks/check_layers.sh` — CI |
| No DDL enums (§5) | `ops/checks/check_constraints.sql` + allowlist — CI |
| Table spine (§8) | `ops/checks/check_spine.sql` — CI |
| `org_id`-leading indexes (§9) | `ops/checks/check_indexes.sql` — CI |
| No `BYTEA` user content (§2) | `ops/checks/check_no_blobs.sql` — CI |
| Reversible migrations | `make migrate-redo` — CI |
| Query plans (§10) | `EXPLAIN` assertions in integration tests |
| Contract drift | codegen diff — CI |

Nine mechanical checks. Together they are the difference between standards that hold
and standards that are a document nobody opens after month three.

---

## 16. One-way doors — the 100+ society target

**Revised target (26 Aug 2026): 100+ societies, built by a solo developer today, with
a team later.** That combination — high ceiling, low current capacity — is the real
design constraint, and it has a specific answer.

### At 100 societies the numbers are

| | |
| --- | --- |
| Units | ~40,000 |
| Residents | ~100,000 |
| Meter readings @ 15 min | **~1.4 billion rows/year** |
| Gate / visitor events | ~100 million/year |
| Ledger entries | ~2 million/year |
| Documents | ~200,000 objects, ~400 GB |
| Money flowing through billing | order of ₹100 crore/year |

Two consequences. The database is overwhelmingly **machine data**, not business
records — 1.4 billion rows against 2 million. And the financial correctness bar is set
by the last line: at that volume of member money, an unauditable balance is not a bug,
it is a liability.

### Sharding is already designed in — deliberately

The concern that sharding later means "high downtime or a complete new app build" is
the right concern, and it is exactly what the tenancy model in ADR-0001 was chosen to
prevent.

Every row carries `org_id`. `org_id` **is** the shard key. `control.tenants.data_location`
maps a tenant to a connection pool, and the API resolves that mapping per request.
Sharding, when it comes, is:

1. Add a second database and register it as `data_location = 'shard-2'`
2. For one society: freeze writes, `pg_dump` filtered by `org_id`, restore, flip its
   `data_location` row, unfreeze

Per-society downtime measured in minutes, no code change, no other tenant affected.
That is the entire reason the indirection exists at Packet 00 rather than being added
when it hurts. **Do not build sharding now.** One PostgreSQL instance with proper
partitioning comfortably serves 100 societies of business data; you would be paying
complexity for a problem you do not have.

### One addition the revised target does force

**Separate the IoT time-series from the transactional data at the schema and
connection level, from the first migration.**

Meter readings and gate events go in their own schema (`telemetry`), reached through
their own connection pool and their own repository package — even though they live in
the same PostgreSQL instance today. They share nothing with the business tables except
`org_id`.

This costs nothing now, and it means the day 1.4 billion rows justify a dedicated
store — a separate PostgreSQL, TimescaleDB, or ClickHouse — that becomes a
configuration change and a data move, not a rewrite of the billing module that reads
consumption. Ingest and billing already talk to each other through rollup tables, not
raw readings, which is what makes the seam clean.

### The actual rule: one-way doors now, reversible doors later

As a solo developer the scarce resource is your time, so the discipline is to spend it
only where a later fix is impossible or catastrophic.

**Do now — retrofitting these is a rewrite, an outage, or unrecoverable data loss:**

| Decision | Why it cannot wait |
| --- | --- |
| `org_id` on every table | It is the shard key. Adding it later means backfilling every table and every query |
| Tenant → pool indirection | Without it, sharding is an application rewrite |
| UUIDv7 keys, not `bigserial` | Changing a PK type rewrites the table and every FK that references it |
| Partitioning on time-series | Partitioning a populated 1.4-billion-row table is an outage |
| Telemetry schema separation | Splitting it later means rewriting every consumer |
| Object storage for files | Moving 400 GB out of `BYTEA` and rewriting every path |
| Append-only ledger | You cannot reconstruct history that a status column overwrote |
| `created_by` / `updated_by` / audit log | You cannot backfill who did what last year |
| Idempotency keys on mutations | Adding them later is a breaking change across web, mobile, and every integrator |
| API versioning + OpenAPI contract | Retrofitting versioning breaks third-party integrations |
| Envelope encryption with `key_version` | Painful but possible later — do it now, it is cheap |
| Currency, timezone, locale, FY as data | Retrofitting means cleaning data, not just code |
| Soft delete + retention hooks | DPDP erasure requests are hard to serve against hard-deleted history |

**Defer — these are additive and can be introduced without touching what exists:**

sharding across databases · read replicas · caching layer · materialised rollups (as
long as raw data is retained) · full-text search · advanced rate limiting · multi-region ·
queue backend change · CDN · SSO/SAML · a BI/analytics pipeline.

If a decision is not on the first list, it is not a Packet 01 decision.

### The scope discipline this implies

The standards in this document are non-negotiable — they are what makes a solo-built
system survive being handed to a team. **Feature scope is the opposite: it should be cut
ruthlessly.**

The failure mode for a solopreneur building an ERP-grade platform is not poor
architecture. It is building modules 6 through 12 for societies that do not exist yet,
and never shipping to the one that does. Concretely:

- v2.0 ships **only** what the pilot society uses today: members/units, documents,
  billing and payments, notices, vouchers, and the resident app.
- Visitors, parking, meters, amenities and helpdesk are **seams, not code**. The
  telemetry schema, the `units` foreign keys and the `charge_heads` model exist so those
  modules can be added; none of them gets built before the pilot is live and paying.
- Every configurable master table ships with sensible seeded defaults so a society can
  work on day one without configuring anything. "Configurable" must not mean "unusable
  until configured."

### What automation replaces

Alone, you have no second reviewer. The nine CI checks in §15 are not process overhead
— they are the reviewer. That is why they are written before the code they guard, and
why a failing check must never be bypassed with `--no-verify`. When the team arrives,
those same checks are how the standards survive contact with people who did not write
them.
