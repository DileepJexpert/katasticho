CREATE TABLE IF NOT EXISTS bank_transaction (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    transaction_date DATE NOT NULL,
    amount NUMERIC(18, 2) NOT NULL,
    direction VARCHAR(10) NOT NULL,
    narration TEXT,
    utr VARCHAR(100),
    payer_name VARCHAR(255),
    payer_vpa VARCHAR(255),
    status VARCHAR(30) NOT NULL DEFAULT 'UNMATCHED',
    payment_id UUID REFERENCES payment(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bank_transaction_org_status_date
    ON bank_transaction(org_id, status, transaction_date DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_bank_transaction_org_utr
    ON bank_transaction(org_id, utr);

CREATE TABLE IF NOT EXISTS payment_match (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    bank_transaction_id UUID NOT NULL REFERENCES bank_transaction(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES invoice(id),
    contact_id UUID REFERENCES contact(id),
    matched_amount NUMERIC(18, 2) NOT NULL,
    confidence NUMERIC(5, 4) NOT NULL,
    match_status VARCHAR(30) NOT NULL DEFAULT 'SUGGESTED',
    payment_id UUID REFERENCES payment(id),
    accepted_by UUID,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_match_org_tx_status
    ON payment_match(org_id, bank_transaction_id, match_status, confidence DESC);

CREATE INDEX IF NOT EXISTS idx_payment_match_org_invoice
    ON payment_match(org_id, invoice_id);
