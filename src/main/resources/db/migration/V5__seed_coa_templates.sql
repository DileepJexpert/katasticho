-- ============================================================
-- V5: Chart of Accounts templates by industry
-- Stored as a reference table (no org_id). Copied into org's
-- account table on signup via AccountService.seedFromTemplate().
-- ============================================================

CREATE TABLE coa_template (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    industry    VARCHAR(50) NOT NULL,
    code        VARCHAR(20) NOT NULL,
    name        VARCHAR(255) NOT NULL,
    type        VARCHAR(20) NOT NULL,
    sub_type    VARCHAR(50),
    parent_code VARCHAR(20),
    level       INTEGER NOT NULL DEFAULT 1,
    is_system   BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_coa_template UNIQUE (industry, code)
);

-- ===================== TRADING TEMPLATE =====================
-- Assets
INSERT INTO coa_template (industry, code, name, type, sub_type, level) VALUES
('TRADING', '1000', 'Assets', 'ASSET', NULL, 1),
('TRADING', '1010', 'Cash', 'ASSET', 'CURRENT_ASSET', 2),
('TRADING', '1020', 'Bank Account', 'ASSET', 'CURRENT_ASSET', 2),
('TRADING', '1100', 'Accounts Receivable', 'ASSET', 'CURRENT_ASSET', 2),
('TRADING', '1200', 'Inventory', 'ASSET', 'CURRENT_ASSET', 2),
('TRADING', '1300', 'Prepaid Expenses', 'ASSET', 'CURRENT_ASSET', 2),
('TRADING', '1400', 'Advances to Suppliers', 'ASSET', 'CURRENT_ASSET', 2),
('TRADING', '1500', 'GST Input Credit', 'ASSET', 'CURRENT_ASSET', 2),
('TRADING', '1600', 'Fixed Assets', 'ASSET', 'FIXED_ASSET', 2),
('TRADING', '1610', 'Furniture & Fixtures', 'ASSET', 'FIXED_ASSET', 3),
('TRADING', '1620', 'Computer Equipment', 'ASSET', 'FIXED_ASSET', 3),
('TRADING', '1690', 'Accumulated Depreciation', 'ASSET', 'FIXED_ASSET', 2);

-- Assets parent_code links
UPDATE coa_template SET parent_code = '1000' WHERE industry = 'TRADING' AND code IN ('1010','1020','1100','1200','1300','1400','1500','1600','1690');
UPDATE coa_template SET parent_code = '1600' WHERE industry = 'TRADING' AND code IN ('1610','1620');

-- Liabilities
INSERT INTO coa_template (industry, code, name, type, sub_type, level) VALUES
('TRADING', '2000', 'Liabilities', 'LIABILITY', NULL, 1),
('TRADING', '2010', 'Accounts Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2020', 'CGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2021', 'SGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2022', 'IGST Output Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2030', 'TDS Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2040', 'Salary Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2050', 'PF Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2060', 'ESI Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2070', 'Professional Tax Payable', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2100', 'Advance from Customers', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2200', 'Accrued Expenses', 'LIABILITY', 'CURRENT_LIABILITY', 2),
('TRADING', '2500', 'Long-term Loans', 'LIABILITY', 'LONG_TERM_LIABILITY', 2);

UPDATE coa_template SET parent_code = '2000' WHERE industry = 'TRADING' AND code LIKE '2%' AND code != '2000';

-- Equity
INSERT INTO coa_template (industry, code, name, type, sub_type, level) VALUES
('TRADING', '3000', 'Equity', 'EQUITY', NULL, 1),
('TRADING', '3010', 'Owner Capital', 'EQUITY', 'OWNERS_EQUITY', 2),
('TRADING', '3020', 'Retained Earnings', 'EQUITY', 'RETAINED_EARNINGS', 2),
('TRADING', '3030', 'Drawings', 'EQUITY', 'DRAWINGS', 2);

UPDATE coa_template SET parent_code = '3000' WHERE industry = 'TRADING' AND code IN ('3010','3020','3030');

-- Revenue
INSERT INTO coa_template (industry, code, name, type, sub_type, level) VALUES
('TRADING', '4000', 'Revenue', 'REVENUE', NULL, 1),
('TRADING', '4010', 'Sales Revenue', 'REVENUE', 'OPERATING_REVENUE', 2),
('TRADING', '4020', 'Service Revenue', 'REVENUE', 'OPERATING_REVENUE', 2),
('TRADING', '4100', 'Other Income', 'REVENUE', 'OTHER_INCOME', 2),
('TRADING', '4110', 'Interest Income', 'REVENUE', 'OTHER_INCOME', 3),
('TRADING', '4120', 'Discount Received', 'REVENUE', 'OTHER_INCOME', 3);

UPDATE coa_template SET parent_code = '4000' WHERE industry = 'TRADING' AND code IN ('4010','4020','4100');
UPDATE coa_template SET parent_code = '4100' WHERE industry = 'TRADING' AND code IN ('4110','4120');

-- Expenses
INSERT INTO coa_template (industry, code, name, type, sub_type, level) VALUES
('TRADING', '5000', 'Expenses', 'EXPENSE', NULL, 1),
('TRADING', '5010', 'Cost of Goods Sold', 'EXPENSE', 'COGS', 2),
('TRADING', '5020', 'Purchase Expense', 'EXPENSE', 'COGS', 2),
('TRADING', '5100', 'Salary Expense', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5110', 'Employer PF Contribution', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5120', 'Employer ESI Contribution', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5200', 'Rent Expense', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5210', 'Utilities', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5220', 'Office Supplies', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5230', 'Telephone & Internet', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5240', 'Travel & Conveyance', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5250', 'Insurance', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5260', 'Legal & Professional Fees', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5270', 'Depreciation Expense', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5280', 'Bank Charges', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5290', 'Discount Allowed', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5300', 'Miscellaneous Expense', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5400', 'Inventory Loss/Shrinkage', 'EXPENSE', 'OPERATING_EXPENSE', 2),
('TRADING', '5500', 'Forex Gain/Loss', 'EXPENSE', 'OTHER_EXPENSE', 2),
('TRADING', '5600', 'Rounding Adjustment', 'EXPENSE', 'OTHER_EXPENSE', 2);

UPDATE coa_template SET parent_code = '5000' WHERE industry = 'TRADING' AND code LIKE '5%' AND code != '5000';

-- Create aliases for other industries (point to TRADING template for MVP)
-- In production, these would have industry-specific accounts
INSERT INTO coa_template (industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT 'RETAIL', code, name, type, sub_type, parent_code, level, is_system FROM coa_template WHERE industry = 'TRADING';

INSERT INTO coa_template (industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT 'SERVICES', code, name, type, sub_type, parent_code, level, is_system FROM coa_template WHERE industry = 'TRADING';

INSERT INTO coa_template (industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT 'F_AND_B', code, name, type, sub_type, parent_code, level, is_system FROM coa_template WHERE industry = 'TRADING';
