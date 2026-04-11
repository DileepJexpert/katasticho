-- ============================================================
-- V3: Accounting Core tables
-- account (CoA), journal_entry (immutable), journal_line, period_balance
-- This is the FOUNDATION of the entire ERP.
-- ============================================================

-- Chart of Accounts: hierarchical, 5-level deep.
CREATE TABLE account (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    code            VARCHAR(20) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    type            VARCHAR(20) NOT NULL CHECK (type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    sub_type        VARCHAR(50),
    parent_id       UUID REFERENCES account(id),
    level           INTEGER NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 5),
    is_system       BOOLEAN NOT NULL DEFAULT FALSE,
    description     VARCHAR(500),
    opening_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    currency        CHAR(3) NOT NULL DEFAULT 'INR',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_account_code_org UNIQUE (org_id, code)
);

CREATE INDEX idx_account_org ON account (org_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_account_org_type ON account (org_id, type) WHERE is_deleted = FALSE;
CREATE INDEX idx_account_parent ON account (parent_id) WHERE parent_id IS NOT NULL;


-- Journal Entry: IMMUTABLE once posted.
-- Status: DRAFT -> POSTED (one-way, irreversible).
-- Corrections via reversal entries ONLY.
-- Bitemporality: effective_date (valid time) + created_at (transaction time).
CREATE TABLE journal_entry (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    entry_number        VARCHAR(30) NOT NULL,
    effective_date      DATE NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    description         VARCHAR(500),
    source_module       VARCHAR(30) NOT NULL CHECK (source_module IN (
                            'AR', 'AP', 'PAYROLL', 'INVENTORY', 'MANUAL', 'GST', 'BANK_REC', 'OPENING'
                        )),
    source_id           UUID,
    status              VARCHAR(10) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'POSTED')),
    reversal_of_id      UUID REFERENCES journal_entry(id),
    is_reversal         BOOLEAN NOT NULL DEFAULT FALSE,
    is_reversed         BOOLEAN NOT NULL DEFAULT FALSE,
    approval_status     VARCHAR(15) NOT NULL DEFAULT 'NONE' CHECK (approval_status IN (
                            'NONE', 'PENDING', 'APPROVED', 'REJECTED'
                        )),
    approved_by         UUID,
    approved_at         TIMESTAMPTZ,
    period_year         INTEGER NOT NULL,
    period_month        INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    created_by          UUID NOT NULL,
    tags                JSONB DEFAULT '{}',

    CONSTRAINT uq_journal_entry_number UNIQUE (org_id, entry_number)
);

CREATE INDEX idx_je_org_date ON journal_entry (org_id, effective_date);
CREATE INDEX idx_je_org_status ON journal_entry (org_id, status);
CREATE INDEX idx_je_org_period ON journal_entry (org_id, period_year, period_month);
CREATE INDEX idx_je_source ON journal_entry (org_id, source_module, source_id);
CREATE INDEX idx_je_reversal ON journal_entry (reversal_of_id) WHERE reversal_of_id IS NOT NULL;


-- Journal Line: child of journal_entry.
-- Dual amounts: transaction currency + base currency (multi-currency ready).
-- SUM(debit) = SUM(credit) enforced per journal_entry.
CREATE TABLE journal_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_entry_id    UUID NOT NULL REFERENCES journal_entry(id) ON DELETE RESTRICT,
    account_id          UUID NOT NULL REFERENCES account(id),
    description         VARCHAR(500),
    currency            CHAR(3) NOT NULL DEFAULT 'INR',
    debit               DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit              DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    exchange_rate       DECIMAL(15,6) NOT NULL DEFAULT 1.000000,
    base_debit          DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (base_debit >= 0),
    base_credit         DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (base_credit >= 0),
    tax_component_code  VARCHAR(20),
    cost_centre         VARCHAR(50),
    project_id          UUID,

    CONSTRAINT chk_line_debit_or_credit CHECK (
        (debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0) OR (debit = 0 AND credit = 0)
    )
);

CREATE INDEX idx_jl_entry ON journal_line (journal_entry_id);
CREATE INDEX idx_jl_account ON journal_line (account_id);
CREATE INDEX idx_jl_account_entry ON journal_line (account_id, journal_entry_id);


-- Period Balance: cached monthly snapshots for performance.
-- This is NEVER the source of truth — reports compute from journal_line.
-- Refreshed by daily batch job and on period close.
CREATE TABLE period_balance (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL,
    account_id          UUID NOT NULL REFERENCES account(id),
    period_year         INTEGER NOT NULL,
    period_month        INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    opening_balance     DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_debit         DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_credit        DECIMAL(15,2) NOT NULL DEFAULT 0,
    closing_balance     DECIMAL(15,2) NOT NULL DEFAULT 0,
    transaction_count   INTEGER NOT NULL DEFAULT 0,
    currency            CHAR(3) NOT NULL DEFAULT 'INR',
    frozen_at           TIMESTAMPTZ,

    CONSTRAINT uq_period_balance UNIQUE (org_id, account_id, period_year, period_month)
);

CREATE INDEX idx_pb_org_period ON period_balance (org_id, account_id, period_year, period_month);


-- Entry number sequence per org (used by JournalService)
CREATE TABLE entry_number_sequence (
    org_id      UUID NOT NULL REFERENCES organisation(id),
    year        INTEGER NOT NULL,
    next_value  BIGINT NOT NULL DEFAULT 1,
    PRIMARY KEY (org_id, year)
);
