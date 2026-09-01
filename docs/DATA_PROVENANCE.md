# CivicSync — Data Provenance Register

Authoritative record of where CivicSync production data lives and which snapshots
exist. Every migration rehearsal and the final cutover reconcile against a snapshot
listed here. Append to this file; never rewrite history in it.

## Authoritative source

| | |
| --- | --- |
| **System of record** | Neon PostgreSQL, project endpoint `ep-sweet-fire-aodx1dwy`, region `ap-southeast-1` |
| **Database** | `civicsync` |
| **Role** | `neondb_owner` |
| **Status** | Live prototype data. Free plan — compute scale-to-zero after 5 min idle (auto-resumes) |
| **Confirmed** | 2026-08-26 |

Use the **non-pooled** endpoint for `pg_dump`/`pg_restore`. The `-pooler` host runs
through PgBouncer and can produce incomplete dumps.

## Other copies — NOT authoritative

| Location | State | Notes |
| --- | --- | --- |
| Local Postgres `civicsync` @ localhost:5432 | Diverged | Was at migration 013; migrations 014–029 applied locally on 2026-08-25. ~365 members, ~955 payments. Treat as a dev copy only |
| Local Postgres `bwa_hq` @ localhost:5432 | Legacy | Old BWA prototype schema. Source for the original legacy import. Retain, do not migrate from directly |

## Snapshots

| Date | Source | File | SHA-256 | Size | Off-machine copies |
| --- | --- | --- | --- | --- | --- |
| 2026-08-25 | Neon `civicsync` | `civicsync_neon_2026-08-25.dump` | `5acf302588f161cfa2be9ddff5bd83219f2093972ed32fef5278871c67bcd99a` | 5.4 MB | _TODO — record where copied_ |

Taken with:

```bash
pg_dump "$NEON_DIRECT_URL" --format=custom --no-owner --no-acl \
  --file=civicsync_neon_YYYY-MM-DD.dump
shasum -a 256 civicsync_neon_YYYY-MM-DD.dump
```

## Rules

1. Snapshot files are never committed to this repository. Record the checksum here only.
2. Every snapshot must exist in at least two locations, one of them off the development machine.
3. Verify a snapshot before relying on it: `pg_restore --list <file> | head`.
4. The v1 database is read-only from the moment v2 ETL rehearsals begin.
5. Credentials are never recorded in this file.

## Open items

- [ ] Record off-machine copy locations for the 2026-08-25 snapshot
- [ ] Rotate `neondb_owner` password (exposed in a chat transcript 2026-08-26)
- [ ] Run `scripts/v1_inventory.sql` against Neon and attach the result
- [ ] Determine whether `member_documents` rows exist with a `file_path` but no `file_data`
      (bytes may have been lost with an ephemeral Render filesystem)
- [ ] Confirm whether local `civicsync` holds any history Neon does not
