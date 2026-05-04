-- Add GST breakdown columns and GST-invoice flag to sales_receipt.

ALTER TABLE sales_receipt
    ADD COLUMN IF NOT EXISTS cgst     NUMERIC(19,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS sgst     NUMERIC(19,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS igst     NUMERIC(19,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS gst_invoice BOOLEAN     NOT NULL DEFAULT FALSE;

-- Backfill: existing rows have no breakdown — leave CGST/SGST/IGST at 0.
-- tax_amount already holds total tax; gst_invoice defaults to false (simple receipt).
