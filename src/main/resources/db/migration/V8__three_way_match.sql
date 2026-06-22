-- 3-way match (PO ↔ GRN ↔ Bill). Catches over-billing / qty-over-receipt /
-- price hikes / amount mismatches before vendor payment. Uses the V7 FKs
-- (no heuristics). EXCEPTION bills surface in the AI Inbox; OWNER/ADMIN
-- may override with reason.

ALTER TABLE purchase_bill ADD COLUMN three_way_match_status VARCHAR(20)
    CHECK (three_way_match_status IS NULL OR three_way_match_status IN
        ('MATCHED','EXCEPTION','BYPASSED','OVERRIDDEN'));
ALTER TABLE purchase_bill ADD COLUMN three_way_match_at TIMESTAMPTZ;
ALTER TABLE purchase_bill ADD COLUMN three_way_match_overridden_by UUID;
ALTER TABLE purchase_bill ADD COLUMN three_way_match_override_reason TEXT;

CREATE TABLE bill_match_result_line (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL,
    bill_id UUID NOT NULL,
    bill_line_id UUID NOT NULL,
    po_line_id UUID,
    grn_line_id UUID,
    item_id UUID NOT NULL,
    billed_qty NUMERIC(15,4) NOT NULL,
    received_qty NUMERIC(15,4),
    ordered_qty NUMERIC(15,4),
    bill_unit_price NUMERIC(15,4) NOT NULL,
    po_unit_price NUMERIC(15,4),
    qty_variance NUMERIC(15,4),
    price_variance NUMERIC(15,4),
    amount_variance NUMERIC(15,4),
    status VARCHAR(20) NOT NULL CHECK (status IN
        ('MATCHED','QTY_OVER','PRICE_HIKE','AMOUNT_MISMATCH','NO_PO','NO_GRN','BYPASSED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_match_result_bill ON bill_match_result_line (org_id, bill_id);
CREATE INDEX idx_match_result_status ON bill_match_result_line (org_id, status)
    WHERE status <> 'MATCHED';
