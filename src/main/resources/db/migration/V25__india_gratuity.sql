-- V25 — India gratuity provision (Payment of Gratuity Act 1972).
--
-- The Gulf gets end-of-service gratuity (V15: 2050 Provision / 5060 Expense);
-- India's parallel is the Payment of Gratuity Act — 15 days' wages (basic+DA)
-- for every completed year of service, payable after 5 continuous years,
-- capped at Rs 20 lakh at payout. Accountants provision the liability monthly
-- (AS 15 / Ind AS 19) so the P&L matches the period the employee earned it.
--
-- India CANNOT reuse the Gulf codes: 2050 is "PF Payable" in the Indian CoA
-- template and 5060 is unseeded for IN. Two new India-only codes are added
-- (confirmed free across every migration): 2080 Gratuity Provision (liability)
-- and 5130 Gratuity Expense. Kept OUT of DefaultAccountPurpose (resolved by
-- direct code lookup on the IN branch) — same carve-out the Gulf 5060/2050
-- pair uses, so a Gulf org and an India org never cross-bind their gratuity GLs.
--
-- Existing India orgs pick up the two accounts automatically on next boot via
-- AccountService.seedFromTemplate + DefaultAccountService repair sweep (the
-- V5 / V22 precedent) — no backfill SQL. ensureIndiaGratuityAccount() in
-- IndiaGratuityService is the self-heal safety net.

-- 1. Seed the two India gratuity accounts for all four India industries.
INSERT INTO public.coa_template (country, industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT 'IN', ind.industry, acc.code, acc.name, acc.type, acc.sub_type, acc.parent_code, acc.level, true
FROM (VALUES ('TRADING'), ('RETAIL'), ('SERVICES'), ('F_AND_B')) AS ind(industry)
CROSS JOIN (VALUES
    ('2080', 'Gratuity Provision', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2),
    ('5130', 'Gratuity Expense',   'EXPENSE',   'OPERATING_EXPENSE', '5000', 2)
) AS acc(code, name, type, sub_type, parent_code, level)
ON CONFLICT (country, industry, code) DO NOTHING;

-- 2. Per-period accrual ledger — one row per (org, year, month) posting run,
--    for idempotency (a re-run or two-replica scheduler must not double-book)
--    and an audit trail of the monthly provision.
CREATE TABLE india_gratuity_accrual (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    period_year INTEGER NOT NULL,
    period_month INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    total_amount NUMERIC(15, 2) NOT NULL,
    employee_count INTEGER NOT NULL,
    journal_entry_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT false
);

-- One accrual per org per period — the idempotency guarantee.
CREATE UNIQUE INDEX uq_india_gratuity_accrual_period
    ON india_gratuity_accrual (org_id, period_year, period_month)
    WHERE is_deleted = false;
