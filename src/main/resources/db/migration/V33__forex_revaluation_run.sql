-- V33 — Period-end forex revaluation run (MASTER_GAP_TRACKER H8).
--
-- Open foreign-currency AR invoices + AP bills are carried in the books at their
-- transaction-date exchange rate. At period end their base-currency value is
-- restated to the closing rate; the difference is an UNREALIZED forex gain/loss.
-- The revaluation posts a consolidated journal on the as-of date and an
-- auto-reversing journal on the next day (so settlement realized-forex is not
-- double-counted). This table records each run for idempotency + audit — one
-- revaluation per (org, as-of date).

CREATE TABLE forex_revaluation_run (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    as_of_date DATE NOT NULL,
    base_currency VARCHAR(3) NOT NULL,
    ar_delta NUMERIC(18,2) NOT NULL DEFAULT 0,       -- net base-currency change on AR (DR when positive)
    ap_delta NUMERIC(18,2) NOT NULL DEFAULT 0,       -- net base-currency change on AP (CR when positive)
    net_gain_loss NUMERIC(18,2) NOT NULL DEFAULT 0,  -- arDelta - apDelta (gain when positive)
    revalued_document_count INTEGER NOT NULL DEFAULT 0,
    reval_journal_entry_id UUID,                     -- null when nothing to revalue (zero delta)
    reversal_journal_entry_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);

-- One revaluation per org per as-of date (idempotency backstop).
CREATE UNIQUE INDEX uq_forex_revaluation_run ON forex_revaluation_run (org_id, as_of_date);
CREATE INDEX idx_forex_revaluation_run_org ON forex_revaluation_run (org_id, as_of_date DESC);
