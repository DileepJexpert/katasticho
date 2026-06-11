-- Budgets (Tally "Budgets & controls" parity, v1): one annual amount per
-- account per fiscal year. The variance report pro-rates the annual amount
-- over the selected window and compares with P&L actuals.

CREATE TABLE budget_line (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID          NOT NULL REFERENCES organisation(id),
    fiscal_year   INTEGER       NOT NULL,            -- FY start year (2026 = FY 2026-27)
    account_code  VARCHAR(20)   NOT NULL,
    annual_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    notes         VARCHAR(255),
    is_deleted    BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    created_by    UUID,
    CONSTRAINT uq_budget_line UNIQUE (org_id, fiscal_year, account_code)
);

CREATE INDEX idx_budget_line_org_fy ON budget_line(org_id, fiscal_year) WHERE is_deleted = FALSE;
