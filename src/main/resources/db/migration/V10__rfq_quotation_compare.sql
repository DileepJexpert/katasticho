-- V10: RFQ (Request For Quotation) + supplier quotations + award→PO.
--
-- The buyer drafts an RFQ with line items → sends to N candidate suppliers →
-- each supplier returns a SupplierQuote with prices + lead time → buyer
-- compares → awards a winner → drafts a PO from the winning quote.
--
-- Closes a procurement-sourcing gap: the existing PO flow assumes the buyer
-- already knows the supplier + the price. RFQ owns the "shop around" step.

-- ── rfq (header) ───────────────────────────────────────────────────────────
CREATE TABLE rfq (
    id                UUID PRIMARY KEY,
    org_id            UUID NOT NULL,
    rfq_number        VARCHAR(30) NOT NULL,
    title             VARCHAR(200) NOT NULL,
    status            VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    due_date          DATE,
    notes             TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by        UUID,
    is_deleted        BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_rfq_status CHECK (status IN ('DRAFT', 'SENT', 'AWARDED', 'CANCELLED'))
);

CREATE UNIQUE INDEX uq_rfq_number_per_org ON rfq (org_id, rfq_number) WHERE is_deleted = FALSE;
CREATE INDEX idx_rfq_org_status ON rfq (org_id, status) WHERE is_deleted = FALSE;

-- ── rfq_line ───────────────────────────────────────────────────────────────
CREATE TABLE rfq_line (
    id                UUID PRIMARY KEY,
    org_id            UUID NOT NULL,
    rfq_id            UUID NOT NULL REFERENCES rfq(id),
    item_id           UUID,
    description       VARCHAR(500),
    quantity          NUMERIC(15, 4) NOT NULL,
    hsn_code          VARCHAR(20),
    gst_rate          NUMERIC(5, 2),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by        UUID,
    is_deleted        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_rfq_line_rfq ON rfq_line (rfq_id) WHERE is_deleted = FALSE;

-- ── rfq_supplier (which suppliers got the RFQ) ────────────────────────────
CREATE TABLE rfq_supplier (
    id                       UUID PRIMARY KEY,
    org_id                   UUID NOT NULL,
    rfq_id                   UUID NOT NULL REFERENCES rfq(id),
    supplier_contact_id      UUID NOT NULL,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by               UUID,
    is_deleted               BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_rfq_supplier_rfq ON rfq_supplier (rfq_id) WHERE is_deleted = FALSE;

-- ── supplier_quote (header) ───────────────────────────────────────────────
CREATE TABLE supplier_quote (
    id                       UUID PRIMARY KEY,
    org_id                   UUID NOT NULL,
    rfq_id                   UUID NOT NULL REFERENCES rfq(id),
    supplier_contact_id      UUID NOT NULL,
    quote_number             VARCHAR(30) NOT NULL,
    valid_until              DATE,
    total_amount             NUMERIC(15, 2) NOT NULL DEFAULT 0,
    currency                 VARCHAR(3) NOT NULL DEFAULT 'INR',
    status                   VARCHAR(20) NOT NULL DEFAULT 'RECEIVED',
    notes                    TEXT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by               UUID,
    is_deleted               BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_supplier_quote_status CHECK (status IN ('RECEIVED', 'AWARDED', 'REJECTED'))
);

CREATE UNIQUE INDEX uq_supplier_quote_number_per_org ON supplier_quote (org_id, quote_number) WHERE is_deleted = FALSE;
CREATE INDEX idx_supplier_quote_rfq ON supplier_quote (rfq_id) WHERE is_deleted = FALSE;

-- ── supplier_quote_line ───────────────────────────────────────────────────
CREATE TABLE supplier_quote_line (
    id                       UUID PRIMARY KEY,
    org_id                   UUID NOT NULL,
    supplier_quote_id        UUID NOT NULL REFERENCES supplier_quote(id),
    item_id                  UUID,
    description              VARCHAR(500),
    quantity                 NUMERIC(15, 4) NOT NULL,
    unit_price               NUMERIC(15, 4) NOT NULL,
    lead_time_days           INT,
    notes                    VARCHAR(500),
    created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by               UUID,
    is_deleted               BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_supplier_quote_line_quote ON supplier_quote_line (supplier_quote_id) WHERE is_deleted = FALSE;
