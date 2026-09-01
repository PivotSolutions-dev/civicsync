# Build Packet 00 — Foundation

**Phase:** 0 · **Estimated:** 1 focused week · **Prerequisite:** none
**Revision 2** (26 Aug 2026) — Fiber v3 and PostgreSQL 18. Supersedes revision 1 entirely.

## What this packet delivers

A running, empty CivicSync v2 platform: monorepo skeleton, local stack in one command,
the tenancy primitives, and a CI pipeline that mechanically enforces the rules keeping
this codebase from rotting the way the prototype did.

**Exit criteria — all must be true before Packet 01:**

1. `make up && make migrate-up` produces a working local stack from a clean checkout
2. `curl localhost:8080/health` returns `{"status":"ok"}`
3. `make ci` passes, and `make verify` passes
4. The RLS check runs and passes — trivially, because there are no tenant tables yet.
   That is the point: the guard exists *before* the tables do
5. `civicsync_app` has `rolsuper = f` and `rolbypassrls = f`
6. The `pre-push` hook is installed and demonstrably blocks a push when a test fails
7. Three ADRs committed

## Prerequisites

> **No local `psql` needed.** The database checks run through
> `docker compose exec postgres psql`, so the client always matches the server version by
> construction and nothing extra is installed on your machine. Any local `psql` you happen
> to have is irrelevant to this packet.


```bash
go version                # need 1.26+
docker --version
docker compose version
migrate -version          # brew install golang-migrate
golangci-lint --version   # brew install golangci-lint
```

---

## Step 1 — Repository bootstrap

**Superseded by `docs/REPO_BOOTSTRAP.md` (26 Aug 2026).** CivicSync v2 is a **new
repository**, not a branch of the prototype.

Complete every item on that document's checklist first: freeze and rename the prototype
repo (do **not** archive it — it runs the live society until cutover), create the empty
private `PivotSolutions-dev/civicsync`, clone it to a new folder, copy the planning
corpus and legacy reference across, make the first commit, then enable branch protection.

Then:

```bash
git checkout -b packet/00-foundation
```

and continue from Step 2 below. Everything from here lands on `main` through a squash-
merged pull request with CI green.

## Step 2 — Repository root files

### `.gitignore`

```gitignore
# secrets
.env
.env.*
!.env.example

# go
api/bin/
*.test
coverage.out

# node
node_modules/
admin/dist/

# flutter
mobile/build/
mobile/.dart_tool/

# local data — NEVER commit database dumps
*.dump
*.sql.gz
ops/local-data/

# os
.DS_Store
```

### `.editorconfig`

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.go]
indent_style = tab

[Makefile]
indent_style = tab

[*.{sql,md}]
indent_size = 4
```

### `docker-compose.yml`

```yaml
name: civicsync

services:
  postgres:
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: civicsync
      POSTGRES_PASSWORD: civicsync
      POSTGRES_DB: civicsync
    # Host port 5433 deliberately: a local Homebrew PostgreSQL commonly holds 5432.
    ports: ["5433:5432"]
    volumes:
      # PostgreSQL 18+ wants ONE mount at /var/lib/postgresql and places the cluster in a
      # version-specific subdirectory beneath it. Mounting /var/lib/postgresql/data — the
      # pre-18 convention — makes the image refuse to start.
      # See https://github.com/docker-library/postgres/pull/1259
      - "pgdata:/var/lib/postgresql"
      - "./ops/checks:/checks:ro"     # so psql inside the container can read the guards
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U civicsync"]
      interval: 5s
      timeout: 3s
      retries: 10

  redis:
    image: redis:7-alpine
    command: redis-server --save "" --appendonly no
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 10

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: civicsync
      MINIO_ROOT_PASSWORD: civicsync123
    ports: ["9000:9000", "9001:9001"]
    volumes: ["miniodata:/data"]

  mailpit:
    image: axllent/mailpit:latest
    ports: ["1025:1025", "8025:8025"]

  gotenberg:
    image: gotenberg/gotenberg:8
    ports: ["3001:3000"]

volumes:
  pgdata:
  miniodata:
```

Redis runs with persistence **disabled on purpose** — it holds nothing we cannot afford
to lose, and making that true locally stops anyone quietly depending on it.

Consoles: MinIO http://localhost:9001 · Mailpit http://localhost:8025

### `.env.example`

```dotenv
APP_ENV=development
PORT=8080

