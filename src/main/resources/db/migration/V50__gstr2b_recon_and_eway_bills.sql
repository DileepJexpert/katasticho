-- V50: GSTR-2B reconciliation + e-Way bills (Phase D — GST compliance)
--
-- gstr2b_entry: rows parsed from an uploaded GSTR-2B portal JSON, matched
-- against posted purchase bills. Mismatches surface as AI Inbox suggestions.
--
-- eway_bill: tracks e-way bill requirement/lifecycle per outward document.
-- Auto-detected when a posted invoice crosses the ₹50,000 threshold (org
-- setting gst.eway_bill_threshold); also supports the vehicle-aggregate rule
-- (multiple sub-threshold documents in one vehicle whose total crosses it).

CREATE TABLE gstr2b_entry (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    return_period   VARCHAR(7) NOT NULL,        -- YYYY-MM
    supplier_gstin  VARCHAR(15) NOT NULL,
    supplier_name   VARCHAR(255),
    invoice_number  VARCHAR(100) NOT NULL,
    invoice_date    DATE,
    invoice_value   NUMERIC(15,2) NOT NULL DEFAULT 0,
    taxable_value   NUMERIC(15,2) NOT NULL DEFAULT 0,
    igst            NUMERIC(15,2) NOT NULL DEFAULT 0,
    cgst            NUMERIC(15,2) NOT NULL DEFAULT 0,
    sgst            NUMERIC(15,2) NOT NULL DEFAULT 0,
    cess            NUMERIC(15,2) NOT NULL DEFAULT 0,
    itc_available   BOOLEAN NOT NULL DEFAULT true,
    match_status    VARCHAR(30) NOT NULL DEFAULT 'UNMATCHED',
    matched_bill_id UUID,
    match_note      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gstr2b_org_period ON gstr2b_entry (org_id, return_period);
CREATE INDEX idx_gstr2b_match_status ON gstr2b_entry (org_id, return_period, match_status);

CREATE TABLE eway_bill (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID NOT NULL,
    document_type    VARCHAR(20) NOT NULL,      -- INVOICE / DELIVERY_CHALLAN
    document_id      UUID NOT NULL,
    document_number  VARCHAR(50) NOT NULL,
    document_date    DATE NOT NULL,
    contact_id       UUID,
    total_value      NUMERIC(15,2) NOT NULL DEFAULT 0,
    status           VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING/GENERATED/CANCELLED
    ewb_number       VARCHAR(20),
    vehicle_number   VARCHAR(30),
    transport_mode   VARCHAR(10) NOT NULL DEFAULT 'ROAD',     -- ROAD/RAIL/AIR/SHIP
    transporter_id   VARCHAR(15),               -- transporter GSTIN
    transporter_name VARCHAR(255),
    distance_km      INT,
    from_state_code  VARCHAR(5),
    to_state_code    VARCHAR(5),
    generated_at     TIMESTAMPTZ,
    valid_until      TIMESTAMPTZ,
    cancelled_at     TIMESTAMPTZ,
    cancel_reason    TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by       UUID,
    is_deleted       BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_eway_org_status ON eway_bill (org_id, status) WHERE is_deleted = false;
CREATE INDEX idx_eway_org_document ON eway_bill (org_id, document_type, document_id) WHERE is_deleted = false;
CREATE INDEX idx_eway_vehicle_date ON eway_bill (org_id, vehicle_number, document_date) WHERE is_deleted = false;
