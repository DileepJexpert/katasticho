-- ─────────────────────────────────────────────────────────────────────────────
-- V4 — country-aware Chart of Accounts templates
-- (docs/INTERNATIONALIZATION_PLAN.md §4).
--
-- The CoA template was keyed by industry only, so a UAE org received the Indian
-- 61-account CoA — which lacks the VAT GL accounts the (already country-aware)
-- TaxSeedService needs for AE (2041 VAT output / 1511 VAT input). Result: VAT
-- rates seeded with NULL GL accounts → VAT couldn't post.
--
-- This migration:
--   1. Adds a `country` column (default 'IN') — every existing template row
--      backfills to India, so India behaviour is byte-for-byte unchanged.
--   2. Widens the uniqueness key to (country, industry, code) so AE and IN can
--      both define code '1500' etc.
--   3. Seeds a Gulf ('AE') TRADING template: the Indian TRADING accounts MINUS
--      the India-only statutory ones (CGST/SGST/IGST input+output, TDS, TCS,
--      PF, ESI, Professional Tax) PLUS Gulf VAT accounts (2041 output / 1511
--      input). Oman reuses this same 'AE' template (identical 5% VAT).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add country, backfill existing rows to India.
ALTER TABLE public.coa_template
    ADD COLUMN IF NOT EXISTS country varchar(2) NOT NULL DEFAULT 'IN';

-- 2. Re-key uniqueness to include country.
ALTER TABLE public.coa_template DROP CONSTRAINT IF EXISTS uq_coa_template;
ALTER TABLE public.coa_template
    ADD CONSTRAINT uq_coa_template UNIQUE (country, industry, code);

-- 3. Seed the Gulf TRADING template = India TRADING minus India-only statutory
--    accounts, cloned with country 'AE'.
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT 'AE', industry, code, name, type, sub_type, parent_code, level, is_system
FROM public.coa_template
WHERE country = 'IN'
  AND industry = 'TRADING'
  AND code NOT IN (
      '1500',  -- GST Input Credit (replaced by 1511 VAT Input)
      '2020',  -- CGST Output Payable
      '2021',  -- SGST Output Payable
      '2022',  -- IGST Output Payable (replaced by 2041 VAT Output)
      '2030',  -- TDS Payable (no withholding tax in the Gulf)
      '2031',  -- TCS Payable
      '2050',  -- PF Payable (no provident fund)
      '2060',  -- ESI Payable (no state insurance)
      '2070'   -- Professional Tax Payable
  )
ON CONFLICT (country, industry, code) DO NOTHING;

-- 4. Add the Gulf VAT GL accounts the TaxSeedService AE path resolves
--    (2041 output / 1511 input). Parents mirror the Indian tax accounts:
--    output VAT under Liabilities (2000), input VAT under Assets (1000).
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system) VALUES
    ('AE', 'TRADING', '1511', 'VAT Input Credit',  'ASSET',     'CURRENT_ASSET',     '1000', 2, true),
    ('AE', 'TRADING', '2041', 'VAT Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true)
ON CONFLICT (country, industry, code) DO NOTHING;
