-- ─────────────────────────────────────────────────────────────────────────────
-- V3 — Gulf + Africa currencies for the multi-country expansion
-- (docs/INTERNATIONALIZATION_PLAN.md §6).
--
-- The baseline seed shipped only 10 currencies (AED AUD CAD CHF EUR GBP INR JPY
-- SGD USD). The target markets (UAE / Oman / Kenya, + neighbouring GCC) need
-- their currencies present, AND with the correct minor-unit precision — the
-- three-decimal Gulf dinars (OMR/BHD/KWD) are the ones that break a hardcoded
-- 2-decimal assumption.
--
-- Additive + idempotent: ON CONFLICT (code) DO NOTHING leaves every existing
-- row (incl. AED at 2dp) untouched, so India behaviour is unchanged.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO public.currency (code, name, symbol, decimal_places, is_active) VALUES
    ('OMR', 'Omani Rial',     'ر.ع.', 3, true),   -- 3 decimals (baisa)
    ('BHD', 'Bahraini Dinar', '.د.ب', 3, true),   -- 3 decimals (fils)
    ('KWD', 'Kuwaiti Dinar',  'د.ك',  3, true),   -- 3 decimals (fils)
    ('SAR', 'Saudi Riyal',    'ر.س',  2, true),
    ('QAR', 'Qatari Riyal',   'ر.ق',  2, true),
    ('KES', 'Kenyan Shilling', 'KSh', 2, true)
ON CONFLICT (code) DO NOTHING;
