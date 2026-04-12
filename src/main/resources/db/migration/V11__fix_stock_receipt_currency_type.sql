-- V11: Fix stock_receipt.currency column type for Hibernate 6.x compatibility.
--
-- V10 declared `currency CHAR(3)` which PostgreSQL reports as `bpchar`, but
-- the JPA entity StockReceipt maps `currency` as a plain String that
-- Hibernate's PostgreSQL dialect validates against VARCHAR(3). This mirrors
-- the V7 fix for the earlier CHAR(3) currency columns in V3.

ALTER TABLE stock_receipt ALTER COLUMN currency TYPE VARCHAR(3);
