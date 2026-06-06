-- Performance indexes for report queries.
-- These speed up the most common date-range + org_id filter patterns
-- used across all P0 reports (cash flow, registers, stock movement, etc.).

CREATE INDEX IF NOT EXISTS idx_invoice_date_org
    ON invoice(org_id, invoice_date);

CREATE INDEX IF NOT EXISTS idx_purchase_bill_date_org
    ON purchase_bill(org_id, bill_date);

CREATE INDEX IF NOT EXISTS idx_sales_receipt_date_org
    ON sales_receipt(org_id, receipt_date);

CREATE INDEX IF NOT EXISTS idx_stock_movement_date_org
    ON stock_movement(org_id, movement_date);

CREATE INDEX IF NOT EXISTS idx_journal_entry_date_org
    ON journal_entry(org_id, effective_date);

CREATE INDEX IF NOT EXISTS idx_tax_line_source
    ON tax_line_item(source_id, source_type);

CREATE INDEX IF NOT EXISTS idx_tax_line_source_line
    ON tax_line_item(source_line_id, source_type);

CREATE INDEX IF NOT EXISTS idx_payment_contact_date
    ON payment(contact_id, org_id, payment_date);

CREATE INDEX IF NOT EXISTS idx_invoice_contact_date
    ON invoice(contact_id, org_id, invoice_date);
