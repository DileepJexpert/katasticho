-- V24: POS khata (credit) sales — widen the sales_receipt payment-mode CHECK
-- to accept CREDIT. A CREDIT receipt collects nothing at the counter; the
-- total books to Accounts Receivable against the receipt's contact (gated by
-- org setting pos.allow_credit_sales + a mandatory contact, enforced in
-- SalesReceiptService).

ALTER TABLE sales_receipt
    DROP CONSTRAINT IF EXISTS sales_receipt_payment_mode_check;

ALTER TABLE sales_receipt
    ADD CONSTRAINT sales_receipt_payment_mode_check
    CHECK (payment_mode IN ('CASH', 'UPI', 'CARD', 'MIXED', 'CREDIT'));
