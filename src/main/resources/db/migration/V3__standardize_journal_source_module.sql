-- Standardise source_module values to match Flutter UI filter tabs.
-- Old: AR (invoices + payments), AP (bills + vendor payments + vendor credits)
-- New: SALES (invoices), PURCHASE (bills + vendor credits), PAYMENT (all payments)

-- Drop the old constraint first
ALTER TABLE journal_entry DROP CONSTRAINT IF EXISTS journal_entry_source_module_check;

-- Disable the immutability trigger so we can rename the column value
-- (this is a system-level rename, not a user edit)
ALTER TABLE journal_entry DISABLE TRIGGER trg_journal_entry_immutable;

-- AR → SALES (invoices, credit notes) or PAYMENT (customer payments)
UPDATE journal_entry SET source_module = 'PAYMENT' WHERE source_module = 'AR' AND description LIKE 'Payment%';
UPDATE journal_entry SET source_module = 'SALES'   WHERE source_module = 'AR' AND description LIKE 'Credit Note%';
UPDATE journal_entry SET source_module = 'SALES'   WHERE source_module = 'AR';

-- AP → PURCHASE (bills, vendor credits) or PAYMENT (vendor payments)
UPDATE journal_entry SET source_module = 'PAYMENT'  WHERE source_module = 'AP' AND description LIKE 'Vendor Payment%';
UPDATE journal_entry SET source_module = 'PURCHASE' WHERE source_module = 'AP' AND description LIKE 'Vendor Credit%';
UPDATE journal_entry SET source_module = 'PURCHASE' WHERE source_module = 'AP';

-- Re-enable the trigger
ALTER TABLE journal_entry ENABLE TRIGGER trg_journal_entry_immutable;

-- Add updated constraint
ALTER TABLE journal_entry
    ADD CONSTRAINT journal_entry_source_module_check
        CHECK (source_module IN (
            'SALES','PURCHASE','PAYMENT','PAYROLL','INVENTORY',
            'MANUAL','GST','BANK_REC','OPENING','POS','EXPENSE'
        ));
