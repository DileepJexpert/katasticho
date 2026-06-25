-- POS sales-receipt return / void.
-- A POS receipt is created COMPLETED (Cash/Revenue journal + SALE stock
-- movements). A "return" reverses the journal (un-books the sale) and restocks
-- every SALE movement, then flips the row to RETURNED. Existing rows backfill to
-- COMPLETED so the field is non-null from the first boot after this migration.
ALTER TABLE sales_receipt
    ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    ADD COLUMN reversal_journal_entry_id UUID,
    ADD COLUMN returned_at TIMESTAMPTZ,
    ADD COLUMN return_reason VARCHAR(255),
    ADD COLUMN returned_by UUID;

ALTER TABLE sales_receipt
    ADD CONSTRAINT sales_receipt_status_chk
        CHECK (status IN ('COMPLETED', 'RETURNED'));

-- Dashboard / register filters that want to exclude voided sales.
CREATE INDEX idx_sales_receipt_status
    ON sales_receipt (org_id, status)
    WHERE is_deleted = FALSE;
