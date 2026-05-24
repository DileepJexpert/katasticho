-- V25: Debit Notes for supplier purchase returns
-- Lifecycle: DRAFT → SUBMITTED → ACCEPTED → SETTLED
CREATE TABLE debit_note (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    supplier_id     UUID NOT NULL,
    debit_note_number VARCHAR(30) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    note_date       DATE NOT NULL,
    return_reason   VARCHAR(50) NOT NULL, -- EXPIRED, DAMAGED, WRONG_ITEM, QUALITY_ISSUE, EXCESS_STOCK
    reference_bill_id UUID,  -- original purchase bill (nullable)
    notes           TEXT,
    subtotal        DECIMAL(19,4) NOT NULL DEFAULT 0,
    tax_amount      DECIMAL(19,4) NOT NULL DEFAULT 0,
    total_amount    DECIMAL(19,4) NOT NULL DEFAULT 0,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE debit_note_line (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    debit_note_id   UUID NOT NULL REFERENCES debit_note(id) ON DELETE CASCADE,
    item_id         UUID NOT NULL,
    description     VARCHAR(500),
    batch_id        UUID,
    batch_number    VARCHAR(100),
    expiry_date     DATE,
    quantity        DECIMAL(19,4) NOT NULL,
    unit_price      DECIMAL(19,4) NOT NULL DEFAULT 0,
    tax_group_id    UUID,
    hsn_code        VARCHAR(10),
    tax_rate        DECIMAL(6,2) NOT NULL DEFAULT 0,
    tax_amount      DECIMAL(19,4) NOT NULL DEFAULT 0,
    line_total      DECIMAL(19,4) NOT NULL DEFAULT 0
);
CREATE SEQUENCE debit_note_seq START 1001 INCREMENT 1;
CREATE INDEX idx_debit_note_org_status ON debit_note(org_id, status, is_deleted);
CREATE INDEX idx_debit_note_supplier ON debit_note(org_id, supplier_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_debit_note_line_dn ON debit_note_line(debit_note_id);
