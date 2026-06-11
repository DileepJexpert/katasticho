-- TCS 206C(1H): seller collects tax at source on sale consideration above
-- ₹50 lakh per buyer per FY (org toggle tax.tcs_enabled; default rate 0.1%).
--
-- 1. invoice.tcs_amount — collected on top of subtotal + GST.
-- 2. "TCS Payable" (2031) added to the CoA template for every industry and
--    backfilled into every existing org's chart so the posting rule can
--    credit it (DefaultAccountPurpose.TCS_PAYABLE resolves by code 2031).

ALTER TABLE invoice
    ADD COLUMN tcs_amount NUMERIC(15,2) NOT NULL DEFAULT 0;

INSERT INTO coa_template (industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT DISTINCT industry, '2031', 'TCS Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, TRUE
FROM coa_template
WHERE NOT EXISTS (
    SELECT 1 FROM coa_template t2
    WHERE t2.industry = coa_template.industry AND t2.code = '2031'
);

-- Existing orgs: add the account next to TDS Payable (2030). New orgs get it
-- from the template at signup.
INSERT INTO account (org_id, code, name, type, sub_type, parent_id, level, is_system, description)
SELECT o.id, '2031', 'TCS Payable', 'LIABILITY', 'CURRENT_LIABILITY',
       (SELECT a2.id FROM account a2
        WHERE a2.org_id = o.id AND a2.code = '2000' AND a2.is_deleted = FALSE
        LIMIT 1),
       2, TRUE, 'Tax collected at source u/s 206C(1H)'
FROM organisation o
WHERE NOT EXISTS (
    SELECT 1 FROM account a
    WHERE a.org_id = o.id AND a.code = '2031' AND a.is_deleted = FALSE
);
