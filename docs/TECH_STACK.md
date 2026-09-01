# CivicSync v2 — Definitive Technology Stack

**Status:** Accepted · **Date:** 26 Aug 2026 · **Supersedes** the stack table in
`PRODUCTION_PLAN.md` §2 and the `chi` choice in Build Packet 00.

Nothing here is left to decide later. Where a choice differs from your other project,
the difference is stated and justified. Where you had a gap, it is filled.

---

## Alignment with your other project

| Layer | Other project | CivicSync v2 | Verdict |
| --- | --- | --- | --- |
| Language | Go | Go 1.25 | **Same** |
| HTTP framework | Fiber | **Fiber v3** | **Same — changed from chi** |
| Admin UI | React + IBM Carbon | React 18 + IBM Carbon v11 | **Same** |
| API style | REST + gRPC | REST now; gRPC reserved for device ingest | **Mostly same** |
| Database | PostgreSQL | PostgreSQL 18 | **Same** |
| Cache | Redis | **Redis — ephemeral state only** | **Same, with a hard rule** |
| Mobile | Flutter | Flutter 3.x | **Same** |

**One stack across both projects is worth real money to you.** Middleware, error
handling, auth patterns, CI configuration and mental model all transfer. As a solo
developer that compounding beats a marginally better router.

### Why I changed my mind on Fiber

Build Packet 00 specified `chi`. My objection was that Fiber runs on `fasthttp`, which
is not `net/http`-compatible, and I assumed that would cost us OpenAPI codegen and the
standard middleware ecosystem. Both concerns turned out to be wrong in practice:
oapi-codegen ships `fiber-server` and `fiber-v3-server` generators, and `otelfiber`
provides OpenTelemetry instrumentation.

**Change Packet 00 accordingly** — it is only a few lines, and better now than in
Packet 07.

Two `fasthttp` behaviours to be disciplined about, because they cause real bugs:

1. **The request context is recycled after the handler returns.** Never hand a Fiber
   `Ctx` to a goroutine or a background job. Copy the values you need — `org_id`,
   `user_id`, `request_id` — into a plain `context.Context` first. Our
   `InTenantTx` signature already takes a `context.Context`, which keeps this honest.
2. **No HTTP/2 end to end.** Irrelevant here: TLS and HTTP/2 terminate at Cloudflare
   and the load balancer, and gRPC will run on its own port anyway.

### Why Redis is in — with one hard rule

I originally said defer Redis to avoid another moving part. You already run it, and
several things in this system fit it genuinely better than PostgreSQL: OTP attempt
counters, rate-limit buckets, master-data cache, and pub/sub fan-out for SSE once you
run more than one API instance. All of those want TTLs and cheap atomic increments.

> **The rule: nothing may live in Redis that we cannot afford to lose.**
> Redis is a cache and a counter, never a system of record.

Specifically, **background jobs stay in PostgreSQL** via River, not in Redis. A lost
job here is a lost payment reconciliation or an unsent legal notice. River's jobs commit
in the same transaction as the business change, which a Redis queue cannot do.

### Why gRPC waits

All client traffic — admin web, Flutter app, third-party integrators — is REST over the
OpenAPI contract. One contract, three generated clients, no dual maintenance.

gRPC earns its place in exactly two future situations, and you should add it then:

- **Device/telemetry ingest** when `metering` ships. Binary framing and streaming are a
  real win at 1.4 billion readings a year, and devices are not browsers.
- **Service-to-service** if a module is ever extracted from the monolith.

Adding gRPC in v2.0 would mean a second contract and a second server for zero user-
visible benefit.

---

## Backend — Go

| Concern | Choice | Notes |
| --- | --- | --- |
| Language | **Go 1.25** | |
| HTTP | **Fiber v3** | `github.com/gofiber/fiber/v3` |
| Postgres driver | **pgx/v5** | `github.com/jackc/pgx/v5` + `pgxpool` |
| Query layer | **sqlc** | Typed Go from real SQL. This is what prevents another 2,300-line repository |
| Migrations | **golang-migrate** | Every migration reversible; `make migrate-redo` in CI |
| Background jobs | **River** | `github.com/riverqueue/river` — Postgres-backed, transactional with your data |
| Cache / counters | **Redis 7** | `github.com/redis/go-redis/v9`. Ephemeral only |
| API contract | **OpenAPI 3.1** | `oapi-codegen` with `fiber-v3-server` + strict mode |
| Validation | **go-playground/validator/v10** | Beyond what the spec enforces |
| JWT | **golang-jwt/jwt/v5** | 15-min access tokens |
| Password hashing | **Argon2id** | `golang.org/x/crypto/argon2`. Existing bcrypt hashes migrate as-is and upgrade on next login |
| Object storage | **aws-sdk-go-v2/service/s3** | Same client for R2, MinIO and S3 |
| Encryption | **crypto/aes** GCM + `golang.org/x/crypto/hkdf` | Envelope encryption, per-org DEK |
| Logging | **log/slog** | JSON in production |
| Tracing/metrics | **OpenTelemetry** + `otelfiber` | `org_id` as a span attribute |
| Errors | **RFC 9457 problem+json** | Stable `type` URIs |
| XLSX | **excelize/v2** | `github.com/xuri/excelize/v2` |
| PDF | **Gotenberg** | A container; HTML template → PDF. Far better fidelity than any Go PDF library for invoices and receipts, and your Carbon-styled templates render as-is |
| Testing | **testcontainers-go** + **testify** | Real PostgreSQL. RLS and triggers cannot be tested against mocks |
| Load testing | **k6** | Against a seeded 20,000-unit dataset |
| Lint | **golangci-lint** | |
| Security scan | **govulncheck** + **gitleaks** | In CI |

