-- ============================================================================
-- V10: Stock Receipt (GRN) module — Sprint 25.5
--
-- The transaction-layer "stock IN" document. One header, many lines, one
-- click receives all lines and posts immutable stock_movement rows via
-- InventoryService.recordMovement().
--
-- Tables created:
--   supplier              — minimal vendor master (name + GSTIN + address)
--   stock_receipt         — header (supplier, date, status, totals)
--   stock_receipt_line    — itemised lines (item, qty, price, batch, expiry)
--
-- Also extends stock_movement.reference_type to allow STOCK_RECEIPT.
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Supplier — minimal master so GRNs FK to a real entity from day one.
--    Vendor bills, payments, three-way matching land in v2 (AP module).
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE supplier (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    name            VARCHAR(255) NOT NULL,
    gstin           VARCHAR(15),
    pan             VARCHAR(10),
    phone           VARCHAR(30),
    email           VARCHAR(255),
    -- Billing address
    address_line1   VARCHAR(255),
    address_line2   VARCHAR(255),
    city            VARCHAR(100),
    state           VARCHAR(100),
    state_code      VARCHAR(5),
    postal_code     VARCHAR(20),
    country         VARCHAR(2) DEFAULT 'IN',
    -- Defaults for new GRNs
    payment_terms_days INTEGER NOT NULL DEFAULT 30,
    notes           TEXT,
    -- Lifecycle
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE INDEX idx_supplier_org_name ON supplier(org_id, name) WHERE NOT is_deleted;
CREATE INDEX idx_supplier_org_active ON supplier(org_id, is_active) WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_supplier_org_gstin ON supplier(org_id, gstin)
    WHERE gstin IS NOT NULL AND NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Stock receipt header — DRAFT → RECEIVED → CANCELLED
--    Cancellation = create reversal movements; original lines stay intact.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE stock_receipt (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    receipt_number  VARCHAR(30) NOT NULL,                  -- GRN-2026-000001
    receipt_date    DATE NOT NULL,
    warehouse_id    UUID NOT NULL REFERENCES warehouse(id),
    supplier_id     UUID NOT NULL REFERENCES supplier(id),
    -- Vendor's own document refs (informational; no FK)
    supplier_invoice_no   VARCHAR(100),
    supplier_invoice_date DATE,
    -- Totals (in INR for v1)
    subtotal        NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount    NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency        CHAR(3) NOT NULL DEFAULT 'INR',
    -- Status
    status          VARCHAR(15) NOT NULL DEFAULT 'DRAFT'
                    CHECK (status IN ('DRAFT','RECEIVED','CANCELLED')),
    -- Lifecycle
    received_at     TIMESTAMPTZ,
    received_by     UUID,
    cancelled_at    TIMESTAMPTZ,
    cancelled_by    UUID,
    cancel_reason   VARCHAR(500),
    notes           TEXT,
    period_year     INTEGER,
    period_month    INTEGER,
    -- Soft delete + audit
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_stock_receipt_org_number
    ON stock_receipt(org_id, receipt_number) WHERE NOT is_deleted;
CREATE INDEX idx_stock_receipt_org_date ON stock_receipt(org_id, receipt_date);
CREATE INDEX idx_stock_receipt_org_supplier ON stock_receipt(org_id, supplier_id);
CREATE INDEX idx_stock_receipt_org_status ON stock_receipt(org_id, status);


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Stock receipt line — every line MUST link to an item (unlike invoice
--    lines, GRNs are pure inventory documents — no free-text "consulting").
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE stock_receipt_line (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id      UUID NOT NULL REFERENCES stock_receipt(id) ON DELETE CASCADE,
    line_number     INTEGER NOT NULL,
    item_id         UUID NOT NULL REFERENCES item(id),
    description     VARCHAR(500),                  -- denormalised item name at receipt time
    hsn_code        VARCHAR(10),
    -- Quantity is always positive on the line; service negates as needed.
    quantity        NUMERIC(15,4) NOT NULL,
    unit_of_measure VARCHAR(20) NOT NULL DEFAULT 'PCS',
    unit_price      NUMERIC(15,4) NOT NULL,
    discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
    discount_amount  NUMERIC(15,2) NOT NULL DEFAULT 0,
    taxable_amount   NUMERIC(15,2) NOT NULL,
    gst_rate         NUMERIC(5,2) NOT NULL DEFAULT 0,
    tax_amount       NUMERIC(15,2) NOT NULL DEFAULT 0,
    line_total       NUMERIC(15,2) NOT NULL,
    -- Optional batch / expiry — used by pharmacies. Sprint 26 will introduce
    -- a real batch master; for now we just store the strings here so the
    -- info isn't lost, and the link to the future batch.id is added later.
    batch_number     VARCHAR(50),
    batch_id         UUID,
    expiry_date      DATE,
    manufacturing_date DATE,
    -- After "receive": link back to the immutable ledger row this line created.
    stock_movement_id UUID REFERENCES stock_movement(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_receipt_line_receipt ON stock_receipt_line(receipt_id);
CREATE INDEX idx_stock_receipt_line_item ON stock_receipt_line(item_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Extend stock_movement.reference_type to include STOCK_RECEIPT.
--    The CHECK constraint in V8 didn't know about GRNs.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE stock_movement DROP CONSTRAINT IF EXISTS stock_movement_reference_type_check;

ALTER TABLE stock_movement ADD CONSTRAINT stock_movement_reference_type_check
    CHECK (reference_type IN (
        'INVOICE','CREDIT_NOTE','BILL','DEBIT_NOTE',
        'STOCK_ADJUSTMENT','STOCK_TRANSFER','STOCK_COUNT','OPENING_BALANCE',
        'STOCK_RECEIPT'
    ));
