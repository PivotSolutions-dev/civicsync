-- =====================================================================
-- CivicSync — version-safe migration inventory
-- Uses only columns present since migration 013, so it runs on ANY
-- CivicSync database. Reports the migration version and probes for
-- later columns via information_schema rather than referencing them.
-- Read-only. pgAdmin: run with F5, export grid with F8.
-- =====================================================================

WITH inv AS (

-- ---------- 0. which database, which migration version ----------
            SELECT '00_schema'::text section, 'database'::text k1, current_database()::text k2, NULL::bigint n, NULL::numeric amt
  UNION ALL SELECT '00_schema', 'migrate_version', version::text || CASE WHEN dirty THEN ' (DIRTY!)' ELSE '' END, NULL, NULL
              FROM schema_migrations
  -- probe for post-013 columns without referencing them directly
  UNION ALL SELECT '00_schema', 'later_column_present', p.tbl || '.' || p.col, 1, NULL
              FROM (VALUES
                     ('service_integrations','business_phone'),
                     ('service_integrations','whatsapp_phone_number_id'),
                     ('notices','attachment_data'),
                     ('payments','financial_year'),
                     ('payments','payment_reference'),
                     ('member_documents','file_data'),
                     ('payment_request_members','reinstates_payment_request_member_id'),
                     ('organization_settings','google_drive_shared_url')
                   ) AS p(tbl,col)
              WHERE EXISTS (SELECT 1 FROM information_schema.columns c
                            WHERE c.table_schema='public' AND c.table_name=p.tbl AND c.column_name=p.col)
  UNION ALL SELECT '00_schema', 'later_table_present', t.tbl, 1, NULL
              FROM (VALUES ('payment_escalation_settings'),('whatsapp_webhook_events')) AS t(tbl)
              WHERE EXISTS (SELECT 1 FROM information_schema.tables i
                            WHERE i.table_schema='public' AND i.table_name=t.tbl)

-- ---------- 1. exact row counts ----------
  UNION ALL SELECT '01_counts', 'members_total',            '', count(*), NULL FROM members
  UNION ALL SELECT '01_counts', 'members_live',             '', count(*), NULL FROM members WHERE deleted_at IS NULL
  UNION ALL SELECT '01_counts', 'members_soft_deleted',     '', count(*), NULL FROM members WHERE deleted_at IS NOT NULL
  UNION ALL SELECT '01_counts', 'users',                    '', count(*), NULL FROM users
  UNION ALL SELECT '01_counts', 'member_documents',         '', count(*), NULL FROM member_documents
  UNION ALL SELECT '01_counts', 'payment_requests',         '', count(*), NULL FROM payment_requests
  UNION ALL SELECT '01_counts', 'payment_request_members',  '', count(*), NULL FROM payment_request_members
  UNION ALL SELECT '01_counts', 'payments',                 '', count(*), NULL FROM payments
  UNION ALL SELECT '01_counts', 'expense_vouchers',         '', count(*), NULL FROM expense_vouchers
  UNION ALL SELECT '01_counts', 'voucher_assignments',      '', count(*), NULL FROM expense_voucher_assignments
  UNION ALL SELECT '01_counts', 'notices',                  '', count(*), NULL FROM notices
  UNION ALL SELECT '01_counts', 'activity_logs',            '', count(*), NULL FROM activity_logs
  UNION ALL SELECT '01_counts', 'migration_audit',          '', count(*), NULL FROM migration_audit
  UNION ALL SELECT '01_counts', 'service_integrations',     '', count(*), NULL FROM service_integrations

-- ---------- 2. members ----------
  UNION ALL SELECT '02_members', 'status='||status, 'verify='||verification_status, count(*), NULL
              FROM members WHERE deleted_at IS NULL GROUP BY status, verification_status
  UNION ALL SELECT '02_members', 'tower='||tower, '', count(*), NULL
              FROM members WHERE deleted_at IS NULL GROUP BY tower
  UNION ALL SELECT '02_members', 'contact_verified', 'phone='||phone_verified||' email='||email_verified, count(*), NULL
              FROM members WHERE deleted_at IS NULL GROUP BY phone_verified, email_verified

-- ---------- 3. users / roles ----------
  UNION ALL SELECT '03_users', 'role='||role, 'org_role='||organization_role, count(*), NULL
              FROM users GROUP BY role, organization_role

-- ---------- 4. documents ----------
  UNION ALL SELECT '04_documents', 'type='||document_type, 'status='||status, count(*), NULL
              FROM member_documents GROUP BY document_type, status
  UNION ALL SELECT '04_documents', 'file_path_blank', '', count(*), NULL
              FROM member_documents WHERE coalesce(trim(file_path),'') = ''

-- ---------- 5. payment advice (the money owed) ----------
  UNION ALL SELECT '05_advice', 'status='||status, '', count(*), sum(amount)
              FROM payment_request_members GROUP BY status
  UNION ALL SELECT '05_advice', 'GRAND_TOTAL', '', count(*), sum(amount)
              FROM payment_request_members

-- ---------- 6. payment requests ----------
  UNION ALL SELECT '06_requests', 'status='||status, 'target='||target_type, count(*), sum(amount)
              FROM payment_requests GROUP BY status, target_type

-- ---------- 7. payments received (the money in) ----------
  UNION ALL SELECT '07_payments', 'provider='||provider, 'status='||status, count(*), sum(amount)
              FROM payments GROUP BY provider, status
  UNION ALL SELECT '07_payments', 'GRAND_TOTAL_SUCCESS', '', count(*), sum(amount)
              FROM payments WHERE status='success'
  UNION ALL SELECT '07_payments', 'unlinked_to_advice', '', count(*), sum(amount)
              FROM payments WHERE payment_request_member_id IS NULL
  UNION ALL SELECT '07_payments', 'period='||coalesce(nullif(period,''),'(blank)'), '', count(*), sum(amount)
              FROM payments GROUP BY period

-- ---------- 8. vouchers ----------
  UNION ALL SELECT '08_vouchers', 'type='||voucher_type, 'status='||status, count(*), sum(amount)
              FROM expense_vouchers GROUP BY voucher_type, status

-- ---------- 9. data-quality probes (non-zero = a migration decision) ----------
  UNION ALL SELECT '09_probe', 'flat_no_non_numeric', '', count(*), NULL
              FROM members WHERE deleted_at IS NULL AND flat_no !~ '^[0-9]+$'
  UNION ALL SELECT '09_probe', 'tower_blank', '', count(*), NULL
              FROM members WHERE deleted_at IS NULL AND coalesce(trim(tower),'')=''
  UNION ALL SELECT '09_probe', 'phone_not_10_digits', '', count(*), NULL
              FROM members WHERE deleted_at IS NULL AND coalesce(regexp_replace(phone,'\D','','g'),'') !~ '^[0-9]{10}$'
  UNION ALL SELECT '09_probe', 'email_missing_or_bad', '', count(*), NULL
              FROM members WHERE deleted_at IS NULL AND (coalesce(email,'')='' OR email NOT LIKE '%@%.%')
  UNION ALL SELECT '09_probe', 'aadhaar_stored', '', count(*), NULL
              FROM members WHERE coalesce(trim(aadhaar_number),'')<>''
  UNION ALL SELECT '09_probe', 'dup_tower_flat_live', '', count(*), NULL
              FROM (SELECT tower,flat_no FROM members WHERE deleted_at IS NULL
                    GROUP BY tower,flat_no HAVING count(*)>1) d
  UNION ALL SELECT '09_probe', 'dup_phone_live', '', count(*), NULL
              FROM (SELECT phone FROM members WHERE deleted_at IS NULL AND coalesce(phone,'')<>''
                    GROUP BY phone HAVING count(*)>1) d
  UNION ALL SELECT '09_probe', 'members_without_user', '', count(*), NULL
              FROM members m LEFT JOIN users u ON u.member_id=m.id
              WHERE m.deleted_at IS NULL AND u.id IS NULL
  UNION ALL SELECT '09_probe', 'orphan_advice_no_member', '', count(*), NULL
              FROM payment_request_members prm LEFT JOIN members m ON m.id=prm.member_id WHERE m.id IS NULL
  UNION ALL SELECT '09_probe', 'orphan_payment_no_member', '', count(*), NULL
              FROM payments p LEFT JOIN members m ON m.id=p.member_id WHERE m.id IS NULL
  UNION ALL SELECT '09_probe', 'orphan_payment_no_advice', '', count(*), NULL
              FROM payments p LEFT JOIN payment_request_members prm ON prm.id=p.payment_request_member_id
              WHERE p.payment_request_member_id IS NOT NULL AND prm.id IS NULL
  UNION ALL SELECT '09_probe', 'paid_advice_without_payment', '', count(*), NULL
              FROM payment_request_members prm
              WHERE prm.status='paid'
                AND NOT EXISTS (SELECT 1 FROM payments p
                                WHERE p.payment_request_member_id=prm.id AND p.status='success')

-- ---------- 10. legacy import provenance ----------
  UNION ALL SELECT '10_legacy', 'source='||source_name, 'target='||target_table, count(*), NULL
              FROM migration_audit GROUP BY source_name, target_table

-- ---------- 11. date ranges ----------
  UNION ALL SELECT '11_range', 'members_created',
              to_char(min(created_at),'YYYY-MM-DD')||' .. '||to_char(max(created_at),'YYYY-MM-DD'), NULL, NULL FROM members
  UNION ALL SELECT '11_range', 'payments_paid_at',
              coalesce(to_char(min(paid_at),'YYYY-MM-DD')||' .. '||to_char(max(paid_at),'YYYY-MM-DD'),'(none)'), NULL, NULL FROM payments
  UNION ALL SELECT '11_range', 'advice_due_date',
              coalesce(to_char(min(due_date),'YYYY-MM-DD')||' .. '||to_char(max(due_date),'YYYY-MM-DD'),'(none)'), NULL, NULL
              FROM payment_request_members
)
SELECT section,
       k1 AS metric,
       k2 AS detail,
       n  AS row_count,
       round(amt,2) AS amount
FROM inv
ORDER BY section, k1, k2;
