-- Fails if any table stores user file content in the database.
-- File content belongs in object storage. See PLATFORM_ENGINEERING_STANDARDS §2.

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
