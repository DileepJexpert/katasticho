-- V36 — Widen sales_order and credit_note status CHECK constraints to include the
-- approval-workflow states the services already write.
--
-- Unlike source_module (V34) / stock_movement type (V35) — free-form labels dropped
-- entirely — these two columns ARE bounded state machines, so we keep the CHECK but
-- add the two missing states. Both services write 'PENDING_APPROVAL' / 'REJECTED'
-- (SalesOrderWorkflowHandler, CreditNoteWorkflowHandler + CreditNoteService.issueCreditNote)
-- as soon as an approval workflow is activated for the org, but the V1 baseline CHECKs
-- omit them, so the first status write throws a CHECK violation (a 500). The seeded
-- SALES_ORDER / CREDIT_NOTE_RETURN_APPROVAL workflows are inactive by default, which is
-- why this never surfaced until an org enabled approvals — and the mocked service tests
-- never exercised the real constraint.

ALTER TABLE sales_order DROP CONSTRAINT IF EXISTS sales_order_status_check;
ALTER TABLE sales_order ADD CONSTRAINT sales_order_status_check CHECK (
    status IN ('DRAFT','PENDING_APPROVAL','CONFIRMED','REJECTED','BACKORDER',
               'PARTIALLY_SHIPPED','SHIPPED','PARTIALLY_INVOICED','INVOICED',
               'COMPLETED','CANCELLED','VOID'));

ALTER TABLE credit_note DROP CONSTRAINT IF EXISTS credit_note_status_check;
ALTER TABLE credit_note ADD CONSTRAINT credit_note_status_check CHECK (
    status IN ('DRAFT','PENDING_APPROVAL','ISSUED','APPLIED','REJECTED','CANCELLED'));
