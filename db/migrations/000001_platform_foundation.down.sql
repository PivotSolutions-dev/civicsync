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
