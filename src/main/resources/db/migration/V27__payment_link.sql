-- V27 — Payment-gateway payment links on invoices (Razorpay-first) + a signed
-- webhook that auto-records the AR payment.
--
-- A seller creates a hosted payment link for an invoice's balance; the customer
-- pays via UPI/card/netbanking on Razorpay's page; Razorpay POSTs a signed
-- webhook back and the payment settles the invoice automatically (DR Bank /
-- CR AR, the same journal a manual receipt posts).
--
-- Two tables:
--   payment_link         — one row per created link (the ONLY mapping the
--                          JWT-less webhook has to resolve invoice + org).
--   payment_webhook_event — append-only dedupe log so a retried/duplicated
--                          Razorpay event never double-settles the invoice.

CREATE TABLE payment_link (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    invoice_id UUID NOT NULL,
    contact_id UUID,
    provider VARCHAR(20) NOT NULL DEFAULT 'RAZORPAY'
        CHECK (provider IN ('RAZORPAY')),
    provider_link_id VARCHAR(64),          -- Razorpay 'plink_...' id (null until create returns)
    reference_id VARCHAR(40) NOT NULL,     -- = invoice.invoice_number, sent as Razorpay reference_id
    short_url TEXT,                        -- the hosted payment page URL
    amount NUMERIC(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'CREATED'
        CHECK (status IN ('CREATED', 'PAID', 'PARTIALLY_PAID', 'CANCELLED', 'EXPIRED', 'FAILED')),
    provider_payment_id VARCHAR(64),       -- Razorpay 'pay_...' captured id (set by webhook)
    recorded_payment_id UUID,              -- FK to the Payment row we created on settlement
    paid_at TIMESTAMPTZ,
    last_event_id VARCHAR(80),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX idx_payment_link_invoice ON payment_link (org_id, invoice_id) WHERE NOT is_deleted;
-- Resolve a link from the Razorpay plink id (webhook lookup).
CREATE UNIQUE INDEX uq_payment_link_provider_link
    ON payment_link (provider, provider_link_id)
    WHERE provider_link_id IS NOT NULL AND NOT is_deleted;
-- Cross-tenant idempotency guard: the same captured payment can never be
-- recorded against two links / twice.
CREATE UNIQUE INDEX uq_payment_link_provider_payment
    ON payment_link (provider, provider_payment_id)
    WHERE provider_payment_id IS NOT NULL AND NOT is_deleted;

CREATE TABLE payment_webhook_event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID,
    provider VARCHAR(20) NOT NULL,
    event_id VARCHAR(80) NOT NULL,
    event_type VARCHAR(60),
    payment_link_id UUID,
    signature_valid BOOLEAN NOT NULL DEFAULT false,
    processed BOOLEAN NOT NULL DEFAULT false,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The primary dedupe: Razorpay stamps an idempotent x-razorpay-event-id.
CREATE UNIQUE INDEX uq_payment_webhook_event ON payment_webhook_event (provider, event_id);
CREATE INDEX idx_payment_webhook_event_org ON payment_webhook_event (org_id, received_at DESC);
