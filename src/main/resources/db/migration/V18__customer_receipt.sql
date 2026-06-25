-- AR multi-invoice receipt + customer advance (C3).
--
-- The legacy `payment` table is strictly one payment ↔ one invoice. A
-- `customer_receipt` is the AR mirror of `vendor_payment`: a single lump-sum
-- collection from a customer that is allocated across many open invoices via
-- `customer_receipt_allocation`, with any unallocated excess parked as a
-- Customer Advance (CoA 2100) liability (`advance_amount`).
--
-- The legacy single-invoice `payment` path is left entirely untouched, so this
-- is purely additive.

CREATE TABLE customer_receipt (
    id                  UUID PRIMARY KEY,
    org_id              UUID NOT NULL,
    branch_id           UUID,
    contact_id          UUID NOT NULL,
    receipt_number      VARCHAR(30) NOT NULL,
    receipt_date        DATE NOT NULL,
    amount              NUMERIC(18, 2) NOT NULL,             -- total received
    allocated_amount    NUMERIC(18, 2) NOT NULL DEFAULT 0,   -- Σ allocations
    advance_amount      NUMERIC(18, 2) NOT NULL DEFAULT 0,   -- amount − allocated
    currency            VARCHAR(3) NOT NULL DEFAULT 'INR',
    exchange_rate       NUMERIC(18, 6) NOT NULL DEFAULT 1,
    base_amount         NUMERIC(18, 2) NOT NULL,
    payment_method      VARCHAR(30) NOT NULL,
    reference_number    VARCHAR(100),
    notes               TEXT,
    journal_entry_id    UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL,
    updated_at          TIMESTAMPTZ NOT NULL,
    created_by          UUID,
    CONSTRAINT customer_receipt_amount_chk      CHECK (amount > 0),
    CONSTRAINT customer_receipt_advance_chk     CHECK (advance_amount >= 0),
    CONSTRAINT customer_receipt_allocated_chk   CHECK (allocated_amount >= 0)
);

CREATE TABLE customer_receipt_allocation (
    id                  UUID PRIMARY KEY,
    customer_receipt_id UUID NOT NULL REFERENCES customer_receipt(id),
    invoice_id          UUID NOT NULL,
    amount_applied      NUMERIC(18, 2) NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    CONSTRAINT customer_receipt_allocation_amount_chk CHECK (amount_applied > 0),
    -- one receipt can apply to a given invoice at most once
    CONSTRAINT customer_receipt_allocation_uq UNIQUE (customer_receipt_id, invoice_id)
);

-- Receipt list / customer-statement scans (newest first).
CREATE INDEX idx_customer_receipt_org_date
    ON customer_receipt (org_id, receipt_date DESC)
    WHERE is_deleted = FALSE;

-- "What has this customer paid?" + advance-balance roll-up.
CREATE INDEX idx_customer_receipt_org_contact
    ON customer_receipt (org_id, contact_id)
    WHERE is_deleted = FALSE;

-- "Which receipts touched this invoice?" for the invoice detail screen.
CREATE INDEX idx_customer_receipt_allocation_invoice
    ON customer_receipt_allocation (invoice_id);
