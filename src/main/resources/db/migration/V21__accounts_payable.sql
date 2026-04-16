-- ============================================================
-- V21: Accounts Payable — Purchase Bills, Vendor Payments,
--      Vendor Credits
--
-- Mirrors the AR module (invoice/payment/credit_note) with
-- money flowing in the opposite direction. Key differences:
--   - vendor_bill_number: vendor's own ref (not our bill_number)
--   - vendor_payment_allocation: many-to-many (one payment can
--     settle multiple bills)
--   - vendor_credit_application: tracks which bills a credit
--     was applied against
--   - All tables carry branch_id (nullable, FK to branch)
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. PURCHASE BILL  (vendor invoice we owe)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE purchase_bill (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id            UUID          NOT NULL REFERENCES organisation(id),
    branch_id         UUID          REFERENCES branch(id),
    contact_id        UUID          NOT NULL REFERENCES contact(id),

    bill_number       VARCHAR(30)   NOT NULL,                    -- our internal number BILL-YYYY-NNNN
    vendor_bill_number VARCHAR(100),                             -- vendor's own invoice/ref number
    bill_date         DATE          NOT NULL,
    due_date          DATE          NOT NULL,

    status            VARCHAR(20)   NOT NULL DEFAULT 'DRAFT'
                      CHECK (status IN ('DRAFT','OPEN','PARTIALLY_PAID','PAID','VOID','OVERDUE')),

    subtotal          NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount        NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    amount_paid       NUMERIC(15,2) NOT NULL DEFAULT 0,
    balance_due       NUMERIC(15,2) NOT NULL DEFAULT 0,

    currency          VARCHAR(3)    NOT NULL DEFAULT 'INR',
    exchange_rate     NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    base_subtotal     NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount   NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_total        NUMERIC(15,2) NOT NULL DEFAULT 0,

    place_of_supply   VARCHAR(5),
    is_reverse_charge BOOLEAN       NOT NULL DEFAULT FALSE,

    tds_amount        NUMERIC(15,2) NOT NULL DEFAULT 0,
    tds_section       VARCHAR(20),

    journal_entry_id  UUID          REFERENCES journal_entry(id),
    notes             TEXT,
    terms_and_conditions TEXT,

    period_year       INTEGER,
    period_month      INTEGER,

    posted_at         TIMESTAMPTZ,
    voided_at         TIMESTAMPTZ,
    voided_by         UUID,
    void_reason       TEXT,

    is_deleted        BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by        UUID
);

CREATE UNIQUE INDEX idx_purchase_bill_org_number ON purchase_bill(org_id, bill_number)
    WHERE NOT is_deleted;
CREATE INDEX idx_purchase_bill_org_status  ON purchase_bill(org_id, status);
CREATE INDEX idx_purchase_bill_contact     ON purchase_bill(contact_id);
CREATE INDEX idx_purchase_bill_org_date    ON purchase_bill(org_id, bill_date);
CREATE INDEX idx_purchase_bill_org_due     ON purchase_bill(org_id, due_date)
    WHERE status IN ('OPEN','PARTIALLY_PAID','OVERDUE');
