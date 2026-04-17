-- V26: Make invoice.customer_id nullable
--
-- With unified contacts (V2), invoices can now be created with only a
-- contact_id. The legacy customer_id FK is no longer required — new
-- contacts created through the unified system may not have a row in
-- the customer table.

ALTER TABLE invoice ALTER COLUMN customer_id DROP NOT NULL;
