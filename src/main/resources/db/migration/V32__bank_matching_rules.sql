-- V32 — User-defined bank matching rules (MASTER_GAP_TRACKER H4).
--
-- The existing reconciliation matcher only scores a bank transaction against
-- outstanding invoices (credits) / bills (debits). Transactions that are NOT
-- document payments — bank charges, utility auto-debits, interest credits,
-- salary transfers — never match and sit UNMATCHED forever. A bank_rule lets an
-- org categorise them: the first matching rule (by priority) proposes an ACCOUNT
-- match to a GL code (optionally with a contact + memo), shown as a high-
-- confidence suggestion or auto-applied on import. Accepting posts a direct
-- bank <-> account journal (no invoice/bill/payment involved).

CREATE TABLE bank_rule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    priority INTEGER NOT NULL DEFAULT 100,        -- lower = evaluated first
    active BOOLEAN NOT NULL DEFAULT true,
    direction_filter VARCHAR(10) NOT NULL DEFAULT 'ANY'
        CHECK (direction_filter IN ('ANY', 'CREDIT', 'DEBIT')),
    narration_op VARCHAR(12) NOT NULL DEFAULT 'CONTAINS'
        CHECK (narration_op IN ('CONTAINS', 'EQUALS', 'STARTS_WITH', 'REGEX', 'ANY')),
    narration_value TEXT,                          -- required unless narration_op = ANY
    amount_op VARCHAR(6) NOT NULL DEFAULT 'ANY'
        CHECK (amount_op IN ('ANY', 'EQ', 'GT', 'LT', 'GTE', 'LTE')),
    amount_value NUMERIC(18,2),                    -- required unless amount_op = ANY
    account_code VARCHAR(40) NOT NULL,             -- target GL for the categorisation
    contact_id UUID,                               -- optional metadata (payee/payer)
    memo VARCHAR(255),
    auto_apply BOOLEAN NOT NULL DEFAULT false,     -- post immediately on import vs. suggest
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
-- The dispatch scan: active rules for an org, evaluated in priority order.
CREATE INDEX idx_bank_rule_dispatch ON bank_rule (org_id, priority)
    WHERE active AND NOT is_deleted;
CREATE INDEX idx_bank_rule_org ON bank_rule (org_id) WHERE NOT is_deleted;

-- payment_match gains the ACCOUNT-categorisation shape (match_type already has no
-- CHECK constraint, so 'ACCOUNT' is a valid new value alongside INVOICE / BILL).
ALTER TABLE payment_match ADD COLUMN account_code VARCHAR(40);
ALTER TABLE payment_match ADD COLUMN bank_rule_id UUID;
