-- Re-add foreign keys that V1 could not define inline because the
-- referenced tables appear later in the script.

ALTER TABLE item
    ADD CONSTRAINT fk_item_default_tax_group
    FOREIGN KEY (default_tax_group_id) REFERENCES tax_group(id);

ALTER TABLE invoice
    ADD CONSTRAINT fk_invoice_sales_order
    FOREIGN KEY (sales_order_id) REFERENCES sales_order(id);
