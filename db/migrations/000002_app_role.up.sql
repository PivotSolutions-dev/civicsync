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
