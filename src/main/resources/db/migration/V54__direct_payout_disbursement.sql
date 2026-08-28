-- Migration: V54__direct_payout_disbursement.sql
-- Description: Creates payout_disbursement table for direct gateway disbursements (RazorpayX / Cashfree / Corporate Payouts).

CREATE TABLE IF NOT EXISTS public.payout_disbursement (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    provider VARCHAR(50) NOT NULL DEFAULT 'RAZORPAYX',
    provider_payout_id VARCHAR(100),
    utr VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'INITIATED',
    contact_id UUID NOT NULL,
    amount NUMERIC(14,4) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    payout_mode VARCHAR(20) NOT NULL DEFAULT 'IMPS',
    beneficiary_name VARCHAR(255),
    account_number VARCHAR(100),
    ifsc_code VARCHAR(50),
    vpa VARCHAR(255),
    vendor_payment_id UUID,
    failure_reason TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_payout_contact FOREIGN KEY (contact_id) REFERENCES public.contact(id),
    CONSTRAINT fk_payout_vendor_payment FOREIGN KEY (vendor_payment_id) REFERENCES public.vendor_payment(id)
);

CREATE INDEX IF NOT EXISTS idx_payout_org_status ON public.payout_disbursement(org_id, status);
CREATE INDEX IF NOT EXISTS idx_payout_contact ON public.payout_disbursement(contact_id);
CREATE INDEX IF NOT EXISTS idx_payout_provider_id ON public.payout_disbursement(provider, provider_payout_id);
