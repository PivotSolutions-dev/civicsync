-- =====================================================================
-- CivicSync v1 — follow-up probes
-- Aggregate patterns only; no personal data is returned.
-- Run against Neon `civicsync`. Read-only. F5, then F8 to export.
-- =====================================================================

WITH f AS (

-- ---------- phone: what shape is the data actually in? ----------
            SELECT '1_phone'::text section,
                   'digits='||length(regexp_replace(coalesce(phone,''),'\D','','g'))::text k1,
                   ''::text k2, count(*)::bigint n
              FROM members WHERE deleted_at IS NULL
              GROUP BY 1,2,3
  UNION ALL SELECT '1_phone', 'blank_or_null', '', count(*)
              FROM members WHERE deleted_at IS NULL AND coalesce(trim(phone),'')=''
  UNION ALL SELECT '1_phone', 'starts_with_91', '', count(*)
              FROM members WHERE deleted_at IS NULL
                AND regexp_replace(phone,'\D','','g') LIKE '91%'
  UNION ALL SELECT '1_phone', 'starts_with_plus', '', count(*)
              FROM members WHERE deleted_at IS NULL AND phone LIKE '+%'
  UNION ALL SELECT '1_phone', 'contains_non_digit', '', count(*)
              FROM members WHERE deleted_at IS NULL AND phone ~ '\D'

-- ---------- email: real, placeholder, or empty? ----------
  UNION ALL SELECT '2_email', 'blank_or_null', '', count(*)
              FROM members WHERE deleted_at IS NULL AND coalesce(trim(email),'')=''
  UNION ALL SELECT '2_email', 'no_at_sign', '', count(*)
              FROM members WHERE deleted_at IS NULL
                AND coalesce(trim(email),'')<>'' AND email NOT LIKE '%@%'
  UNION ALL SELECT '2_email', 'domain='||lower(split_part(email,'@',2)), '', count(*)
              FROM members WHERE deleted_at IS NULL AND email LIKE '%@%'
              GROUP BY 2

-- ---------- flat numbers that are not plain integers ----------
  UNION ALL SELECT '3_flat', 'tower='||tower, 'pattern='||regexp_replace(flat_no,'[0-9]','N','g'), count(*)
              FROM members WHERE deleted_at IS NULL AND flat_no !~ '^[0-9]+$'
              GROUP BY 2,3
  UNION ALL SELECT '3_flat', 'flat_no_length='||length(flat_no)::text, '', count(*)
              FROM members WHERE deleted_at IS NULL GROUP BY 2

-- ---------- documents: are the bytes actually present? ----------
  UNION ALL SELECT '4_docs', 'file_data_present', '', count(*)
              FROM member_documents WHERE file_data IS NOT NULL AND length(file_data)>0
  UNION ALL SELECT '4_docs', 'file_data_missing_PATH_ONLY', '', count(*)
              FROM member_documents WHERE file_data IS NULL OR length(file_data)=0
  UNION ALL SELECT '4_docs', 'total_bytes', '', coalesce(sum(length(file_data)),0)
              FROM member_documents
  UNION ALL SELECT '4_docs', 'notice_attachment_present', '', count(*)
              FROM notices WHERE attachment_data IS NOT NULL AND length(attachment_data)>0

-- ---------- payments: future dating and reference fill ----------
  UNION ALL SELECT '5_payments', 'paid_at_in_future', '', count(*)
              FROM payments WHERE paid_at > now()
  UNION ALL SELECT '5_payments', 'paid_at_null', '', count(*)
              FROM payments WHERE paid_at IS NULL
  UNION ALL SELECT '5_payments', 'payment_reference_blank', '', count(*)
              FROM payments WHERE coalesce(trim(payment_reference),'')=''
  UNION ALL SELECT '5_payments', 'financial_year_blank', '', count(*)
              FROM payments WHERE coalesce(trim(financial_year),'')=''
  UNION ALL SELECT '5_payments', 'paid_year='||to_char(paid_at,'YYYY'), '', count(*)
              FROM payments WHERE paid_at IS NOT NULL GROUP BY 2
  UNION ALL SELECT '5_payments', 'payments_per_member_max', '', max(c)
              FROM (SELECT member_id, count(*) c FROM payments GROUP BY 1) x
  UNION ALL SELECT '5_payments', 'members_with_no_payment', '', count(*)
              FROM members m WHERE m.deleted_at IS NULL
                AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.member_id=m.id)

-- ---------- soft-deleted members: do they carry history? ----------
  UNION ALL SELECT '6_deleted', 'deleted_with_payments', '', count(DISTINCT m.id)
              FROM members m JOIN payments p ON p.member_id=m.id
              WHERE m.deleted_at IS NOT NULL
  UNION ALL SELECT '6_deleted', 'deleted_tower='||tower, '', count(*)
              FROM members WHERE deleted_at IS NOT NULL GROUP BY 2
)
SELECT section, k1 AS metric, k2 AS detail, n AS value
FROM f ORDER BY section, k1, k2;
