-- V47: Add missing created_by columns to tables whose JPA entities extend BaseEntity.
-- Fixes: serial_number (V38) and published_catalog_item (V43) were created before
-- the created_by requirement was standardized. BaseEntity maps this column.

ALTER TABLE serial_number ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE published_catalog_item ADD COLUMN IF NOT EXISTS created_by UUID;
