-- V69: Backfill audit columns missed by V61.
-- The V61 MRP/warehouse/logistics tables map to BaseEntity (which includes
-- created_by) but the CREATE TABLE statements omitted it, so Hibernate
-- schema validation fails on a fresh database.
ALTER TABLE mrp_run        ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE mrp_demand     ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE mrp_supply     ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE planned_order  ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE warehouse_zone ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE shipment       ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE shipment_line  ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE batch_trace    ADD COLUMN IF NOT EXISTS created_by UUID;

-- Same omission in other BaseEntity-mapped tables (V46/V60/V62 line tables).
ALTER TABLE work_order_line           ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE purchase_requisition_line ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE return_order_line         ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE production_cost_summary   ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE integration_sync_log      ADD COLUMN IF NOT EXISTS created_by UUID;
