-- ─────────────────────────────────────────────────────────────────────────────
-- V15 — Gulf gratuity GL accounts.
--
-- UAE Federal Decree-Law 33/2021 + Oman Royal Decree 35/2003 both require a
-- monthly accrual of end-of-service gratuity. The accrual is booked as:
--     DR Gratuity Expense (5060)
--     CR Gratuity Provision (2050)
-- and consumed on termination payout. India's PayrollService uses 2050 for
-- "PF Payable" — but V4 excludes 2050 from the AE template (no provident
-- fund in the Gulf), so the code is free to mean "Gratuity Provision" in AE
-- and OM. 5060 isn't used anywhere yet, so it's added net-new for Gulf orgs.
--
-- Oman's TRADING template doesn't exist in V4 (AE-only) — but OmanProfile
-- uses 'OM' as its country code, so we either need a clone of the AE rows
-- under OM, or DefaultAccountService can fall back. Simplest path: clone
-- AE's full TRADING template into OM here (single-trip, idempotent). This
-- also unblocks the OM tax-engine path that V4 silently left orphaned.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Clone the entire AE TRADING template into OM (Oman's labour law mirrors
--    UAE's chart for accounting purposes — only the gratuity tier-break and
--    statutory holidays differ).
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT 'OM', industry, code, name, type, sub_type, parent_code, level, is_system
FROM public.coa_template
WHERE country = 'AE'
  AND industry = 'TRADING'
ON CONFLICT (country, industry, code) DO NOTHING;

-- 2. Seed the two Gulf gratuity accounts (AE + OM).
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system) VALUES
    ('AE', 'TRADING', '2050', 'Gratuity Provision', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
    ('AE', 'TRADING', '5060', 'Gratuity Expense',   'EXPENSE',   'OPERATING_EXPENSE', '5000', 2, true),
    ('OM', 'TRADING', '2050', 'Gratuity Provision', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, true),
    ('OM', 'TRADING', '5060', 'Gratuity Expense',   'EXPENSE',   'OPERATING_EXPENSE', '5000', 2, true)
ON CONFLICT (country, industry, code) DO NOTHING;
