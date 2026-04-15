-- ============================================================
-- V19: Estimates / Quotations — F9
--
-- An estimate is a non-financial quote issued to a contact.
-- It has NO journal impact — totals sit on the record until
-- either the estimate is converted to an invoice (which posts
-- normal AR journals) or declines out. Lifecycle:
--
--   DRAFT    → saved, not sent
--   SENT     → emailed to customer
--   ACCEPTED → customer agreed
--   DECLINED → customer said no
--   INVOICED → converted to invoice (terminal)
--   EXPIRED  → past expiry_date (informational)
-- ============================================================

CREATE TABLE estimate (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                     UUID          NOT NULL REFERENCES organisation(id),
    branch_id                  UUID          REFERENCES branch(id),

    estimate_number            VARCHAR(30)   NOT NULL,   -- EST-YYYY-NNNNNN

    -- Buyer: unified contact (CUSTOMER or BOTH).
    contact_id                 UUID          NOT NULL REFERENCES contact(id),

    estimate_date              DATE          NOT NULL,
    expiry_date                DATE,

    status                     VARCHAR(20)   NOT NULL DEFAULT 'DRAFT'
                               CHECK (status IN ('DRAFT','SENT','ACCEPTED','DECLINED','INVOICED','EXPIRED')),

    -- Totals (no journal impact — stored as computed at save time).
    subtotal                   NUMERIC(15,2) NOT NULL DEFAULT 0,
    discount_amount            NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount                 NUMERIC(15,2) NOT NULL DEFAULT 0,
    total                      NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency                   VARCHAR(3)    NOT NULL DEFAULT 'INR',

    reference_number           VARCHAR(60),
    subject                    VARCHAR(200),
    notes                      TEXT,
    terms                      TEXT,

    -- Set when convertToInvoice() runs; points at the created draft invoice.
    converted_to_invoice_id    UUID          REFERENCES invoice(id),
    converted_at               TIMESTAMPTZ,

    sent_at                    TIMESTAMPTZ,
    accepted_at                TIMESTAMPTZ,
    declined_at                TIMESTAMPTZ,

    is_deleted                 BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at                 TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at                 TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by                 UUID          REFERENCES app_user(id)
);

CREATE UNIQUE INDEX idx_estimate_org_number   ON estimate(org_id, estimate_number)
    WHERE NOT is_deleted;
CREATE INDEX        idx_estimate_org_date     ON estimate(org_id, estimate_date DESC)
    WHERE NOT is_deleted;
CREATE INDEX        idx_estimate_org_status   ON estimate(org_id, status)
    WHERE NOT is_deleted;
CREATE INDEX        idx_estimate_org_contact  ON estimate(org_id, contact_id)
    WHERE NOT is_deleted;
CREATE INDEX        idx_estimate_converted    ON estimate(converted_to_invoice_id)
    WHERE converted_to_invoice_id IS NOT NULL;


-- ────────────────────────────────────────────────────────────
-- Estimate lines — mirror the invoice_line layout but carry no
-- accounting tie-in (no account_code at estimate time; that's
-- chosen when the estimate is converted into an invoice).
-- ────────────────────────────────────────────────────────────
CREATE TABLE estimate_line (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    estimate_id      UUID          NOT NULL REFERENCES estimate(id) ON DELETE CASCADE,
    line_number      INT           NOT NULL,

    item_id          UUID          REFERENCES item(id),
    description      VARCHAR(500)  NOT NULL,
    unit             VARCHAR(20),
    hsn_code         VARCHAR(10),

    quantity         NUMERIC(15,3) NOT NULL DEFAULT 1,
    rate             NUMERIC(15,2) NOT NULL DEFAULT 0,   -- unit price
    discount_pct     NUMERIC(5,2)  NOT NULL DEFAULT 0,
    tax_rate         NUMERIC(5,2)  NOT NULL DEFAULT 0,   -- GST rate %
    amount           NUMERIC(15,2) NOT NULL DEFAULT 0,   -- line total (post-tax)

    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_estimate_line_estimate ON estimate_line(estimate_id);
CREATE INDEX idx_estimate_line_item     ON estimate_line(item_id)
    WHERE item_id IS NOT NULL;
