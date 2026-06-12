-- V70: Allow HOSPITAL as a journal source module.
-- The Katixo hospital service posts its billing (DR AR / CR revenue) and
-- patient payments (DR Cash|Bank / CR AR) as journals with
-- source_module = 'HOSPITAL', so a CA can filter hospital entries in reports.
ALTER TABLE journal_entry DROP CONSTRAINT IF EXISTS journal_entry_source_module_check;
ALTER TABLE journal_entry ADD CONSTRAINT journal_entry_source_module_check
    CHECK (source_module IN ('SALES','PURCHASE','PAYMENT','PAYROLL','INVENTORY',
                             'MANUAL','GST','BANK_REC','OPENING','POS','EXPENSE',
                             'MANUFACTURING','HOSPITAL'));