# Migrator connection — owns the schema, runs migrations. NOT used by the API.
DATABASE_URL=postgres://civicsync:civicsync@localhost:5433/civicsync?sslmode=disable

# Application connection — non-owner, no BYPASSRLS. This is what the API uses.
APP_DATABASE_URL=postgres://civicsync_app:civicsync_app_dev@localhost:5433/civicsync?sslmode=disable

REDIS_URL=redis://localhost:6379/0

# Object storage (MinIO locally, Cloudflare R2 in production)
S3_ENDPOINT=http://localhost:9000
S3_REGION=auto
S3_BUCKET=civicsync-dev
S3_ACCESS_KEY_ID=civicsync
S3_SECRET_ACCESS_KEY=civicsync123

SMTP_HOST=localhost
SMTP_PORT=1025
GOTENBERG_URL=http://localhost:3001
```

**Two database connection strings is the point.** The migrator owns the schema and can
do anything; the API connects as `civicsync_app`, which cannot bypass row-level
security. Confusing them is the one mistake that silently disables tenant isolation, so
they are separate variables from the first commit.

```bash
cp .env.example .env
```

---

## Step 3 — Migration 000001: platform foundation

### `db/migrations/000001_platform_foundation.up.sql`

```sql
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS control;
CREATE SCHEMA IF NOT EXISTS telemetry;

COMMENT ON SCHEMA app       IS 'Platform helper functions. Holds no tenant data.';
COMMENT ON SCHEMA control   IS 'Control plane: tenant directory. Never subject to tenant RLS.';
COMMENT ON SCHEMA telemetry IS
'High-volume machine data (meter readings, gate events). Separate schema and separate
connection pool from day one so it can move to a dedicated store without rewriting the
modules that consume it. Empty until the metering module ships.';

-- ---------------------------------------------------------------
-- Tenant context
-- ---------------------------------------------------------------
CREATE FUNCTION app.current_org_id() RETURNS uuid
LANGUAGE plpgsql STABLE PARALLEL SAFE
AS $$
DECLARE raw text;
BEGIN
    raw := current_setting('app.org_id', true);
    IF raw IS NULL OR raw = '' THEN
        RETURN NULL;
    END IF;
    RETURN raw::uuid;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION app.current_org_id() IS
'Tenant context for the current transaction. Returns NULL when unset or malformed, so
RLS policies comparing org_id = app.current_org_id() match NO rows. Failing closed is
deliberate. Set with: SELECT set_config(''app.org_id'', $1, true);';

-- ---------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------
CREATE FUNCTION app.touch_updated_at() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------
-- Control plane: the tenant directory
-- ---------------------------------------------------------------
CREATE TABLE control.tenants (
    org_id        uuid        PRIMARY KEY DEFAULT uuidv7(),
    slug          citext      NOT NULL UNIQUE,
    name          text        NOT NULL,
    status        text        NOT NULL DEFAULT 'active'
                              CHECK (status IN ('provisioning','active','suspended','closed')),
    plan_code     text        NOT NULL DEFAULT 'standard',
    data_location text        NOT NULL DEFAULT 'primary',
    settings      jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN control.tenants.data_location IS
'Logical database identifier. Every tenant resolves to "primary" today. A society
promoted to a dedicated database gets its own value and the API routes it to a
different connection pool. This column is the escape hatch from pooled multi-tenancy —
without it, that promotion would be a re-architecture instead of a config change.';

CREATE TRIGGER tenants_touch
    BEFORE UPDATE ON control.tenants
    FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();

-- ---------------------------------------------------------------
-- Module enablement
-- ---------------------------------------------------------------
CREATE TABLE control.plan_modules (
    plan_code   text NOT NULL,
    module_code text NOT NULL,
    PRIMARY KEY (plan_code, module_code)
);

CREATE TABLE control.org_modules (
    org_id      uuid NOT NULL REFERENCES control.tenants(org_id) ON DELETE CASCADE,
    module_code text NOT NULL,
    enabled     boolean NOT NULL DEFAULT false,
    enabled_at  timestamptz,
    enabled_by  uuid,
    PRIMARY KEY (org_id, module_code)
);

COMMIT;
```

`uuidv7()` is native in PostgreSQL 18 — time-ordered, so it appends to B-tree indexes
instead of scattering writes across them the way random v4 does.

### `db/migrations/000001_platform_foundation.down.sql`

```sql
BEGIN;

DROP TABLE    IF EXISTS control.org_modules;
DROP TABLE    IF EXISTS control.plan_modules;
DROP TABLE    IF EXISTS control.tenants;
DROP FUNCTION IF EXISTS app.touch_updated_at();
DROP FUNCTION IF EXISTS app.current_org_id();
DROP SCHEMA   IF EXISTS telemetry;
DROP SCHEMA   IF EXISTS control;
DROP SCHEMA   IF EXISTS app;

COMMIT;
```

Every migration gets a real `down`. CI runs `up`, `down -all`, `up` on every push —
which is what makes rollback a fact rather than a hope.

---

## Step 4 — Migration 000002: the application role

### `db/migrations/000002_app_role.up.sql`

```sql
BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'civicsync_app') THEN
        CREATE ROLE civicsync_app LOGIN PASSWORD 'civicsync_app_dev';
    END IF;
