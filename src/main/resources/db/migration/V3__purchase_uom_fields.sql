-- V3: Add purchase UoM fields to item table for Kirana multi-unit buying/selling
ALTER TABLE item ADD COLUMN IF NOT EXISTS purchase_uom_id UUID REFERENCES uom(id);
ALTER TABLE item ADD COLUMN IF NOT EXISTS purchase_uom_conversion NUMERIC(15,4);
ALTER TABLE item ADD COLUMN IF NOT EXISTS purchase_price_per_uom NUMERIC(15,2);

-- Add unit field to purchase bill lines so bills can record the purchase UoM used
ALTER TABLE purchase_bill_line ADD COLUMN IF NOT EXISTS unit_uom_id UUID REFERENCES uom(id);
ALTER TABLE purchase_bill_line ADD COLUMN IF NOT EXISTS unit_conversion_factor NUMERIC(15,4);
ALTER TABLE purchase_bill_line ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(15,4);

-- Add unit field to sales receipt lines for multi-unit selling
ALTER TABLE sales_receipt_line ADD COLUMN IF NOT EXISTS unit_uom_id UUID REFERENCES uom(id);
ALTER TABLE sales_receipt_line ADD COLUMN IF NOT EXISTS unit_conversion_factor NUMERIC(15,4);
ALTER TABLE sales_receipt_line ADD COLUMN IF NOT EXISTS base_quantity NUMERIC(15,4);

-- Per-item secondary selling unit prices (e.g. eggs ₹80/dozen instead of 12×₹7=₹84)
CREATE TABLE IF NOT EXISTS item_unit_price (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID          NOT NULL REFERENCES organisation(id),
    item_id      UUID          NOT NULL REFERENCES item(id),
    uom_id       UUID          NOT NULL REFERENCES uom(id),
    conversion_factor NUMERIC(15,4) NOT NULL CHECK (conversion_factor > 0),
    custom_price NUMERIC(15,2),
    is_deleted   BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by   UUID,
    CONSTRAINT item_unit_price_unique UNIQUE (org_id, item_id, uom_id)
);

CREATE INDEX IF NOT EXISTS idx_item_unit_price_item ON item_unit_price(org_id, item_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_item_purchase_uom ON item(purchase_uom_id) WHERE purchase_uom_id IS NOT NULL;
