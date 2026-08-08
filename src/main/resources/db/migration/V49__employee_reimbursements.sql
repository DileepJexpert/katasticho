-- Employee reimbursement workflow: claim -> approval -> settlement -> payment.
-- Claims do not post accounting entries until approved.

ALTER TABLE expense ADD COLUMN IF NOT EXISTS employee_id uuid;
ALTER TABLE field_allowance_claim ADD COLUMN IF NOT EXISTS reimbursement_id uuid;
CREATE INDEX IF NOT EXISTS idx_field_allowance_reimbursement
    ON field_allowance_claim (org_id, reimbursement_id)
    WHERE reimbursement_id IS NOT NULL;

ALTER TABLE expense DROP CONSTRAINT IF EXISTS expense_payment_mode_check;
ALTER TABLE expense ADD CONSTRAINT expense_payment_mode_check CHECK (
    payment_mode IN ('CASH', 'BANK', 'UPI', 'CREDIT_CARD', 'EMPLOYEE_PAYABLE')
);

CREATE INDEX IF NOT EXISTS idx_expense_org_employee
    ON expense (org_id, employee_id, expense_date DESC)
    WHERE is_deleted = false;

CREATE TABLE IF NOT EXISTS employee_expense_reimbursement (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    expense_id uuid,
    expense_date date NOT NULL,
    account_id uuid NOT NULL,
    category varchar(80),
    description varchar(500) NOT NULL,
    amount numeric(15,2) NOT NULL,
    status varchar(20) DEFAULT 'SUBMITTED' NOT NULL,
    advance_applied numeric(15,2) DEFAULT 0 NOT NULL,
    payable_amount numeric(15,2) DEFAULT 0 NOT NULL,
    receipt_url varchar(1000),
    notes varchar(1000),
    approved_by uuid,
    approved_at timestamptz,
    rejected_by uuid,
    rejected_at timestamptz,
    rejection_reason varchar(1000),
    paid_through_id uuid,
    paid_amount numeric(15,2) DEFAULT 0 NOT NULL,
    paid_at timestamptz,
    payment_journal_entry_id uuid,
    settlement_journal_entry_id uuid,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT employee_reimbursement_status_check CHECK
        (status IN ('SUBMITTED', 'APPROVED', 'REJECTED', 'PAID', 'CANCELLED')),
    CONSTRAINT employee_reimbursement_amount_check CHECK (amount > 0),
    CONSTRAINT employee_reimbursement_advance_check CHECK
        (advance_applied >= 0 AND advance_applied <= amount),
    CONSTRAINT employee_reimbursement_payable_check CHECK (payable_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_employee_reimbursement_org_status
    ON employee_expense_reimbursement (org_id, status, expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_employee_reimbursement_org_employee
    ON employee_expense_reimbursement (org_id, employee_id, expense_date DESC);

CREATE TABLE IF NOT EXISTS employee_expense_advance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    advance_date date NOT NULL,
    amount numeric(15,2) NOT NULL,
    settled_amount numeric(15,2) DEFAULT 0 NOT NULL,
    status varchar(20) DEFAULT 'OPEN' NOT NULL,
    paid_through_id uuid NOT NULL,
    journal_entry_id uuid NOT NULL,
    notes varchar(1000),
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT employee_advance_status_check CHECK (status IN ('OPEN', 'SETTLED', 'VOID')),
    CONSTRAINT employee_advance_amount_check CHECK (amount > 0),
    CONSTRAINT employee_advance_settled_check CHECK (settled_amount >= 0 AND settled_amount <= amount)
);

CREATE INDEX IF NOT EXISTS idx_employee_advance_open_fifo
    ON employee_expense_advance (org_id, employee_id, advance_date, created_at)
    WHERE status = 'OPEN' AND is_deleted = false;

CREATE TABLE IF NOT EXISTS employee_reimbursement_advance_allocation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    reimbursement_id uuid NOT NULL,
    advance_id uuid NOT NULL,
    amount numeric(15,2) NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT reimbursement_advance_allocation_amount_check CHECK (amount > 0),
    CONSTRAINT uq_reimbursement_advance_allocation UNIQUE (reimbursement_id, advance_id)
);

-- These template rows make the accounts available to every new organisation.
-- Existing organisations are repaired lazily by the reimbursement service so
-- rollout does not depend on recreating their chart of accounts.
INSERT INTO coa_template (industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT t.industry, '1310', 'Employee Advances', 'ASSET', 'CURRENT_ASSET', '1000', 2, false
FROM (SELECT DISTINCT industry FROM coa_template) t
WHERE NOT EXISTS (SELECT 1 FROM coa_template c WHERE c.industry = t.industry AND c.code = '1310');

INSERT INTO coa_template (industry, code, name, type, sub_type, parent_code, level, is_system)
SELECT t.industry, '2080', 'Employee Reimbursement Payable', 'LIABILITY', 'CURRENT_LIABILITY', '2000', 2, false
FROM (SELECT DISTINCT industry FROM coa_template) t
WHERE NOT EXISTS (SELECT 1 FROM coa_template c WHERE c.industry = t.industry AND c.code = '2080');


