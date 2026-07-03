-- ─────────────────────────────────────────────────────────────────────────────
-- V22 — complete the country × industry CoA template matrix.
--
-- V4 seeded ('AE','TRADING') and V15 cloned it to ('OM','TRADING') — but a
-- Gulf org that signed up as RETAIL / SERVICES / F_AND_B silently fell back
-- to the INDIAN chart (CGST/SGST/IGST/TDS/TCS/PF/ESI/PT accounts, no VAT
-- GLs), and its first gratuity accrual hard-failed on the missing 5060.
-- Kenya had no template at all. This migration fills the matrix:
--
--   * AE + OM × {RETAIL, SERVICES, F_AND_B}: clone the Indian industry
--     template minus the 9 India-only statutory accounts, plus Gulf VAT
--     (1511 input / 2041 output) and gratuity (2050 provision / 5060 expense)
--     — the exact shape V4+V15 gave TRADING.
--   * KE × all four industries: same India-minus-statutory clone plus VAT
--     1511/2041 (KRA VAT, 16%). No gratuity rows — Kenyan service pay is
--     modelled with the Kenya payroll phase, not here.
--
-- Existing orgs pick the new rows up through the idempotent boot-time repair
-- sweep (OrgBootstrapService → AccountService.seedFromTemplate), which after
-- this release also resolves the org's template country through its
-- CountryProfile before falling back to 'IN'.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Gulf RETAIL / SERVICES / F_AND_B — India clone minus Indian statutory.
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT gulf.country, t.industry, t.code, t.name, t.type, t.sub_type, t.parent_code, t.level, t.is_system
FROM public.coa_template t
CROSS JOIN (VALUES ('AE'), ('OM')) AS gulf(country)
WHERE t.country = 'IN'
  AND t.industry IN ('RETAIL', 'SERVICES', 'F_AND_B')
  AND t.code NOT IN (
      '1500',  -- GST Input Credit (replaced by 1511 VAT Input)
      '2020',  -- CGST Output Payable
      '2021',  -- SGST Output Payable
      '2022',  -- IGST Output Payable (replaced by 2041 VAT Output)
      '2030',  -- TDS Payable
      '2031',  -- TCS Payable
      '2050',  -- PF Payable (code reused as Gratuity Provision in the Gulf)
      '2060',  -- ESI Payable
      '2070'   -- Professional Tax Payable
  )
ON CONFLICT (country, industry, code) DO NOTHING;

-- 2. Gulf VAT + gratuity accounts for the three new industries (both countries).
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT gulf.country, ind.industry, acc.code, acc.name, acc.type, acc.sub_type, acc.parent_code, acc.level, acc.is_system
FROM (VALUES ('AE'), ('OM')) AS gulf(country)
CROSS JOIN (VALUES ('RETAIL'), ('SERVICES'), ('F_AND_B')) AS ind(industry)
CROSS JOIN (VALUES
    ('1511', 'VAT Input Credit',   'ASSET',     'CURRENT_ASSET',      '1000', 2, true),
    ('2041', 'VAT Output Payable', 'LIABILITY', 'CURRENT_LIABILITY',  '2000', 2, true),
    ('2050', 'Gratuity Provision', 'LIABILITY', 'CURRENT_LIABILITY',  '2000', 2, true),
    ('5060', 'Gratuity Expense',   'EXPENSE',   'OPERATING_EXPENSE',  '5000', 2, true)
) AS acc(code, name, type, sub_type, parent_code, level, is_system)
ON CONFLICT (country, industry, code) DO NOTHING;

-- 3. Kenya — all four industries, India clone minus Indian statutory.
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT 'KE', t.industry, t.code, t.name, t.type, t.sub_type, t.parent_code, t.level, t.is_system
FROM public.coa_template t
WHERE t.country = 'IN'
  AND t.industry IN ('TRADING', 'RETAIL', 'SERVICES', 'F_AND_B')
  AND t.code NOT IN ('1500', '2020', '2021', '2022', '2030', '2031', '2050', '2060', '2070')
ON CONFLICT (country, industry, code) DO NOTHING;

-- 4. Kenya VAT accounts for all four industries.
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT 'KE', ind.industry, acc.code, acc.name, acc.type, acc.sub_type, acc.parent_code, acc.level, acc.is_system
FROM (VALUES ('TRADING'), ('RETAIL'), ('SERVICES'), ('F_AND_B')) AS ind(industry)
CROSS JOIN (VALUES
    ('1511', 'VAT Input Credit',   'ASSET',     'CURRENT_ASSET',     '1000', 2, true),
    ('2041', 'VAT Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true)
) AS acc(code, name, type, sub_type, parent_code, level, is_system)
ON CONFLICT (country, industry, code) DO NOTHING;
