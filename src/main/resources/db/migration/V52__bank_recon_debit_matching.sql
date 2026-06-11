-- V52: Bank reconciliation — debit-side (vendor bill) matching
--
-- payment_match was invoice-only (money in). Outgoing (DEBIT) bank
-- transactions now match against open purchase bills too: match_type says
-- which side, bill_id points at the purchase bill for BILL matches.

ALTER TABLE payment_match
    ADD COLUMN match_type VARCHAR(20) NOT NULL DEFAULT 'INVOICE',
    ADD COLUMN bill_id UUID;

CREATE INDEX idx_payment_match_bill ON payment_match (org_id, bill_id) WHERE bill_id IS NOT NULL;
