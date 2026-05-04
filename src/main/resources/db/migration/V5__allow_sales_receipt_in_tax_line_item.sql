-- Allow SALES_RECEIPT as a source_type in tax_line_item.

ALTER TABLE tax_line_item
    DROP CONSTRAINT IF EXISTS tax_line_item_source_type_check;

ALTER TABLE tax_line_item
    ADD CONSTRAINT tax_line_item_source_type_check
        CHECK (source_type IN ('INVOICE','CREDIT_NOTE','BILL','EXPENSE','VENDOR_CREDIT','SALES_RECEIPT'));