END;
$$;

-- The security-critical line in this entire packet.
ALTER ROLE civicsync_app NOBYPASSRLS NOSUPERUSER NOCREATEDB NOCREATEROLE;

GRANT USAGE ON SCHEMA public, app TO civicsync_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES    IN SCHEMA public TO civicsync_app;
GRANT USAGE, SELECT                  ON ALL SEQUENCES IN SCHEMA public TO civicsync_app;
GRANT EXECUTE                        ON ALL FUNCTIONS IN SCHEMA app    TO civicsync_app;

-- Tables created by future migrations inherit these grants automatically.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO civicsync_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO civicsync_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
    GRANT EXECUTE ON FUNCTIONS TO civicsync_app;

-- The control plane is not reachable by the application role.
REVOKE ALL ON SCHEMA control FROM civicsync_app;
REVOKE ALL ON ALL TABLES IN SCHEMA control FROM civicsync_app;

COMMIT;
```

### `db/migrations/000002_app_role.down.sql`

```sql
BEGIN;

REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM civicsync_app;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM civicsync_app;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA app    FROM civicsync_app;
REVOKE ALL ON SCHEMA public, app             FROM civicsync_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM civicsync_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM civicsync_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app    REVOKE ALL ON FUNCTIONS FROM civicsync_app;

-- The role itself is intentionally left in place.

COMMIT;
```

**Production note.** The dev password is fine locally. In production the role is created
out-of-band with a managed secret. On Neon, `ALTER ROLE … NOSUPERUSER` may be refused
because Neon manages role attributes — acceptable there provided the role was never
granted `BYPASSRLS`. Verify with:

```sql
SELECT rolname, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = 'civicsync_app';
```

---

## Step 5 — The CI guards

Written now, while there is nothing to fix.

### `ops/checks/check_rls.sql`

```sql
-- Fails if any table in `public` is not tenant-isolated.
DO $$
DECLARE offenders text;
BEGIN
    SELECT string_agg(c.relname, ', ' ORDER BY c.relname)
      INTO offenders
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND c.relname <> 'schema_migrations'
       AND (
              NOT c.relrowsecurity
           OR NOT c.relforcerowsecurity
           OR NOT EXISTS (SELECT 1 FROM pg_attribute a
                           WHERE a.attrelid = c.oid
                             AND a.attname  = 'org_id'
                             AND NOT a.attisdropped)
           OR NOT EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid)
           );

    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION
          'Tenant isolation check FAILED. These public tables lack org_id, FORCE RLS, or a policy: %',
          offenders;
    END IF;

    RAISE NOTICE 'Tenant isolation check passed.';
END;
$$;
```

### `ops/checks/check_no_blobs.sql`

```sql
-- Fails if any table stores user file content in the database.
DO $$
DECLARE offenders text;
BEGIN
    SELECT string_agg(c.relname || '.' || a.attname, ', ')
      INTO offenders
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
      JOIN pg_type t ON t.oid = a.atttypid
     WHERE n.nspname IN ('public','telemetry')
       AND c.relkind = 'r'
       AND t.typname = 'bytea'
       AND a.attname NOT IN ('sha256','ciphertext','nonce','otp_hash','signature');

    IF offenders IS NOT NULL THEN
        RAISE EXCEPTION
          'BYTEA check FAILED. File content must live in object storage, not PostgreSQL: %',
          offenders;
    END IF;

    RAISE NOTICE 'BYTEA check passed.';
