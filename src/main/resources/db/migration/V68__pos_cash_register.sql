-- V68 (renumbered from duplicate V48): POS Cash Register / Day Close
-- Tracks daily register opening, cash sales, expenses, and closing balance.

CREATE TABLE IF NOT EXISTS pos_cash_register (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID          NOT NULL,
    branch_id       UUID,
    register_date   DATE          NOT NULL,
    opening_balance DECIMAL(14,2) NOT NULL DEFAULT 0,
    actual_closing  DECIMAL(14,2),
    status          VARCHAR(20)   NOT NULL DEFAULT 'OPEN',
    notes           TEXT,
    opened_by       UUID,
    closed_by       UUID,
    closed_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, register_date)
);

CREATE TABLE IF NOT EXISTS pos_cash_expense (
    id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID          NOT NULL,
    register_id  UUID          NOT NULL REFERENCES pos_cash_register(id) ON DELETE CASCADE,
    amount       DECIMAL(14,2) NOT NULL,
    description  VARCHAR(255)  NOT NULL,
    expense_time TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    recorded_by  UUID,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pos_cash_register_org_date ON pos_cash_register(org_id, register_date);
CREATE INDEX IF NOT EXISTS idx_pos_cash_expense_register  ON pos_cash_expense(register_id);
