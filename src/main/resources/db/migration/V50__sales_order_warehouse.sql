-- Persist the fulfilment warehouse selected for a sales order.
-- Existing orders are backfilled from the organisation default where possible;
-- new orders validate the warehouse in SalesOrderService.
ALTER TABLE sales_order
    ADD COLUMN IF NOT EXISTS warehouse_id uuid;

UPDATE sales_order so
SET warehouse_id = w.id
FROM warehouse w
WHERE so.warehouse_id IS NULL
  AND w.org_id = so.org_id
  AND w.is_default = TRUE
  AND w.is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_sales_order_org_warehouse
    ON sales_order (org_id, warehouse_id)
    WHERE is_deleted = FALSE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_sales_order_warehouse'
    ) THEN
        ALTER TABLE sales_order
            ADD CONSTRAINT fk_sales_order_warehouse
            FOREIGN KEY (warehouse_id) REFERENCES warehouse(id);
    END IF;
END $$;