END;
$$;
```

The allowlist covers short cryptographic values, which are legitimate. Anything else in
`BYTEA` is a file that belongs in R2.

### `ops/checks/check_layers.sh`

```bash
#!/usr/bin/env bash
# internal/domain must stay pure: no imports from app, store, http, or platform.
set -euo pipefail

MODULE="github.com/PivotSolutions-dev/civicsync/api"

cd "$(dirname "$0")/../../api"

if [ ! -d internal/domain ]; then
    echo "check_layers: internal/domain not present yet, skipping"
    exit 0
fi

violations=$(go list -deps ./internal/domain/... 2>/dev/null \
    | grep -E "^${MODULE}/internal/(app|store|http|platform)" || true)

if [ -n "$violations" ]; then
    echo "LAYER VIOLATION — internal/domain must not import:"
    echo "$violations" | sed 's/^/  /'
    echo
    echo "Dependency rule: http -> app -> domain, app -> store. domain imports nothing."
    exit 1
fi

echo "Layer check passed."
```

```bash
chmod +x ops/checks/check_layers.sh
```

---

## Step 6 — The Go service (Fiber v3)

```bash
mkdir -p api/cmd/api api/internal/{domain,app,store} \
         api/internal/http api/internal/platform/{config,database,logging,reqctx}
cd api
go mod init github.com/PivotSolutions-dev/civicsync/api
go get github.com/gofiber/fiber/v3
go get github.com/jackc/pgx/v5
go get github.com/google/uuid
cd ..
```

### `api/internal/platform/config/config.go`

```go
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	Env             string
	Port            int
	AppDatabaseURL  string
	RedisURL        string
	ShutdownTimeout time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		Env:             env("APP_ENV", "development"),
		AppDatabaseURL:  env("APP_DATABASE_URL", ""),
		RedisURL:        env("REDIS_URL", ""),
		ShutdownTimeout: 15 * time.Second,
	}

	port, err := strconv.Atoi(env("PORT", "8080"))
	if err != nil {
		return cfg, fmt.Errorf("PORT must be an integer: %w", err)
	}
	cfg.Port = port

	if cfg.AppDatabaseURL == "" {
		return cfg, fmt.Errorf("APP_DATABASE_URL is required")
	}
	return cfg, nil
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
```

It reads `APP_DATABASE_URL`, never `DATABASE_URL`. The API has no way to connect as the
schema owner even by accident.

### `api/internal/platform/logging/logging.go`

```go
package logging

import (
	"log/slog"
	"os"
)

func New(env string) *slog.Logger {
	opts := &slog.HandlerOptions{Level: slog.LevelInfo}
	if env == "development" {
		opts.Level = slog.LevelDebug
		return slog.New(slog.NewTextHandler(os.Stdout, opts))
	}
	return slog.New(slog.NewJSONHandler(os.Stdout, opts))
}
```

### `api/internal/platform/reqctx/reqctx.go`

This package exists specifically because of `fasthttp`. Read the comments — this is the
one place Fiber's model differs from `net/http` in a way that causes real bugs.

```go
// Package reqctx carries request-scoped identity on a real context.Context.
//
// Fiber runs on fasthttp, which pools and recycles the request context once the
// handler returns. Two consequences shape this package:
//
//  1. fiber.Ctx.Context() returns context.Background() unless something has called
//     SetContext. Middleware() derives a context from c.RequestCtx() instead, so a
//     client disconnect cancels in-flight database work.
//
//  2. Anything outliving the request — a River job, a goroutine — must NOT hold the
//     request context. Detach() copies the identity into a fresh context instead.
package reqctx

import (
	"context"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/requestid"
	"github.com/google/uuid"
)

type key int

const (
	keyRequestID key = iota
	keyOrgID
	keyUserID
)

// Middleware attaches a cancellable, identity-bearing context to the Fiber Ctx.
// Register it after requestid.New().
func Middleware() fiber.Handler {
	return func(c fiber.Ctx) error {
		ctx := context.WithValue(c.RequestCtx(), keyRequestID, requestid.FromContext(c))
		c.SetContext(ctx)
		return c.Next()
	}
}

func WithOrg(ctx context.Context, orgID uuid.UUID) context.Context {
	return context.WithValue(ctx, keyOrgID, orgID)
}

func WithUser(ctx context.Context, userID uuid.UUID) context.Context {
	return context.WithValue(ctx, keyUserID, userID)
}

