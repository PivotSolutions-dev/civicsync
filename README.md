# CivicSync

Multi-tenant operations platform for residential welfare associations.
Admin console (web) · Resident app (Flutter) · Go API on PostgreSQL.

**Status:** pre-release. Release 0.5 (Association Core) targets **1 April 2027**.

Supersedes the prototype at
[CivicSync-prototype](https://github.com/PivotSolutions-dev/CivicSync-prototype),
frozen at tag `prototype-final-2026-08-26`.

## Start here

| Document | What it settles |
| --- | --- |
| [docs/INDEX.md](docs/INDEX.md) | **The map.** Every document, the reading order, the decision log |
| [docs/PRODUCTION_PLAN.md](docs/PRODUCTION_PLAN.md) | Scope, tenancy, migration strategy |
| [docs/RELEASE_PLAN.md](docs/RELEASE_PLAN.md) | Releases 0.5 / 1.0 / 1.1 / 2.0, 17 packets, milestone dates |
| [docs/PLATFORM_ENGINEERING_STANDARDS.md](docs/PLATFORM_ENGINEERING_STANDARDS.md) | Mechanism-level rules and the CI checks that enforce them |
| [docs/ARCHITECTURE_DDD.md](docs/ARCHITECTURE_DDD.md) | Layering, aggregates, and what we deliberately do not do |
| [docs/MODULE_REGISTER.md](docs/MODULE_REGISTER.md) | Module boundaries, ownership, packet map |
| [docs/REGISTRY_OWNERSHIP_MODEL.md](docs/REGISTRY_OWNERSHIP_MODEL.md) | Title, occupancy and association membership |
| [docs/TECH_STACK.md](docs/TECH_STACK.md) | Every technology choice, and the rejected ones |
| [docs/DEVELOPMENT_PLANNER.md](docs/DEVELOPMENT_PLANNER.md) | What to build next, and what to read before building it |
| [docs/CUTOVER_PLAN.md](docs/CUTOVER_PLAN.md) | The association engagement: meetings, approvals, go-live |
| [docs/adr/](docs/adr/) | Architecture decision records |

## Local development

    cp .env.example .env
    make init          # enables the versioned git hooks — run once per clone
    make up
    make migrate-up
    make run

See [docs/packets/BUILD_PACKET_00.md](docs/packets/BUILD_PACKET_00.md).

## Non-negotiables

1. Every tenant table carries `org_id`, `FORCE ROW LEVEL SECURITY`, and a policy.
2. File content lives in object storage. Never in PostgreSQL.
3. Money is an append-only ledger. Nothing is hard-deleted.
4. No enums, lists, rates or permissions hardcoded. They are master data.
5. Migrations are the only schema authority.

CI enforces 1, 2, 4 and 5 mechanically. Do not bypass a failing check.

## Licence

Proprietary. © Pivot Solutions.
