-- P2P workflow integration: link Purchase Bills + GRNs back to their source PO line.
-- All FKs nullable — direct GRNs / direct bills (no PO) still work byte-for-byte.

ALTER TABLE purchase_bill ADD COLUMN purchase_order_id UUID;
ALTER TABLE purchase_bill_line ADD COLUMN purchase_order_line_id UUID;
ALTER TABLE stock_receipt ADD COLUMN purchase_order_id UUID;
ALTER TABLE stock_receipt_line ADD COLUMN purchase_order_line_id UUID;

CREATE INDEX idx_bill_po ON purchase_bill (org_id, purchase_order_id)
    WHERE purchase_order_id IS NOT NULL AND is_deleted = FALSE;

CREATE INDEX idx_bill_line_po_line ON purchase_bill_line (purchase_order_line_id)
    WHERE purchase_order_line_id IS NOT NULL;

CREATE INDEX idx_grn_po ON stock_receipt (org_id, purchase_order_id)
    WHERE purchase_order_id IS NOT NULL AND is_deleted = FALSE;

CREATE INDEX idx_grn_line_po_line ON stock_receipt_line (purchase_order_line_id)
    WHERE purchase_order_line_id IS NOT NULL;