func RequestID(ctx context.Context) string {
	v, _ := ctx.Value(keyRequestID).(string)
	return v
}

func OrgID(ctx context.Context) (uuid.UUID, bool) {
	v, ok := ctx.Value(keyOrgID).(uuid.UUID)
	return v, ok
}

func UserID(ctx context.Context) (uuid.UUID, bool) {
	v, ok := ctx.Value(keyUserID).(uuid.UUID)
	return v, ok
}

// Detach returns a background context carrying only the copied request identity.
//
// Use this for anything that outlives the request. Passing the request context to a
// background job is the classic fasthttp bug: the context is recycled underneath you
// and you read another request's values.
func Detach(ctx context.Context) context.Context {
	out := context.Background()
	if v := RequestID(ctx); v != "" {
		out = context.WithValue(out, keyRequestID, v)
	}
	if v, ok := OrgID(ctx); ok {
		out = context.WithValue(out, keyOrgID, v)
	}
	if v, ok := UserID(ctx); ok {
		out = context.WithValue(out, keyUserID, v)
	}
	return out
}
```

### `api/internal/platform/database/database.go`

```go
package database

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DB struct {
	Pool *pgxpool.Pool
}

func Open(ctx context.Context, url string) (*DB, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("parse database url: %w", err)
	}
	cfg.MaxConns = 10
	cfg.MinConns = 1

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping: %w", err)
	}
	return &DB{Pool: pool}, nil
}

func (db *DB) Close() { db.Pool.Close() }

// InTenantTx runs fn inside a transaction scoped to orgID.
//
// Tenant context is set with set_config(..., is_local => true), which is
// transaction-scoped. Three consequences worth understanding:
//
//   - Safe under PgBouncer transaction pooling, so production keeps cheap pooled
//     connections.
//   - Context cannot leak into another request's use of the same connection.
//   - SET LOCAL cannot take a bind parameter; set_config can. That is why this is a
//     function call and not a SET statement.
//
// Every query touching tenant data goes through here. There is no other path.
func (db *DB) InTenantTx(ctx context.Context, orgID uuid.UUID, fn func(pgx.Tx) error) error {
	if orgID == uuid.Nil {
		return fmt.Errorf("tenant context required: org id is nil")
	}

	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx,
		`SELECT set_config('app.org_id', $1, true)`, orgID.String()); err != nil {
		return fmt.Errorf("set tenant context: %w", err)
	}

	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
```

### `api/internal/http/errors.go`

```go
package http

import (
	"errors"
	"fmt"

	"github.com/gofiber/fiber/v3"

	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/reqctx"
)

const problemJSON = "application/problem+json"

// errorHandler renders every error as RFC 9457 problem+json, so clients can branch on
// a stable `type` instead of parsing prose.
func errorHandler(c fiber.Ctx, err error) error {
	status := fiber.StatusInternalServerError
	title := "Internal Server Error"

	var fe *fiber.Error
	if errors.As(err, &fe) {
		status = fe.Code
		title = fe.Message
	}

	body := fiber.Map{
		"type":       fmt.Sprintf("https://civicsync.app/problems/%d", status),
		"title":      title,
		"status":     status,
		"request_id": reqctx.RequestID(c.Context()),
	}

	return c.Status(status).JSON(body, problemJSON)
}
```

### `api/internal/http/router.go`

```go
package http

import (
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/logger"
	recoverer "github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/gofiber/fiber/v3/middleware/requestid"

	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/database"
	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/reqctx"
)

func NewApp(db *database.DB) *fiber.App {
	app := fiber.New(fiber.Config{
		AppName:      "civicsync-api",
		ErrorHandler: errorHandler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
	})

	app.Use(requestid.New())
	app.Use(recoverer.New())
	app.Use(logger.New())
	app.Use(reqctx.Middleware()) // must come after requestid.New()

	app.Get("/health", func(c fiber.Ctx) error {
		if err := db.Pool.Ping(c.Context()); err != nil {
			return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
				"status": "degraded",
				"detail": "database unreachable",
			})
		}
		return c.JSON(fiber.Map{"status": "ok"})
	})

	return app
}
```

Note the import alias: the package is `recover`, aliased to `recoverer` so it does not
shadow Go's builtin. `c.Context()` is safe here **only because** `reqctx.Middleware()`
ran first — without it, it returns `context.Background()` with no cancellation.

### `api/cmd/api/main.go`

```go
package main

