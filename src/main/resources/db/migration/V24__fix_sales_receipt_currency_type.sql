-- V24: Convert sales_receipt.currency from CHAR(3) to VARCHAR(3) for Hibernate compatibility
ALTER TABLE sales_receipt ALTER COLUMN currency TYPE VARCHAR(3);
