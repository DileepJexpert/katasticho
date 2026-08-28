-- Migration V59: Partial unique index for offline POS sales receipt sync idempotency
-- Prevents duplicate receipts, double stock deductions, and duplicate journals when offline bills resync concurrently.

CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_receipt_offline_sync
    ON sales_receipt (org_id, offline_receipt_number)
    WHERE offline_receipt_number IS NOT NULL AND is_deleted = false;