import (
	"context"
	"fmt"
	"net"
	"os"
	"os/signal"
	"syscall"

	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/config"
	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/database"
	"github.com/PivotSolutions-dev/civicsync/api/internal/platform/logging"

	apihttp "github.com/PivotSolutions-dev/civicsync/api/internal/http"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "fatal: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	log := logging.New(cfg.Env)

	ctx, stop := signal.NotifyContext(context.Background(),
		os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := database.Open(ctx, cfg.AppDatabaseURL)
	if err != nil {
		return err
	}
	defer db.Close()

	app := apihttp.NewApp(db)
	addr := net.JoinHostPort("", fmt.Sprint(cfg.Port))

	errCh := make(chan error, 1)
	go func() {
		log.Info("api listening", "port", cfg.Port, "env", cfg.Env)
		if err := app.Listen(addr); err != nil {
			errCh <- err
		}
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		log.Info("shutting down")
	}

	shutdownCtx, cancel := context.WithTimeout(
		context.Background(), cfg.ShutdownTimeout)
	defer cancel()

	return app.ShutdownWithContext(shutdownCtx)
}
```

`app.Listen` blocks, so it runs in a goroutine and shutdown is driven by the signal
context — the same shape as the `net/http` version, which is why swapping the router
touched so little.

### `api/internal/domain/doc.go`

```go
// Package domain holds pure business types and rules.
//
// It imports nothing from internal/app, internal/store, internal/http, or
// internal/platform — enforced by ops/checks/check_layers.sh in CI.
//
// If you want a database handle or an HTTP request in here, the logic belongs in
// internal/app instead.
package domain
```

---

## Step 7 — Makefile

Recipe lines use **tabs**.

```make
SHELL  := /bin/bash
DB_URL ?= postgres://civicsync:civicsync@localhost:5433/civicsync?sslmode=disable

.PHONY: init up down logs migrate-up migrate-down migrate-redo \
        check-rls check-blobs check-layers lint test build run verify ci

# Run once after cloning. Points git at the versioned hooks in .githooks/
init:
	git config core.hooksPath .githooks
	@echo "git hooks enabled"


up:
	docker compose up -d
	@printf "waiting for postgres"
	@until docker compose exec -T postgres pg_isready -U civicsync >/dev/null 2>&1; \
	  do printf "."; sleep 1; done; echo " ready"

down:
	docker compose down

logs:
	docker compose logs -f

migrate-up:
	migrate -path db/migrations -database "$(DB_URL)" up

migrate-down:
	migrate -path db/migrations -database "$(DB_URL)" down 1

# Proves every migration is reversible. Run before committing a new migration.
migrate-redo:
	migrate -path db/migrations -database "$(DB_URL)" down -all
	migrate -path db/migrations -database "$(DB_URL)" up

# Run through the container so the psql client always matches the server.
check-rls:
	docker compose exec -T postgres psql -U civicsync -d civicsync \
	  -v ON_ERROR_STOP=1 -f /checks/check_rls.sql

check-blobs:
	docker compose exec -T postgres psql -U civicsync -d civicsync \
	  -v ON_ERROR_STOP=1 -f /checks/check_no_blobs.sql

check-layers:
	./ops/checks/check_layers.sh

lint:
	cd api && go vet ./... && golangci-lint run

test:
	cd api && go test ./...

build:
	cd api && go build -o bin/api ./cmd/api

# Leading `-` ignores the exit status: Ctrl-C makes `go run` exit non-zero even
# after a clean graceful shutdown, and the resulting "Error 1" is pure noise.
run:
	-cd api && go run ./cmd/api

# Fast checks — no Docker, no database. This is what the pre-push hook runs.
verify: check-layers lint test build

# Everything, including the database checks. This is what CI runs.
ci: migrate-redo check-rls check-blobs check-layers lint test build
```

---

### Step 7b — The pre-push hook

**What a git hook is, if you have not used one.** Git can run a script of yours at certain
moments — here, just before a `git push` actually sends anything. If the script exits with
an error, the push does not happen. Nothing is broken and nothing is lost; the commit is
still sitting on your machine exactly as it was. You fix the problem and push again.

**Why we want one.** GitHub's branch protection is not enforced on private repositories on
a free organization plan, so CI can go red without blocking a merge. The hook puts the
check somewhere it *does* bite: your own machine, before the code leaves it.

Create `.githooks/pre-push`:

```bash
#!/usr/bin/env bash
# Runs before every `git push`. Non-zero exit cancels the push.
set -euo pipefail

echo "→ running make verify before push…"

if ! make verify; then
    echo
    echo "──────────────────────────────────────────────────────────────"
    echo " PUSH CANCELLED — make verify failed."
    echo
    echo " Nothing is lost. Your commits are still here."
    echo " Fix what is reported above, commit the fix, and push again."
    echo
    echo " Run the checks yourself any time with:   make verify"
    echo " To push anyway (rarely correct):         git push --no-verify"
    echo "──────────────────────────────────────────────────────────────"
    exit 1
fi

echo "→ verify passed, pushing."
```

Make it executable and switch git over to it:

```bash
chmod +x .githooks/pre-push
make init
```

**`make init` is the important line.** By default git looks for hooks in `.git/hooks/`,
which is not version-controlled and would not survive a fresh clone. `core.hooksPath`
points git at `.githooks/` instead, so the hook is committed with the project and a future
developer gets it by running `make init` once.

**What it runs.** `make verify` is the fast subset — layer check, vet, lint, tests, build.
No Docker, no database, a few seconds. The full `make ci`, including the RLS and BYTEA
checks that need PostgreSQL, runs in GitHub Actions where the database is available.

**When it fires and you are in a hurry.** `git push --no-verify` skips it. That is
legitimate when you are pushing a work-in-progress branch nobody will merge, or when the
failure is in something unrelated that you are already fixing. It is not legitimate on a
branch you are about to open a PR from. The hook is a speed bump for you, by you — the
moment you routinely `--no-verify` past it, it has stopped doing anything and you should
either fix the checks or move to GitHub Team and enforce it properly.

**If it seems not to run at all:** you probably have not run `make init` in this clone.
Check with `git config core.hooksPath` — it should print `.githooks`.

---

## Step 8 — CI

### `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main, v2]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:18
        env:
          POSTGRES_USER: civicsync
          POSTGRES_PASSWORD: civicsync
          POSTGRES_DB: civicsync
        # Host port 5433 deliberately: a local Homebrew PostgreSQL commonly holds 5432.
    ports: ["5433:5432"]
        options: >-
          --health-cmd "pg_isready -U civicsync"
          --health-interval 5s --health-timeout 3s --health-retries 10

    env:
      DB_URL: postgres://civicsync:civicsync@localhost:5433/civicsync?sslmode=disable

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: "1.26"
          cache-dependency-path: api/go.sum

      - name: Install tooling
        run: |
          go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
          sudo apt-get update && sudo apt-get install -y postgresql-client
          curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
            | sh -s -- -b "$(go env GOPATH)/bin" v2.12.2
          echo "$(go env GOPATH)/bin" >> "$GITHUB_PATH"

      # CI has no Docker Compose stack — Postgres is a service container — so the
      # check targets are run directly here with the runner's own psql client.
      - name: Prepare check commands for CI
        run: echo "PSQL=psql $DB_URL" >> "$GITHUB_ENV"

      - name: Migrations are reversible
        run: make migrate-redo

      - name: Tenant isolation guard
        run: psql "$DB_URL" -v ON_ERROR_STOP=1 -f ops/checks/check_rls.sql

      - name: No file content in the database
        run: psql "$DB_URL" -v ON_ERROR_STOP=1 -f ops/checks/check_no_blobs.sql

      - name: Layer guard
        run: make check-layers

      # Deliberately NOT golangci-lint-action: it pins its own golangci-lint version,
      # which drifts from the developer's. Installing an explicit version above and
      # running `make lint` means CI runs exactly the command you run locally.
      # Bump the pinned version here and in the prerequisites together.
      - name: Lint
        run: make lint

      - name: Tests
        run: make test

      - name: Build
        run: make build
