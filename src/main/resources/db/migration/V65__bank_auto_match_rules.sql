-- V65: Automated Bank Statement Feeds & Smart Auto-Match Reconciler
CREATE TABLE IF NOT EXISTS bank_reconciliation_rule (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    rule_name VARCHAR(100) NOT NULL,
    match_field VARCHAR(50) NOT NULL DEFAULT 'DESCRIPTION', -- DESCRIPTION, REFERENCE, AMOUNT
    operator VARCHAR(30) NOT NULL DEFAULT 'CONTAINS', -- CONTAINS, STARTS_WITH, REGEX, EXACT
    match_pattern VARCHAR(255) NOT NULL,
    target_account_id UUID REFERENCES account(id) ON DELETE RESTRICT,
    auto_post BOOLEAN NOT NULL DEFAULT FALSE,
    priority INT NOT NULL DEFAULT 10,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS bank_auto_match_suggestion (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    bank_account_id UUID NOT NULL REFERENCES bank_account(id) ON DELETE CASCADE,
    statement_date DATE NOT NULL,
    statement_reference VARCHAR(100),
    statement_description TEXT,
    statement_amount NUMERIC(15, 4) NOT NULL,
    is_credit BOOLEAN NOT NULL DEFAULT TRUE,
    matched_journal_entry_id UUID REFERENCES journal_entry(id) ON DELETE SET NULL,
    confidence_score INT NOT NULL DEFAULT 0,
    match_reason VARCHAR(255) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING', -- PENDING, ACCEPTED, REJECTED
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_bank_match_org_acct ON bank_auto_match_suggestion(org_id, bank_account_id, status) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_bank_recon_rules_org ON bank_reconciliation_rule(org_id) WHERE is_deleted = false;
