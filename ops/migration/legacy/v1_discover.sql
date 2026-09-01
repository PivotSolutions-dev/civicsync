-- =====================================================================
-- CivicSync — schema discovery
-- Run this FIRST, before the inventory. Read-only.
-- pgAdmin: Query Tool (F5), then export the grid to CSV (F8).
-- Tells me exactly which schema this database is running.
-- =====================================================================

SELECT c.relname                                   AS table_name,
       a.attnum                                    AS col_no,
       a.attname                                   AS column_name,
       format_type(a.atttypid, a.atttypmod)        AS data_type,
       CASE WHEN a.attnotnull THEN 'NOT NULL' END  AS nullability,
       pg_get_expr(d.adbin, d.adrelid)             AS default_expr,
       c.reltuples::bigint                         AS approx_rows
FROM       pg_class     c
JOIN       pg_namespace n ON n.oid = c.relnamespace
JOIN       pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
LEFT JOIN  pg_attrdef   d ON d.adrelid = c.oid AND d.adnum = a.attnum
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
ORDER BY c.relname, a.attnum;


-- =====================================================================
-- Then run this one separately. It reports which golang-migrate version
-- the database is at. If it errors with "relation does not exist", say so
-- -- that itself tells me this database was never managed by CivicSync
-- migrations.
-- =====================================================================

-- SELECT version, dirty FROM schema_migrations;


-- =====================================================================
-- And this one, to see every database on the server at once.
-- =====================================================================

-- SELECT datname,
--        pg_size_pretty(pg_database_size(datname)) AS size
-- FROM pg_database
-- WHERE datistemplate = false
-- ORDER BY pg_database_size(datname) DESC;
