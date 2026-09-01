-- Fails if any table in `public` is not tenant-isolated.
-- Run after migrations, in CI and before every deploy.

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
