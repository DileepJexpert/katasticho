-- V7: Change CHAR(n) columns to VARCHAR(n) for Hibernate 6.x compatibility.
-- PostgreSQL bpchar (CHAR) causes schema-validation failures with Hibernate's
-- PostgreSQL dialect. VARCHAR is functionally identical for fixed-length ISO codes.

-- organisation table
ALTER TABLE organisation ALTER COLUMN country_code TYPE VARCHAR(2);
ALTER TABLE organisation ALTER COLUMN base_currency TYPE VARCHAR(3);

-- account table
ALTER TABLE account ALTER COLUMN currency TYPE VARCHAR(3);

-- journal_line table
ALTER TABLE journal_line ALTER COLUMN currency TYPE VARCHAR(3);

-- account_period table (if currency column exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'account_period' AND column_name = 'currency'
  ) THEN
    ALTER TABLE account_period ALTER COLUMN currency TYPE VARCHAR(3);
  END IF;
END $$;

-- exchange_rate table
ALTER TABLE exchange_rate ALTER COLUMN from_currency TYPE VARCHAR(3);
ALTER TABLE exchange_rate ALTER COLUMN to_currency TYPE VARCHAR(3);