```

`migrate-redo` applies every migration, rolls them all back, and applies them again. A
broken `down` fails the build on the day it is written, not during an incident.

> **These checks are advisory, for now.** GitHub does not enforce rulesets or branch
> protection on private repositories under a free organization plan, so a red build will
> be visible but will not block a merge. The `pre-push` hook in Step 7b is what actually
> stops bad code leaving your machine. Move to GitHub Team (~$4/user/month) and enable
> required status checks at either of two triggers: **the first time you merge a red
> build**, or **the day a second developer joins.** Not before — you would be paying for
> a control that is currently doing nothing.

---

## Step 9 — Architecture Decision Records

### `docs/adr/0001-pooled-multi-tenancy-with-rls.md`

```markdown
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
- Every new tenant table needs `org_id`, an `org_id`-leading index, and a policy.
  Enforced by `ops/checks/check_rls.sql` in CI.
- Backups are cluster-wide; per-society restore needs a scripted filtered procedure,
  built and rehearsed in Packet 14.

## Rejected

- **Database per society** — linear cost and ops load; incompatible with partitioned
  time-series for IoT.
- **Schema per society** — migrations run N times; partition management becomes N×12 per
  year.
```

### `docs/adr/0002-contract-first-openapi.md`

```markdown
# ADR-0002: Contract-first OpenAPI

