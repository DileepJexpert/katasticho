-- =====================================================================
-- V23: Sales Receipt (POS) tables
-- One-shot point-of-sale transactions with immediate payment + stock.
-- =====================================================================

-- ── sales_receipt ────────────────────────────────────────────────────
CREATE TABLE sales_receipt (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    branch_id       UUID REFERENCES branch(id),
    receipt_number  VARCHAR(30) NOT NULL,
    contact_id      UUID REFERENCES contact(id),       -- nullable = walk-in
    receipt_date    DATE NOT NULL,

    subtotal        DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax_amount      DECIMAL(15,2) NOT NULL DEFAULT 0,
    total           DECIMAL(15,2) NOT NULL DEFAULT 0,

    payment_mode    VARCHAR(20) NOT NULL
                    CHECK (payment_mode IN ('CASH','UPI','CARD','MIXED')),
    paid_through_id UUID REFERENCES account(id),
    amount_received DECIMAL(15,2) NOT NULL DEFAULT 0,
    change_returned DECIMAL(15,2) NOT NULL DEFAULT 0,
    upi_reference   VARCHAR(50),

    currency        CHAR(3) NOT NULL DEFAULT 'INR',
    notes           VARCHAR(500),

    journal_entry_id UUID REFERENCES journal_entry(id),

    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID REFERENCES app_user(id),

    CONSTRAINT uq_sales_receipt_org_number UNIQUE (org_id, receipt_number)
);

CREATE INDEX idx_sales_receipt_org     ON sales_receipt(org_id);
CREATE INDEX idx_sales_receipt_branch  ON sales_receipt(org_id, branch_id);
CREATE INDEX idx_sales_receipt_date    ON sales_receipt(org_id, receipt_date);
CREATE INDEX idx_sales_receipt_contact ON sales_receipt(contact_id);

-- ── sales_receipt_line ───────────────────────────────────────────────
CREATE TABLE sales_receipt_line (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id        UUID NOT NULL REFERENCES sales_receipt(id) ON DELETE CASCADE,
    line_number       INT NOT NULL,
    item_id           UUID REFERENCES item(id),           -- nullable for ad-hoc
    description       VARCHAR(500),
    quantity          DECIMAL(15,3) NOT NULL DEFAULT 1,
    unit              VARCHAR(20),
    rate              DECIMAL(15,2) NOT NULL DEFAULT 0,
    tax_group_id      UUID REFERENCES tax_group(id),
    hsn_code          VARCHAR(8),
    amount            DECIMAL(15,2) NOT NULL DEFAULT 0,
    batch_id          UUID REFERENCES stock_batch(id),
    stock_movement_id UUID REFERENCES stock_movement(id)
);

CREATE INDEX idx_srl_receipt ON sales_receipt_line(receipt_id);
CREATE INDEX idx_srl_item    ON sales_receipt_line(item_id);

-- ── Add barcode column to item table ─────────────────────────────────
ALTER TABLE item ADD COLUMN IF NOT EXISTS barcode VARCHAR(50);
CREATE INDEX idx_item_barcode ON item(barcode) WHERE barcode IS NOT NULL;
