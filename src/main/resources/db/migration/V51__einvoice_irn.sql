-- V51: e-Invoice (IRN) tracking (Phase F — statutory documents)
--
-- One row per B2B invoice that needs an IRN. Auto-created (PENDING) when a
-- posted invoice has a registered (GSTIN) buyer and the org has e-invoicing
-- enabled (org setting gst.einvoice_enabled). We generate the IRP INV-01 JSON;
-- the IRN / Ack / signed QR obtained from the portal or GSP is recorded back.

CREATE TABLE einvoice (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    invoice_id      UUID NOT NULL,
    document_number VARCHAR(50) NOT NULL,
    document_date   DATE NOT NULL,
    contact_id      UUID,
    total_value     NUMERIC(15,2) NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',   -- PENDING/GENERATED/CANCELLED
    irn             VARCHAR(64),
    ack_number      VARCHAR(30),
    ack_date        VARCHAR(30),                              -- as issued by the IRP
    signed_qr       TEXT,
    generated_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    cancel_reason   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    is_deleted      BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_einvoice_org_status ON einvoice (org_id, status) WHERE is_deleted = false;
CREATE INDEX idx_einvoice_org_invoice ON einvoice (org_id, invoice_id) WHERE is_deleted = false;
