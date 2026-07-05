-- V42 — Per-org uniqueness backstop for purchase-order numbers.
--
-- generatePoNumber derived the number from a soft-delete-sensitive
-- countByOrgIdAndIsDeletedFalse (deleting a PO shifted the count → a duplicate
-- number on the next create, with no constraint to catch it). The service is
-- switched to the shared monotonic InvoiceNumberSequence generator (prefix 'PO',
-- PESSIMISTIC_WRITE per org/prefix/year). This partial unique index is the
-- backstop so any residual duplicate fails loudly instead of persisting —
-- matching the V21 pattern for network_order / job_work_order / NCR.

CREATE UNIQUE INDEX uq_purchase_order_org_number
    ON purchase_orders (org_id, po_number)
    WHERE NOT is_deleted;
