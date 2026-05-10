-- Fiscal period management for period close enforcement.
-- Each org has one row per (year, month) so the posting gate
-- can reject entries into closed periods.

CREATE TABLE IF NOT EXISTS fiscal_period (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL REFERENCES organisation(id),
    period_year INTEGER NOT NULL,
    period_month INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    status      VARCHAR(20) NOT NULL DEFAULT 'OPEN'
                CHECK (status IN ('OPEN', 'CLOSED', 'LOCKED')),
    closed_at   TIMESTAMPTZ,
    closed_by   UUID,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (org_id, period_year, period_month)
);

CREATE INDEX IF NOT EXISTS idx_fiscal_period_org_status
    ON fiscal_period(org_id, status);
