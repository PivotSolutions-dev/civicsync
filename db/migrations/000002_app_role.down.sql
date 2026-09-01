BEGIN;

REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM civicsync_app;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM civicsync_app;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA app    FROM civicsync_app;
REVOKE ALL ON SCHEMA public, app             FROM civicsync_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM civicsync_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM civicsync_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA app    REVOKE ALL ON FUNCTIONS FROM civicsync_app;

-- The role itself is intentionally left in place; other databases may use it.

COMMIT;
