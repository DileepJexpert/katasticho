-- Standardise source_module values to match Flutter UI filter tabs.
-- Old: AR (invoices + payments), AP (bills + vendor payments + vendor credits)
-- New: SALES (invoices), PURCHASE (bills + vendor credits), PAYMENT (all payments)

-- Drop the old constraint, migrate data, add new constraint
ALTER TABLE journal_entry DROP CONSTRAINT IF EXISTS journal_entry_source_module_check;

-- Invoices posted as 'AR' → 'SALES'
UPDATE journal_entry
SET source_module = 'SALES'
WHERE source_module = 'AR'
  AND description LIKE 'Invoice%';

-- Credit notes posted as 'AR' → 'SALES'
UPDATE journal_entry
SET source_module = 'SALES'
WHERE source_module = 'AR'
  AND description LIKE 'Credit Note%';

-- Customer payments posted as 'AR' → 'PAYMENT'
UPDATE journal_entry
SET source_module = 'PAYMENT'
WHERE source_module = 'AR'
  AND description LIKE 'Payment%';

-- Any remaining 'AR' rows → 'SALES'
UPDATE journal_entry SET source_module = 'SALES' WHERE source_module = 'AR';

-- Bills posted as 'AP' → 'PURCHASE'
UPDATE journal_entry
SET source_module = 'PURCHASE'
WHERE source_module = 'AP'
  AND description LIKE 'Purchase Bill%';

-- Vendor credits posted as 'AP' → 'PURCHASE'
UPDATE journal_entry
SET source_module = 'PURCHASE'
WHERE source_module = 'AP'
  AND description LIKE 'Vendor Credit%';

-- Vendor payments posted as 'AP' → 'PAYMENT'
UPDATE journal_entry
SET source_module = 'PAYMENT'
WHERE source_module = 'AP'
  AND description LIKE 'Vendor Payment%';

-- Any remaining 'AP' rows → 'PURCHASE'
UPDATE journal_entry SET source_module = 'PURCHASE' WHERE source_module = 'AP';

-- Add updated constraint
ALTER TABLE journal_entry
    ADD CONSTRAINT journal_entry_source_module_check
        CHECK (source_module IN (
            'SALES','PURCHASE','PAYMENT','PAYROLL','INVENTORY',
            'MANUAL','GST','BANK_REC','OPENING','POS','EXPENSE'
        ));
