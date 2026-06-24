-- ─────────────────────────────────────────────────────────────────────────────
-- V16 — track end-of-service gratuity payout on hr_offboarding (AE/OM orgs).
--
-- The V15 accrual builds up the 2050 Gratuity Provision liability month by
-- month. On termination, the offboarding flow must DEBIT that provision and
-- CREDIT cash/bank for the lump-sum due (UAE Decree-Law 33/2021 + Oman Royal
-- Decree 35/2003 formulas, computed by GulfPayrollService.compute()).
--
-- Three columns:
--   gratuity_journal_entry_id — FK to the posting journal (enforces
--     idempotency — re-running pay-gratuity refuses when this is set).
--   gratuity_amount — capped gratuity actually paid (= GratuityResult.cappedGratuity).
--   gratuity_paid_at — wall-clock of the payout (for the HR view).
--
-- All three are nullable — India offboardings, AE/OM terminations under 1
-- year of service, and pending payouts all leave them NULL. Existing rows
-- backfill to NULL with no migration data work needed.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.hr_offboarding
    ADD COLUMN IF NOT EXISTS gratuity_journal_entry_id uuid,
    ADD COLUMN IF NOT EXISTS gratuity_amount numeric(15, 2),
    ADD COLUMN IF NOT EXISTS gratuity_paid_at timestamptz;
