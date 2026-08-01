-- Field collection accounting link and subcontracting output support.
-- Collections are posted as customer receipts and linked to the visit so an
-- offline retry cannot create a second receipt for the same visit.

ALTER TABLE field_visit
    ADD COLUMN customer_receipt_id UUID;

ALTER TABLE field_visit
    ADD CONSTRAINT field_visit_customer_receipt_fk
    FOREIGN KEY (customer_receipt_id) REFERENCES customer_receipt(id);

CREATE UNIQUE INDEX field_visit_customer_receipt_uq
    ON field_visit (customer_receipt_id)
    WHERE customer_receipt_id IS NOT NULL;

-- job_work_order_line already has line_type. OUTPUT rows are used for the
-- finished goods received from the subcontractor; MATERIAL rows remain the
-- raw materials sent out.
CREATE INDEX job_work_order_line_output_item_idx
    ON job_work_order_line (job_work_order_id, item_id, line_type)
    WHERE is_deleted = FALSE;