CREATE INDEX idx_purchase_bill_branch      ON purchase_bill(org_id, branch_id)
    WHERE branch_id IS NOT NULL AND NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 2. PURCHASE BILL LINE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE purchase_bill_line (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_bill_id     UUID          NOT NULL REFERENCES purchase_bill(id) ON DELETE CASCADE,
    line_number          INTEGER       NOT NULL,
    description          VARCHAR(500)  NOT NULL,
    hsn_code             VARCHAR(10),
    item_id              UUID          REFERENCES item(id),
    account_id           UUID          NOT NULL REFERENCES account(id),
    quantity             NUMERIC(12,4) NOT NULL DEFAULT 1,
    unit_price           NUMERIC(15,2) NOT NULL,
    discount_percent     NUMERIC(5,2)  NOT NULL DEFAULT 0,
    discount_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    taxable_amount       NUMERIC(15,2) NOT NULL,
    gst_rate             NUMERIC(5,2)  NOT NULL DEFAULT 0,
    tax_amount           NUMERIC(15,2) NOT NULL DEFAULT 0,
    line_total           NUMERIC(15,2) NOT NULL,
    base_taxable_amount  NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_line_total      NUMERIC(15,2) NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_purchase_bill_line_bill ON purchase_bill_line(purchase_bill_id);
CREATE INDEX idx_purchase_bill_line_item ON purchase_bill_line(item_id)
    WHERE item_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 3. VENDOR PAYMENT  (outbound payment to vendor)
--    One payment can be allocated across multiple bills via
--    the vendor_payment_allocation junction table.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE vendor_payment (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id            UUID          NOT NULL REFERENCES organisation(id),
    branch_id         UUID          REFERENCES branch(id),
    contact_id        UUID          NOT NULL REFERENCES contact(id),

    payment_number    VARCHAR(30)   NOT NULL,                    -- VPAY-YYYY-NNNN
    payment_date      DATE          NOT NULL,
    amount            NUMERIC(15,2) NOT NULL CHECK (amount > 0),

    currency          VARCHAR(3)    NOT NULL DEFAULT 'INR',
    exchange_rate     NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    base_amount       NUMERIC(15,2) NOT NULL,

    payment_mode      VARCHAR(30)   NOT NULL
                      CHECK (payment_mode IN ('CASH','BANK_TRANSFER','UPI','CHEQUE','CARD','OTHER')),
    paid_through_id   UUID          NOT NULL REFERENCES account(id),  -- Cash/Bank GL account
    reference_number  VARCHAR(100),

    tds_amount        NUMERIC(15,2) NOT NULL DEFAULT 0,
    tds_section       VARCHAR(20),

    notes             TEXT,
    journal_entry_id  UUID          REFERENCES journal_entry(id),

    is_deleted        BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by        UUID
);

CREATE UNIQUE INDEX idx_vendor_payment_org_number ON vendor_payment(org_id, payment_number)
    WHERE NOT is_deleted;
CREATE INDEX idx_vendor_payment_contact    ON vendor_payment(contact_id);
CREATE INDEX idx_vendor_payment_org_date   ON vendor_payment(org_id, payment_date);
CREATE INDEX idx_vendor_payment_branch     ON vendor_payment(org_id, branch_id)
    WHERE branch_id IS NOT NULL AND NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 4. VENDOR PAYMENT ALLOCATION  (many-to-many junction)
--    One payment can settle multiple bills; one bill can be
--    settled by multiple payments over time.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE vendor_payment_allocation (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_payment_id   UUID          NOT NULL REFERENCES vendor_payment(id) ON DELETE CASCADE,
    purchase_bill_id    UUID          NOT NULL REFERENCES purchase_bill(id),
    amount_applied      NUMERIC(15,2) NOT NULL CHECK (amount_applied > 0),
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_vpa_payment ON vendor_payment_allocation(vendor_payment_id);
CREATE INDEX idx_vpa_bill    ON vendor_payment_allocation(purchase_bill_id);
CREATE UNIQUE INDEX idx_vpa_payment_bill ON vendor_payment_allocation(vendor_payment_id, purchase_bill_id);


-- ─────────────────────────────────────────────────────────────
-- 5. VENDOR CREDIT  (return to vendor / vendor debit note)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE vendor_credit (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID          NOT NULL REFERENCES organisation(id),
    branch_id           UUID          REFERENCES branch(id),
    contact_id          UUID          NOT NULL REFERENCES contact(id),

    credit_number       VARCHAR(30)   NOT NULL,                  -- VCRED-YYYY-NNNN
    credit_date         DATE          NOT NULL,
    purchase_bill_id    UUID          REFERENCES purchase_bill(id),  -- original bill (optional)

    status              VARCHAR(20)   NOT NULL DEFAULT 'DRAFT'
                        CHECK (status IN ('DRAFT','OPEN','APPLIED','VOID')),

    subtotal            NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount        NUMERIC(15,2) NOT NULL DEFAULT 0,
    balance             NUMERIC(15,2) NOT NULL DEFAULT 0,        -- remaining unapplied amount

    currency            VARCHAR(3)    NOT NULL DEFAULT 'INR',
    exchange_rate       NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    base_subtotal       NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount     NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_total          NUMERIC(15,2) NOT NULL DEFAULT 0,

    place_of_supply     VARCHAR(5),
    reason              TEXT          NOT NULL,
    journal_entry_id    UUID          REFERENCES journal_entry(id),

    is_deleted          BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by          UUID
);

CREATE UNIQUE INDEX idx_vendor_credit_org_number ON vendor_credit(org_id, credit_number)
    WHERE NOT is_deleted;
CREATE INDEX idx_vendor_credit_contact   ON vendor_credit(contact_id);
CREATE INDEX idx_vendor_credit_org_status ON vendor_credit(org_id, status)
    WHERE NOT is_deleted;
CREATE INDEX idx_vendor_credit_bill      ON vendor_credit(purchase_bill_id)
    WHERE purchase_bill_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 6. VENDOR CREDIT LINE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE vendor_credit_line (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_credit_id     UUID          NOT NULL REFERENCES vendor_credit(id) ON DELETE CASCADE,
    line_number          INTEGER       NOT NULL,
    description          VARCHAR(500)  NOT NULL,
    hsn_code             VARCHAR(10),
    item_id              UUID          REFERENCES item(id),
    account_id           UUID          NOT NULL REFERENCES account(id),
    quantity             NUMERIC(12,4) NOT NULL DEFAULT 1,
    unit_price           NUMERIC(15,2) NOT NULL,
    taxable_amount       NUMERIC(15,2) NOT NULL,
    gst_rate             NUMERIC(5,2)  NOT NULL DEFAULT 0,
    tax_amount           NUMERIC(15,2) NOT NULL DEFAULT 0,
    line_total           NUMERIC(15,2) NOT NULL,
    base_taxable_amount  NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_line_total      NUMERIC(15,2) NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_vendor_credit_line_credit ON vendor_credit_line(vendor_credit_id);
CREATE INDEX idx_vendor_credit_line_item   ON vendor_credit_line(item_id)
    WHERE item_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 7. VENDOR CREDIT APPLICATION  (apply credit against a bill)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE vendor_credit_application (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_credit_id    UUID          NOT NULL REFERENCES vendor_credit(id),
    purchase_bill_id    UUID          NOT NULL REFERENCES purchase_bill(id),
    amount_applied      NUMERIC(15,2) NOT NULL CHECK (amount_applied > 0),
    applied_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    applied_by          UUID,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_vca_credit ON vendor_credit_application(vendor_credit_id);
CREATE INDEX idx_vca_bill   ON vendor_credit_application(purchase_bill_id);


-- ─────────────────────────────────────────────────────────────
-- 8. WIDEN tax_line_item source_type TO INCLUDE VENDOR CREDIT
--    V1 defined: ('INVOICE','CREDIT_NOTE','BILL','EXPENSE')
--    Add 'VENDOR_CREDIT' for tax breakdowns on vendor credits
-- ─────────────────────────────────────────────────────────────
ALTER TABLE tax_line_item
    DROP CONSTRAINT IF EXISTS tax_line_item_source_type_check;

ALTER TABLE tax_line_item
    ADD CONSTRAINT tax_line_item_source_type_check
    CHECK (source_type IN ('INVOICE','CREDIT_NOTE','BILL','EXPENSE','VENDOR_CREDIT'));
