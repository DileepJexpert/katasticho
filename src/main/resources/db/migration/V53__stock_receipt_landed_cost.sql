-- Landed cost on goods receipt: header-level additional charges (freight, duty,
-- insurance, other) that get apportioned across received lines by value and
-- baked into each item's stock cost at receive time.
--
-- GRN receive posts no journal (financial side is the purchase bill), so this
-- only affects stock_movement.unit_cost and item.purchase_price — the
-- weighted-average cost in stock_balance then reflects the true landed cost.

ALTER TABLE stock_receipt
    ADD COLUMN freight_amount   NUMERIC(15,2) NOT NULL DEFAULT 0,
    ADD COLUMN duty_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    ADD COLUMN insurance_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    ADD COLUMN other_charges    NUMERIC(15,2) NOT NULL DEFAULT 0;

-- Per-unit landed cost actually applied at receive time, kept for audit/display.
ALTER TABLE stock_receipt_line
    ADD COLUMN landed_unit_cost NUMERIC(15,4);
