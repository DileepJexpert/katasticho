-- V31 — Instalment payment terms + dunning levels (Odoo parity, MASTER_GAP_TRACKER H2).
--
-- Two related AR-collections capabilities, both purely additive — the existing
-- payment/allocation engine (the single InvoiceService.updatePaymentStatus that
-- recomputes balanceDue = totalAmount - amountPaid) is NOT touched:
--
--   1. Payment terms with instalments — a payment_term is a named schedule of
--      lines (percent-of-total + days-offset, optional trailing BALANCE line).
--      Applying a term to an invoice materialises invoice_instalment rows and
--      sets the invoice's due_date to the final instalment. Per-instalment paid
--      status is DERIVED at read time from the invoice's existing amountPaid
--      (oldest-first waterfall), so no payment row ever targets a dated sub-balance.
--   2. Dunning levels — org-defined escalating reminder stages keyed on days
--      overdue. A scheduled job walks overdue invoices (instalment-aware) and
--      fires the highest applicable not-yet-sent level via EMAIL / WHATSAPP /
--      AI_INBOX / NONE, recording one dunning_log row per (invoice, level).

-- ── Payment terms ────────────────────────────────────────────────────────────
CREATE TABLE payment_term (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    is_default BOOLEAN NOT NULL DEFAULT false,
    active BOOLEAN NOT NULL DEFAULT true,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
CREATE INDEX idx_payment_term_org ON payment_term (org_id) WHERE NOT is_deleted;

CREATE TABLE payment_term_line (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    payment_term_id UUID NOT NULL,
    seq INTEGER NOT NULL DEFAULT 0,
    value_type VARCHAR(10) NOT NULL DEFAULT 'PERCENT' CHECK (value_type IN ('PERCENT', 'BALANCE')),
    value NUMERIC(9,4) NOT NULL DEFAULT 0,     -- percent-of-total when PERCENT; ignored for BALANCE
    days_offset INTEGER NOT NULL DEFAULT 0,    -- due = invoice_date + days_offset
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
CREATE INDEX idx_payment_term_line_term ON payment_term_line (payment_term_id) WHERE NOT is_deleted;

CREATE TABLE invoice_instalment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    invoice_id UUID NOT NULL,
    payment_term_id UUID,                       -- provenance (nullable)
    seq INTEGER NOT NULL DEFAULT 0,
    amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    due_date DATE NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
CREATE INDEX idx_invoice_instalment_invoice ON invoice_instalment (invoice_id) WHERE NOT is_deleted;
CREATE INDEX idx_invoice_instalment_org_due ON invoice_instalment (org_id, due_date) WHERE NOT is_deleted;
CREATE UNIQUE INDEX uq_invoice_instalment_seq ON invoice_instalment (invoice_id, seq) WHERE NOT is_deleted;

-- ── Dunning ──────────────────────────────────────────────────────────────────
CREATE TABLE dunning_level (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    seq INTEGER NOT NULL DEFAULT 0,
    name VARCHAR(120) NOT NULL,
    days_overdue INTEGER NOT NULL DEFAULT 0,    -- trigger threshold
    channel VARCHAR(12) NOT NULL DEFAULT 'AI_INBOX' CHECK (channel IN ('EMAIL', 'WHATSAPP', 'AI_INBOX', 'NONE')),
    subject VARCHAR(200),
    message_template TEXT,                       -- {{customer}} {{amount}} {{days}} {{invoiceNumber}} {{dueDate}} {{orgName}}
    active BOOLEAN NOT NULL DEFAULT true,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
CREATE INDEX idx_dunning_level_org ON dunning_level (org_id, seq) WHERE NOT is_deleted;

CREATE TABLE dunning_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    invoice_id UUID NOT NULL,
    contact_id UUID,
    dunning_level_id UUID NOT NULL,
    days_overdue INTEGER NOT NULL DEFAULT 0,
    amount NUMERIC(18,2) NOT NULL DEFAULT 0,
    channel VARCHAR(12) NOT NULL,
    outcome VARCHAR(20) NOT NULL DEFAULT 'SENT',  -- SENT / SKIPPED / FAILED
    detail TEXT,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
-- One SUCCESSFUL send per (invoice, level); FAILED rows don't block a later retry.
CREATE UNIQUE INDEX uq_dunning_log_sent ON dunning_log (org_id, invoice_id, dunning_level_id)
    WHERE outcome = 'SENT' AND NOT is_deleted;
CREATE INDEX idx_dunning_log_org_sent ON dunning_log (org_id, sent_at DESC) WHERE NOT is_deleted;
CREATE INDEX idx_dunning_log_invoice ON dunning_log (invoice_id) WHERE NOT is_deleted;
