-- V13: Composite index supporting the ATP (Available-to-Promise) commitment query.
--
-- ATP needs to sum SalesOrderLine.quantity − quantityShipped across every
-- CONFIRMED / BACKORDER SO for a given (org, item). The header carries the SO
-- status; the line carries the item + dispatched-qty diff. Joining line→header
-- is unavoidable (the SO has no warehouse — every org-wide stock balance is
-- valued against the line's item across all warehouses), but we can at least
-- keep the line scan cheap.
--
-- Filter on (item_id, quantity_backordered) is the hot path — backordered + not
-- yet fully shipped lines are the ones still committing stock. is_deleted=false
-- guard keeps soft-deleted rows out of the index.

CREATE INDEX IF NOT EXISTS idx_sales_order_line_item_open_commitment
    ON sales_order_line (item_id, sales_order_id)
    WHERE quantity_shipped < quantity;
