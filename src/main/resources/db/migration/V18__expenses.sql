-- ============================================================
-- V18: Expense recording — F7
--
-- Records money spent against an Expense GL account and posts
-- a double-entry journal:
--   DR  Expense GL             amount
--   DR  GST Input Credit       tax_amount   (if gst > 0)
--   CR  Paid-through (Cash/Bank)  total
--
-- One row = one expense transaction (cash, bank, UPI, card).
-- Supports billable expenses that flow to customer invoices.
-- ============================================================

CREATE TABLE expense (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID          NOT NULL REFERENCES organisation(id),

    expense_number      VARCHAR(30)   NOT NULL,          -- EXP-YYYY-NNNNNN
    expense_date        DATE          NOT NULL,

    -- Expense GL account (subType = EXPENSE)
    account_id          UUID          NOT NULL REFERENCES account(id),
    category            VARCHAR(60),                      -- free-text bucket (TRAVEL, MEALS, …)
    description         VARCHAR(500),

    amount              NUMERIC(15,2) NOT NULL,           -- pre-tax
    tax_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
    total               NUMERIC(15,2) NOT NULL,           -- amount + tax_amount
    currency            VARCHAR(3)    NOT NULL DEFAULT 'INR',
    gst_rate            NUMERIC(5,2)  NOT NULL DEFAULT 0, -- 0/5/12/18/28

    -- Vendor (optional). Contact with contactType VENDOR or BOTH.
    contact_id          UUID REFERENCES contact(id),

    -- How it was paid
    payment_mode        VARCHAR(20)   NOT NULL DEFAULT 'CASH'
                        CHECK (payment_mode IN ('CASH','BANK','UPI','CREDIT_CARD')),
    paid_through_id     UUID          NOT NULL REFERENCES account(id),  -- Cash/Bank GL

    -- Billable to customer?
    is_billable         BOOLEAN       NOT NULL DEFAULT FALSE,
    project_id          UUID,                              -- future project module
    customer_contact_id UUID REFERENCES contact(id),       -- customer it's billable to

    receipt_url         VARCHAR(1000),                     -- attachment URL (optional shortcut)

    status              VARCHAR(20)   NOT NULL DEFAULT 'RECORDED'
                        CHECK (status IN ('RECORDED','BILLABLE','INVOICED','VOID')),

    journal_entry_id    UUID REFERENCES journal_entry(id),

    is_deleted          BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by          UUID REFERENCES app_user(id)
);

CREATE UNIQUE INDEX idx_expense_org_number   ON expense(org_id, expense_number)
    WHERE NOT is_deleted;
CREATE INDEX        idx_expense_org_date     ON expense(org_id, expense_date DESC)
    WHERE NOT is_deleted;
CREATE INDEX        idx_expense_org_status   ON expense(org_id, status)
    WHERE NOT is_deleted;
CREATE INDEX        idx_expense_org_contact  ON expense(org_id, contact_id)
    WHERE contact_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX        idx_expense_org_category ON expense(org_id, category)
    WHERE category IS NOT NULL AND NOT is_deleted;
CREATE INDEX        idx_expense_org_billable ON expense(org_id, customer_contact_id)
    WHERE is_billable = TRUE AND NOT is_deleted;
CREATE INDEX        idx_expense_journal      ON expense(journal_entry_id)
    WHERE journal_entry_id IS NOT NULL;
