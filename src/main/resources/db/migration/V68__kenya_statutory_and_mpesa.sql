-- V68: Kenya Statutory, M-Pesa Mobile Money Suite & KRA eTIMS Bridge
CREATE TABLE IF NOT EXISTS mpesa_transaction (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    mpesa_receipt_number VARCHAR(50) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL DEFAULT 'STK_PUSH_C2B', -- STK_PUSH_C2B, B2C_PAYOUT, STATEMENT_IMPORT
    phone_number VARCHAR(30) NOT NULL,
    amount NUMERIC(15, 4) NOT NULL,
    party_name VARCHAR(150),
    account_reference VARCHAR(100),
    status VARCHAR(30) NOT NULL DEFAULT 'COMPLETED', -- PENDING, COMPLETED, FAILED, RECONCILED
    matched_invoice_id UUID REFERENCES invoice(id) ON DELETE SET NULL,
    matched_journal_entry_id UUID REFERENCES journal_entry(id) ON DELETE SET NULL,
    transaction_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_mpesa_receipt UNIQUE (org_id, mpesa_receipt_number)
);

CREATE TABLE IF NOT EXISTS kra_etims_invoice (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
    control_unit_number VARCHAR(50) NOT NULL,
    scu_receipt_number VARCHAR(100) NOT NULL,
    qr_code_url TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'VERIFIED', -- PENDING, SUBMITTED, VERIFIED, REJECTED
    response_payload TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_kra_etims_inv UNIQUE (invoice_id)
);

CREATE INDEX IF NOT EXISTS idx_mpesa_org_status ON mpesa_transaction(org_id, status) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_kra_etims_org ON kra_etims_invoice(org_id, status) WHERE is_deleted = false;
