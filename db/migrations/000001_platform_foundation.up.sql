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
different connection pool. This column is the escape hatch from pooled multi-tenancy.';

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
