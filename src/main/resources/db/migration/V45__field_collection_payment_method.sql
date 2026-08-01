-- Preserve the payment channel used by a field visit so day-close cash
-- reconciliation excludes UPI, card, bank-transfer, and cheque receipts.
ALTER TABLE field_visit
    ADD COLUMN collection_payment_method VARCHAR(30);