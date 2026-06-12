-- V69: Field samples/promo stock + TA/DA allowance claims (all verticals)
-- Phase 2 of the field-force pack: works for pharma (medicine samples),
-- FMCG (promo material/POSM), and any distributor running the field app.

-- Samples / promotional material issued to (or returned by) a field salesperson.
-- Distribution to customers is tallied from visit_product_log, so
-- balance = issued - returned - distributed.
CREATE TABLE field_sample_txn (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    item_id UUID,
    product_name VARCHAR(200) NOT NULL,
    txn_type VARCHAR(10) NOT NULL,          -- ISSUE / RETURN
    quantity INT NOT NULL,
    txn_date DATE NOT NULL,
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_fst_org_salesperson ON field_sample_txn(org_id, salesperson_id);

-- One TA/DA allowance claim per salesperson per day. Amount is computed
-- from the GPS distance trail (TA per km) + flat daily allowance, and the
-- created expense carries the accounting.
CREATE TABLE field_allowance_claim (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    claim_date DATE NOT NULL,
    distance_km NUMERIC(10,2) NOT NULL DEFAULT 0,
    ta_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    da_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
    expense_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_fac_day ON field_allowance_claim(org_id, salesperson_id, claim_date);
