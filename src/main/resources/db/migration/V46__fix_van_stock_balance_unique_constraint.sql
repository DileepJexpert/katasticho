-- V44: Safety net for databases where V42 ran before the inline UNIQUE fix.
-- On fresh databases (with fixed V42), the DROP is a no-op and the CREATE
-- uses IF NOT EXISTS. On old databases, this replaces the constraint with
-- a proper expression index.

ALTER TABLE van_stock_balance DROP CONSTRAINT IF EXISTS van_stock_balance_org_id_van_id_item_id_coalesce_key;

CREATE UNIQUE INDEX IF NOT EXISTS uq_van_stock_balance_org_van_item_batch
    ON van_stock_balance(org_id, van_id, item_id, COALESCE(batch_id, '00000000-0000-0000-0000-000000000000'));
