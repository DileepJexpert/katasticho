-- ============================================================
-- V20: Recurring Invoices — F8
--
-- A recurring_invoice is a TEMPLATE (not itself a financial
-- document) that the scheduler cron-fires on next_invoice_date
-- to mint fresh DRAFT invoices via InvoiceService.createInvoice.
-- The template has no journal impact — each generated invoice
-- follows the normal AR posting rules when it is sent.
--
-- Lifecycle:
--   ACTIVE  → scheduler will generate on next_invoice_date
--   PAUSED  → scheduler skips; can be resumed
--   STOPPED → manually halted; terminal
--   EXPIRED → reached end_date; terminal
-- ============================================================

CREATE TABLE recurring_invoice (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                   UUID           NOT NULL REFERENCES organisation(id),

    profile_name             VARCHAR(200)   NOT NULL,

    -- Buyer: unified contact (CUSTOMER or BOTH)
    contact_id               UUID           NOT NULL REFERENCES contact(id),

    frequency                VARCHAR(20)    NOT NULL
                             CHECK (frequency IN ('WEEKLY','MONTHLY','QUARTERLY','HALF_YEARLY','YEARLY')),

    start_date               DATE           NOT NULL,
    end_date                 DATE,                            -- open-ended if NULL
    next_invoice_date        DATE           NOT NULL,

    -- Template line items — stored as JSONB so the whole template
    -- round-trips atomically. Each element:
    --   { "itemId": "uuid?", "description": "...", "quantity": 1,
    --     "rate": 0, "discountPct": 0, "taxRate": 18, "hsnCode": "..." }
    line_items               JSONB          NOT NULL DEFAULT '[]'::jsonb,

    -- Default payment terms carried into each generated invoice
    -- (net N days from invoice date).
    payment_terms_days       INT            NOT NULL DEFAULT 0,

    -- If true, scheduler calls invoiceService.send() immediately
    -- after generation so the invoice hits the customer's inbox.
    auto_send                BOOLEAN        NOT NULL DEFAULT FALSE,

    status                   VARCHAR(20)    NOT NULL DEFAULT 'ACTIVE'
                             CHECK (status IN ('ACTIVE','PAUSED','STOPPED','EXPIRED')),

    -- Running counter + last-run timestamp for the detail screen.
    total_generated          INT            NOT NULL DEFAULT 0,
    last_generated_at        TIMESTAMPTZ,

    -- Optional fields copied onto every generated invoice
    notes                    TEXT,
    terms                    TEXT,
    currency                 VARCHAR(3)     NOT NULL DEFAULT 'INR',

    is_deleted               BOOLEAN        NOT NULL DEFAULT FALSE,
    created_at               TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ    NOT NULL DEFAULT now(),
    created_by               UUID           REFERENCES app_user(id)
);

CREATE INDEX idx_recurring_invoice_org          ON recurring_invoice(org_id)
    WHERE NOT is_deleted;

-- Primary scheduler query: "give me every ACTIVE template whose
-- next_invoice_date <= today" — index tuned for that.
CREATE INDEX idx_recurring_invoice_due          ON recurring_invoice(status, next_invoice_date)
    WHERE NOT is_deleted;

CREATE INDEX idx_recurring_invoice_contact      ON recurring_invoice(org_id, contact_id)
    WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────
-- Link table: generated invoices back to their source template.
-- Denormalised for the "list of generated invoices" panel on
-- the detail screen — avoids having to add a column to the
-- heavy invoice table.
-- ────────────────────────────────────────────────────────────
CREATE TABLE recurring_invoice_generation (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recurring_invoice_id     UUID           NOT NULL REFERENCES recurring_invoice(id) ON DELETE CASCADE,
    invoice_id               UUID           NOT NULL REFERENCES invoice(id),
    generated_at             TIMESTAMPTZ    NOT NULL DEFAULT now(),
    auto_sent                BOOLEAN        NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_recurring_invoice_gen_template ON recurring_invoice_generation(recurring_invoice_id);
CREATE UNIQUE INDEX idx_recurring_invoice_gen_invoice
    ON recurring_invoice_generation(invoice_id);
