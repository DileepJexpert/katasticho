ALTER TABLE payment
    ADD COLUMN IF NOT EXISTS status VARCHAR(25) NOT NULL DEFAULT 'POSTED',
    ADD COLUMN IF NOT EXISTS posted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS posted_by UUID,
    ADD COLUMN IF NOT EXISTS void_reason TEXT,
    ADD COLUMN IF NOT EXISTS voided_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS voided_by UUID;

UPDATE payment
SET status = 'POSTED'
WHERE status IS NULL;

UPDATE payment
SET posted_at = COALESCE(posted_at, created_at),
    posted_by = COALESCE(posted_by, created_by)
WHERE status = 'POSTED';

ALTER TABLE payment
    DROP CONSTRAINT IF EXISTS payment_status_check;

ALTER TABLE payment
    ADD CONSTRAINT payment_status_check
        CHECK (status IN ('DRAFT','POSTED','PENDING_APPROVAL','VOIDED'));

CREATE INDEX IF NOT EXISTS idx_payment_org_status
    ON payment(org_id, status)
    WHERE is_deleted = false;
