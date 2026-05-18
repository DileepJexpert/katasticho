-- Add Opening Balance Equity account to CoA template for all industries.
-- Used when recording opening stock so the double-entry stays balanced:
--   DR 1200 Inventory Asset  /  CR 3040 Opening Balance Equity

INSERT INTO coa_template (industry, code, name, type, sub_type, level, parent_code)
VALUES ('TRADING', '3040', 'Opening Balance Equity', 'EQUITY', 'OWNERS_EQUITY', 2, '3000')
ON CONFLICT DO NOTHING;

-- Seed the account into every existing org that has a CoA derived from TRADING template.
-- This mirrors what OrgBootstrapService.seedFromTemplate() does for new orgs.
INSERT INTO account (id, org_id, code, name, type, sub_type, level, parent_id, is_deleted, created_at, updated_at)
SELECT gen_random_uuid(),
       a.org_id,
       '3040',
       'Opening Balance Equity',
       'EQUITY',
       'OWNERS_EQUITY',
       2,
       a.id,
       FALSE,
       NOW(),
       NOW()
FROM account a
WHERE a.code = '3000'
  AND a.type = 'EQUITY'
  AND a.is_deleted = FALSE
  AND NOT EXISTS (
    SELECT 1 FROM account a2
    WHERE a2.org_id = a.org_id AND a2.code = '3040' AND a2.is_deleted = FALSE
  );
