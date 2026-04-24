-- Allow 'EXPENSE' as a journal_entry source_module for expense recordings
ALTER TABLE journal_entry DROP CONSTRAINT IF EXISTS journal_entry_source_module_check;
ALTER TABLE journal_entry ADD CONSTRAINT journal_entry_source_module_check
    CHECK (source_module IN ('AR','AP','PAYROLL','INVENTORY','MANUAL','GST','BANK_REC','OPENING','POS','EXPENSE'));
