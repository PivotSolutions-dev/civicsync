# ADR-0001: Pooled multi-tenancy with row-level security

- Status: Accepted
- Date: 2026-08-26

## Context

CivicSync will be sold to 100+ residential societies. Requirements: strong per-society
data privacy, infrastructure cost that does not scale linearly with customers, and a
roadmap including high-volume time-series (smart meters, gate events).

## Decision

One PostgreSQL cluster, one shared schema. Every tenant-owned table carries `org_id` and
is protected by `ENABLE`/`FORCE ROW LEVEL SECURITY` with a policy comparing `org_id` to
`app.current_org_id()`. The API connects as `civicsync_app`, which has no `BYPASSRLS`.
Tenant context is set per transaction via `set_config('app.org_id', …, true)`.

`control.tenants.data_location` maps a tenant to a connection pool, so any society can
later be promoted to a dedicated database without changing business logic. `org_id` is
therefore also the shard key.

## Consequences

- Marginal cost per additional society approaches zero.
- A missing `WHERE org_id = …` returns zero rows rather than another society's data.
  `app.current_org_id()` returns NULL when unset, so policies fail closed.
- Every new tenant table needs `org_id`, an `org_id`-leading index, and a policy.
  Enforced by `ops/checks/check_rls.sql` in CI.
- Backups are cluster-wide; per-society restore needs a scripted filtered procedure,
  built and rehearsed in Packet 14.

## Rejected

- **Database per society** — linear cost and operational load; incompatible with
  partitioned time-series for IoT.
- **Schema per society** — migrations run N times; partition management becomes N×12 per
  year.
