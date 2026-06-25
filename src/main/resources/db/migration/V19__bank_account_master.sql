-- Bank-account master (C5). A business has many bank accounts (HDFC Current,
-- SBI Savings, an OD/CC account, …); each one is its own ledger and reconciles
-- separately. The single default BANK GL account (1020) could not distinguish
-- them. `bank_account` is the human master (bank name / account number / IFSC /
-- branch / type) and points at its own GL sub-account under 1020, so each bank's
-- cash movements post to a distinct ledger.

CREATE TABLE bank_account (
    id                  UUID PRIMARY KEY,
    org_id              UUID NOT NULL,
    branch_id           UUID,
    name                VARCHAR(120) NOT NULL,       -- display label, e.g. "HDFC Current ••4521"
    bank_name           VARCHAR(120),
    account_number      VARCHAR(40),
    ifsc                VARCHAR(20),
    branch              VARCHAR(120),
    account_type        VARCHAR(20) NOT NULL DEFAULT 'CURRENT',
    gl_account_id       UUID NOT NULL,               -- FK to account.id (the bank's own ledger)
    opening_balance     NUMERIC(18, 2) NOT NULL DEFAULT 0,
    is_default          BOOLEAN NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    notes               TEXT,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL,
    updated_at          TIMESTAMPTZ NOT NULL,
    created_by          UUID,
    CONSTRAINT bank_account_type_chk
        CHECK (account_type IN ('SAVINGS', 'CURRENT', 'OD', 'CC', 'OTHER'))
);

-- list / picker scans
CREATE INDEX idx_bank_account_org
    ON bank_account (org_id)
    WHERE is_deleted = FALSE;

-- at most one default per org (partial unique on the flagged row)
CREATE UNIQUE INDEX idx_bank_account_one_default
    ON bank_account (org_id)
    WHERE is_default = TRUE AND is_deleted = FALSE;

-- no two live accounts share an account number within an org
CREATE UNIQUE INDEX idx_bank_account_number_uq
    ON bank_account (org_id, account_number)
    WHERE account_number IS NOT NULL AND is_deleted = FALSE;
