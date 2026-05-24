-- V24: Prescription records for pharmacy compliance
CREATE TABLE prescription_record (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL,
    contact_id          UUID,  -- patient (nullable for walk-in)
    receipt_id          UUID,  -- linked sale receipt
    doctor_name         VARCHAR(200),
    doctor_reg_number   VARCHAR(100),
    prescription_number VARCHAR(100),
    prescribed_date     DATE,
    valid_until         DATE,
    notes               TEXT,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE prescription_record_item (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prescription_record_id  UUID NOT NULL REFERENCES prescription_record(id) ON DELETE CASCADE,
    item_id                 UUID,
    item_name               VARCHAR(500) NOT NULL,
    quantity                NUMERIC(14,4) NOT NULL DEFAULT 1,
    dosage_instructions     TEXT
);
CREATE INDEX idx_rx_record_org_contact ON prescription_record(org_id, contact_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_rx_record_receipt ON prescription_record(receipt_id) WHERE receipt_id IS NOT NULL;
CREATE INDEX idx_rx_item_record ON prescription_record_item(prescription_record_id);
