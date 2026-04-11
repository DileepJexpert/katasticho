-- ============================================================================
-- V6: Accounts Receivable tables
-- customer, invoice, invoice_line, tax_line_item, payment, credit_note
-- ============================================================================

-- Customer master
CREATE TABLE customer (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    name            VARCHAR(255) NOT NULL,
    email           VARCHAR(255),
    phone           VARCHAR(20),
    gstin           VARCHAR(15),         -- India GST ID (15-char format)
    tax_id          VARCHAR(50),         -- Generic tax ID for non-India
    pan             VARCHAR(10),         -- India PAN
    billing_address_line1  VARCHAR(255),
    billing_address_line2  VARCHAR(255),
    billing_city    VARCHAR(100),
    billing_state   VARCHAR(100),
    billing_state_code VARCHAR(5),       -- For CGST/SGST vs IGST determination
    billing_postal_code VARCHAR(20),
    billing_country VARCHAR(2) DEFAULT 'IN',
    shipping_address_line1 VARCHAR(255),
    shipping_address_line2 VARCHAR(255),
    shipping_city   VARCHAR(100),
    shipping_state  VARCHAR(100),
    shipping_state_code VARCHAR(5),
    shipping_postal_code VARCHAR(20),
    shipping_country VARCHAR(2) DEFAULT 'IN',
    credit_limit    NUMERIC(15,2) DEFAULT 0,
    payment_terms_days INTEGER DEFAULT 30,
    notes           TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE INDEX idx_customer_org ON customer(org_id);
CREATE INDEX idx_customer_org_name ON customer(org_id, name) WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_customer_org_gstin ON customer(org_id, gstin) WHERE gstin IS NOT NULL AND NOT is_deleted;

-- Invoice header
CREATE TABLE invoice (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    customer_id     UUID NOT NULL REFERENCES customer(id),
    invoice_number  VARCHAR(30) NOT NULL,
    invoice_date    DATE NOT NULL,
    due_date        DATE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                    CHECK (status IN ('DRAFT','SENT','PARTIALLY_PAID','PAID','CANCELLED','OVERDUE')),
    -- Amounts
    subtotal        NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount    NUMERIC(15,2) NOT NULL DEFAULT 0,
    amount_paid     NUMERIC(15,2) NOT NULL DEFAULT 0,
    balance_due     NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency        VARCHAR(3) NOT NULL DEFAULT 'INR',
    exchange_rate   NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    -- Base currency amounts (for ledger)
    base_subtotal   NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_total      NUMERIC(15,2) NOT NULL DEFAULT 0,
    -- Tax context
    place_of_supply VARCHAR(5),          -- State code for GST
    is_reverse_charge BOOLEAN NOT NULL DEFAULT FALSE,
    -- References
    journal_entry_id UUID REFERENCES journal_entry(id),  -- Posted journal
    notes           TEXT,
    terms_and_conditions TEXT,
    -- Period
    period_year     INTEGER,
    period_month    INTEGER,
    -- Lifecycle
    sent_at         TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    cancelled_by    UUID,
    cancel_reason   TEXT,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_invoice_org_number ON invoice(org_id, invoice_number) WHERE NOT is_deleted;
CREATE INDEX idx_invoice_org_status ON invoice(org_id, status);
CREATE INDEX idx_invoice_customer ON invoice(customer_id);
CREATE INDEX idx_invoice_org_date ON invoice(org_id, invoice_date);
CREATE INDEX idx_invoice_org_due ON invoice(org_id, due_date) WHERE status IN ('SENT','PARTIALLY_PAID','OVERDUE');

-- Invoice line items
CREATE TABLE invoice_line (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id      UUID NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
    line_number     INTEGER NOT NULL,
    description     VARCHAR(500) NOT NULL,
    hsn_code        VARCHAR(10),         -- HSN/SAC code for GST
    quantity        NUMERIC(12,4) NOT NULL DEFAULT 1,
    unit_price      NUMERIC(15,2) NOT NULL,
    discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    taxable_amount  NUMERIC(15,2) NOT NULL,  -- After discount
    gst_rate        NUMERIC(5,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    line_total      NUMERIC(15,2) NOT NULL,  -- taxable + tax
    account_code    VARCHAR(20) NOT NULL,    -- Revenue account
    -- Base currency
    base_taxable_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_line_total NUMERIC(15,2) NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_invoice_line_invoice ON invoice_line(invoice_id);

-- Generic tax line items (reusable for AR, AP, etc.)
CREATE TABLE tax_line_item (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    source_type     VARCHAR(30) NOT NULL CHECK (source_type IN ('INVOICE','CREDIT_NOTE','BILL','EXPENSE')),
    source_id       UUID NOT NULL,           -- invoice.id or credit_note.id etc.
    source_line_id  UUID,                    -- invoice_line.id (nullable for header-level tax)
    tax_regime      VARCHAR(30) NOT NULL,    -- e.g. 'INDIA_GST'
    component_code  VARCHAR(10) NOT NULL,    -- e.g. 'CGST', 'SGST', 'IGST'
    rate            NUMERIC(5,2) NOT NULL,
    taxable_amount  NUMERIC(15,2) NOT NULL,
    tax_amount      NUMERIC(15,2) NOT NULL,
    account_code    VARCHAR(20) NOT NULL,    -- Tax liability account
    hsn_code        VARCHAR(10),
    -- Base currency
    base_taxable_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tax_line_source ON tax_line_item(source_type, source_id);
CREATE INDEX idx_tax_line_org ON tax_line_item(org_id);
CREATE INDEX idx_tax_line_regime ON tax_line_item(org_id, tax_regime, component_code);

-- Payment table
CREATE TABLE payment (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    customer_id     UUID NOT NULL REFERENCES customer(id),
    invoice_id      UUID NOT NULL REFERENCES invoice(id),
    payment_number  VARCHAR(30) NOT NULL,
    payment_date    DATE NOT NULL,
    amount          NUMERIC(15,2) NOT NULL,
    currency        VARCHAR(3) NOT NULL DEFAULT 'INR',
    exchange_rate   NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    base_amount     NUMERIC(15,2) NOT NULL,
    payment_method  VARCHAR(30) NOT NULL CHECK (payment_method IN ('CASH','BANK_TRANSFER','UPI','CHEQUE','CARD','OTHER')),
    reference_number VARCHAR(100),           -- UTR, cheque number, etc.
    bank_account    VARCHAR(50),
    notes           TEXT,
    -- Journal reference
    journal_entry_id UUID REFERENCES journal_entry(id),
    -- Lifecycle
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_payment_org_number ON payment(org_id, payment_number) WHERE NOT is_deleted;
CREATE INDEX idx_payment_org ON payment(org_id);
CREATE INDEX idx_payment_invoice ON payment(invoice_id);
CREATE INDEX idx_payment_customer ON payment(customer_id);

-- Credit note
CREATE TABLE credit_note (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    customer_id     UUID NOT NULL REFERENCES customer(id),
    invoice_id      UUID REFERENCES invoice(id),   -- Original invoice (nullable for standalone)
    credit_note_number VARCHAR(30) NOT NULL,
    credit_note_date DATE NOT NULL,
    reason          TEXT NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                    CHECK (status IN ('DRAFT','ISSUED','APPLIED','CANCELLED')),
    -- Amounts
    subtotal        NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount    NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency        VARCHAR(3) NOT NULL DEFAULT 'INR',
    exchange_rate   NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    base_subtotal   NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_total      NUMERIC(15,2) NOT NULL DEFAULT 0,
    place_of_supply VARCHAR(5),
    -- Journal reference
    journal_entry_id UUID REFERENCES journal_entry(id),
    -- Lifecycle
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_credit_note_org_number ON credit_note(org_id, credit_note_number) WHERE NOT is_deleted;
CREATE INDEX idx_credit_note_org ON credit_note(org_id);
CREATE INDEX idx_credit_note_invoice ON credit_note(invoice_id);

-- Credit note line items
CREATE TABLE credit_note_line (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_note_id  UUID NOT NULL REFERENCES credit_note(id) ON DELETE CASCADE,
    line_number     INTEGER NOT NULL,
    description     VARCHAR(500) NOT NULL,
    hsn_code        VARCHAR(10),
    quantity        NUMERIC(12,4) NOT NULL DEFAULT 1,
    unit_price      NUMERIC(15,2) NOT NULL,
    taxable_amount  NUMERIC(15,2) NOT NULL,
    gst_rate        NUMERIC(5,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    line_total      NUMERIC(15,2) NOT NULL,
    account_code    VARCHAR(20) NOT NULL,
    base_taxable_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_line_total NUMERIC(15,2) NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_credit_note_line_cn ON credit_note_line(credit_note_id);

-- Invoice number sequence (separate from journal entry sequence)
CREATE TABLE invoice_number_sequence (
    org_id      UUID NOT NULL REFERENCES organisation(id),
    prefix      VARCHAR(10) NOT NULL DEFAULT 'INV',
    year        INTEGER NOT NULL,
    next_value  BIGINT NOT NULL DEFAULT 1,
    PRIMARY KEY (org_id, prefix, year)
);