---

## Admin console — React

| Concern | Choice | Notes |
| --- | --- | --- |
| Framework | **React 18** | Not 19 until IBM Carbon confirms support — verify before upgrading |
| Language | **TypeScript 5.x**, `strict: true` | |
| Build | **Vite 6** | |
| Design system | **IBM Carbon v11** | `@carbon/react`. Right family for dense ERP tables and forms |
| Routing | **TanStack Router** | Type-safe routes and search params |
| Server state | **TanStack Query v5** | Caching, retry, invalidation — all absent in the prototype |
| Data grid | **TanStack Table v8** | Headless; **server-side** paging/filter/sort. Replaces the bespoke `DataTable` |
| API client | **orval** | Generates the client *and* the Query hooks from the OpenAPI spec |
| Forms | **React Hook Form** + **Zod** | Zod schemas generated from the spec |
| Charts | **Recharts** | Carbon Charts is an option but heavier |
| Unit tests | **Vitest** + **Testing Library** | |
| API mocking | **MSW** | Handlers generated from the spec |
| E2E | **Playwright** | Login, onboarding, billing, payment, documents |
| Lint/format | **Biome** | One tool replacing ESLint + Prettier; much faster |

---

## Resident app — Flutter

| Concern | Choice | Notes |
| --- | --- | --- |
| Framework | **Flutter 3.x** (latest stable) / Dart 3 | |
| State | **Riverpod v2** | |
| HTTP | **dio** | Interceptors for auth, retry, idempotency keys |
| API client | **openapi-generator** (`dart-dio`) | Same spec as the web client |
| Routing | **go_router** | |
| Models | **freezed** + **json_serializable** | |
| Local storage | **flutter_secure_storage** (tokens) + **Drift** (offline cache) | |
| Push | **firebase_messaging** | FCM covers both iOS and Android |
| Payments | **razorpay_flutter** | |
| Crash/errors | **sentry_flutter** | |
| Testing | **flutter_test** + **mocktail**; **Patrol** for integration | |
| Distribution | **Fastlane** + TestFlight / Play internal testing | |

---

## Infrastructure

| Concern | Choice | Notes |
| --- | --- | --- |
| Local dev | **Docker Compose** | PostgreSQL 18, Redis, MinIO, Mailpit, Gotenberg |
| CI/CD | **GitHub Actions** | |
| Database | **Neon** (pilot) → **managed PostgreSQL** at scale | Neon's scale-to-zero suits a pilot; revisit around 20 societies |
| Object storage | **Cloudflare R2** | S3-compatible, zero egress fees |
| API hosting | **Fly.io** or **Render** | Fly for regional placement close to Indian users |
| Edge/DNS/WAF | **Cloudflare** | TLS, HTTP/2 and 3, WAF, rate limiting at the edge |
| Admin hosting | **Cloudflare Pages** or **Vercel** | Static build |
| Secrets | **Doppler** or **1Password Secrets Automation** | Never in the repo, never in the database |
| Error tracking | **Sentry** | Go, React and Flutter |
| Uptime/logs | **Better Stack** | |
| Metrics/traces | **Grafana Cloud** free tier | OTel-native |
| Status page | **Better Stack** | Societies will ask for one |

---

## India-specific integrations

| Concern | Choice | Notes |
| --- | --- | --- |
| Payments | **Razorpay** | Orders, webhooks, signature verification, settlement reconciliation. UPI, cards, netbanking |
| WhatsApp | **Meta WhatsApp Cloud API** | Pending WABA approval |
| SMS | **MSG91** | DLT-registered templates required in India — allow 2–3 weeks lead time |
| Email | **Resend** or **AWS SES** | |
| Push | **Firebase Cloud Messaging** | |

All five sit behind provider-neutral interfaces (`PaymentGateway`, `MessageChannel`), so
swapping Razorpay for PhonePe or MSG91 for Gupshup is an adapter, not a refactor.

> **Start the DLT registration and the WABA review this week.** Both are approval
> processes measured in weeks and neither depends on your code. They are the classic
> thing that blocks a launch that was otherwise ready.

---

## Deliberately not used

| Rejected | Why |
| --- | --- |
| GORM / any ORM | Hides the SQL; N+1 queries by default; fights RLS and CTEs. sqlc gives type safety without the hiding |
| Kafka / RabbitMQ | River on PostgreSQL is sufficient to well past 100 societies, at zero extra infrastructure |
| Kubernetes | A solo developer does not need a cluster. Fly/Render until there is a team |
| Elasticsearch | PostgreSQL full-text search covers this workload |
| Next.js | The admin console is an authenticated SPA. SSR buys nothing and adds a Node runtime to operate |
| Tailwind / shadcn | You have Carbon. Two design systems is worse than either alone |
| Prisma / Drizzle | Not applicable — Go backend |
| Redis as job queue | Jobs must commit atomically with business data. Only a Postgres queue can |

---

## Changes to Build Packet 00

1. `postgres:17-alpine` → **`postgres:18-alpine`** *(already applied)*
2. `chi` → **Fiber v3**: `go get github.com/gofiber/fiber/v3`
3. Add **Redis** and **Gotenberg** to `docker-compose.yml`
4. `internal/http/router.go` becomes a Fiber app; `/health` becomes a Fiber handler
5. `ops/checks/check_layers.sh` — no change; the module path grep still applies

The tenancy work — `app.current_org_id()`, `InTenantTx`, the RLS policies, the CI
checks — is entirely unaffected. That was the point of keeping the database as the
enforcement layer: the router is a detail.

I will reissue Packet 00's Go section against Fiber v3 so you are not translating it
yourself. Say the word and it is your next message.
