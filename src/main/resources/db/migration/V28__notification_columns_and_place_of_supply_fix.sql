-- ============================================================
-- V28: Hotfix — add notification columns + widen place_of_supply
--
-- notification: type, metadata, read_at were added to the entity
--   but not in the original V3 migration that was already applied.
-- place_of_supply: VARCHAR(5) is too short for Indian state names.
-- ============================================================

-- ─── notification: add new columns if missing ───────────────
ALTER TABLE notification
    ADD COLUMN IF NOT EXISTS type VARCHAR(30) NOT NULL DEFAULT 'SYSTEM';

ALTER TABLE notification
    DROP CONSTRAINT IF EXISTS notification_type_check;

ALTER TABLE notification
    ADD CONSTRAINT notification_type_check
    CHECK (type IN ('PAYMENT_REMINDER','EXPIRY_ALERT','LOW_STOCK_ALERT',
                    'DAILY_SUMMARY','BILL_OVERDUE','SYSTEM','INFO','WARNING'));

ALTER TABLE notification
    ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE notification
    ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- ─── place_of_supply: widen to VARCHAR(50) everywhere ───────
ALTER TABLE invoice        ALTER COLUMN place_of_supply TYPE VARCHAR(50);
ALTER TABLE credit_note    ALTER COLUMN place_of_supply TYPE VARCHAR(50);
ALTER TABLE purchase_bill  ALTER COLUMN place_of_supply TYPE VARCHAR(50);
ALTER TABLE vendor_credit  ALTER COLUMN place_of_supply TYPE VARCHAR(50);
