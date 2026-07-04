-- V34 — Drop the stale journal_entry.source_module CHECK constraint.
--
-- The V1 baseline pinned source_module to a fixed 11-value vocabulary
-- (SALES/PURCHASE/PAYMENT/PAYROLL/INVENTORY/MANUAL/GST/BANK_REC/OPENING/POS/EXPENSE).
-- Since then a dozen+ features post journals with source_module values the CHECK
-- rejects — MANUFACTURING, FIXED_ASSET, AMORTIZATION, TALLY_IMPORT, RECURRING_JOURNAL,
-- PAYROLL_PAYMENT, INTEREST_CHARGE, HR_OFFBOARDING, AI_ENTRY, YEAR_END_CLOSE, BANKING
-- (bank rules) and now FOREX_REVAL (period-end forex revaluation). Every one of those
-- journal posts would throw a CHECK violation on a real INSERT; they only "passed" because
-- their unit tests mock JournalService, so the constraint was never exercised.
--
-- source_module is a *label* used for filtering/reporting (idx_je_source), not a value any
-- query relies on for correctness, and it is always set from a code constant (not user input),
-- so the enum guard's only net effect has been latent crashes for legitimate journals.
-- Drop it; source_module stays NOT NULL VARCHAR(30). This un-breaks all the features above
-- (current + future) at once.

ALTER TABLE journal_entry DROP CONSTRAINT IF EXISTS journal_entry_source_module_check;