- Status: Accepted
- Date: 2026-08-26

## Context

Three surfaces: Go API, TypeScript admin, Dart/Flutter resident app. Dart and TypeScript
share no type system. The prototype's API models were `unknown`/`any`, producing an
avoidable class of integration bugs.

## Decision

`contracts/openapi.yaml` is the source of truth, hand-written and reviewed. Code is
generated from it: `oapi-codegen` (`fiber-v3-server`, strict mode) for Go, `orval` for
the TypeScript client and TanStack Query hooks, `openapi-generator` (`dart-dio`) for
Flutter. CI fails if generated code differs from the committed spec.

## Consequences

- Schema changes appear in review as spec diffs.
- A field renamed in Go cannot silently break the mobile app.
- The spec must be updated before implementation — deliberate friction.
```

### `docs/adr/0003-ledger-based-finance.md`

```markdown
# ADR-0003: Ledger-based finance

- Status: Accepted
- Date: 2026-08-26

## Context

The prototype tracked dues as a `status` column moving through nine states, mutated
escalation during read requests, and deleted the linked lapsed row when a reinstatement
was paid. Balances were not derivable and history was destroyed by design.

The live-data inventory (2026-08-26) found 955 legacy receipts totalling ₹10,72,892 and
exactly one advice row, so converting to a ledger carries little migration risk.

## Decision

Money is modelled as append-only `ledger_entries` against a unit account, with
`invoices`, `invoice_lines`, `receipts`, `adjustments` and `dunning_events` as documents
that produce entries. Outstanding balance is derived, never stored as status. Nothing is
hard-deleted; corrections are reversing entries. Escalation runs as an idempotent
scheduled job writing a `dunning_event` and a penalty entry.

## Consequences

- Any balance can be explained by replaying entries — an auditor requirement, and at
  100 societies the money in scope makes this a liability question, not a nicety.
- Running escalation twice in a day is a no-op.
- More tables and more write discipline than a status column.
- Reporting reads `financial_year`/`period`, never inferred from `paid_at` — v1 uses
  FY-end dating, including dates in 2027.
```

---

## Step 10 — Verify

```bash
cp .env.example .env
make up
make migrate-up
make check-rls        # NOTICE  Tenant isolation check passed.
make check-blobs      # NOTICE  BYTEA check passed.
make run              # separate terminal
curl -s localhost:8080/health     # {"status":"ok"}
make ci               # all green
```

Then confirm the security property everything else rests on:

```bash
psql "postgres://civicsync:civicsync@localhost:5433/civicsync" \
  -c "SELECT rolname, rolsuper, rolbypassrls FROM pg_roles WHERE rolname='civicsync_app';"
```

Both flags must be `f`. If either is `t`, tenant isolation is not enforced and nothing
built above it can be trusted.

Commit:

```bash
git add -A
git commit -m "Packet 00: monorepo skeleton, tenancy foundation, CI guards, ADRs 1-3"
git push -u origin v2
```

---

## What I need back before Packet 01

1. `make ci` passes, and both role flags are `f`
2. Anything that did not compile or behave as written — I will correct this packet
   rather than have you work around it
3. `git log --oneline HEAD..origin/main` from before you branched, if GitHub had commits
   your local checkout was missing. I audited local files and want to know whether the
   domain rules I read were current

## Packet 01 preview

Table spine and its CI checks, master-data framework, settings framework, audit log,
number series, module enablement, partitioning, the outbox — and the cross-tenant
isolation test that deliberately bypasses application code to prove the database itself
refuses the read.
