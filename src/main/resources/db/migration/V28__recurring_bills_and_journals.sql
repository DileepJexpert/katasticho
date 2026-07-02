-- V28 — Recurring bills + recurring journals (mirrors the recurring-invoice
-- feature: a template row + a JSONB line payload + a due-date cursor + an
-- audit link table, swept by a ShedLock-guarded daily job).
--
-- Recurring bill    → drafts a PurchaseBill each period (rent, subscriptions,
--                     retainers) — DRAFT by default, auto-post opt-in.
-- Recurring journal → posts a JournalEntry each period (depreciation,
--                     prepaid amortisation, accruals) — DRAFT by default.

CREATE TABLE recurring_bill (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    profile_name VARCHAR(200) NOT NULL,
    contact_id UUID NOT NULL,                       -- vendor
    frequency VARCHAR(20) NOT NULL
        CHECK (frequency IN ('WEEKLY', 'MONTHLY', 'QUARTERLY', 'HALF_YEARLY', 'YEARLY')),
    start_date DATE NOT NULL,
    end_date DATE,
    next_bill_date DATE NOT NULL,
    line_items JSONB NOT NULL DEFAULT '[]',
    payment_terms_days INTEGER NOT NULL DEFAULT 0,
    reverse_charge BOOLEAN NOT NULL DEFAULT false,
    place_of_supply VARCHAR(2),
    auto_post BOOLEAN NOT NULL DEFAULT false,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'PAUSED', 'STOPPED', 'EXPIRED')),
    total_generated INTEGER NOT NULL DEFAULT 0,
    last_generated_at TIMESTAMPTZ,
    notes TEXT,
    terms TEXT,
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
CREATE INDEX idx_recurring_bill_org ON recurring_bill (org_id) WHERE NOT is_deleted;
CREATE INDEX idx_recurring_bill_due ON recurring_bill (status, next_bill_date) WHERE NOT is_deleted;
CREATE INDEX idx_recurring_bill_contact ON recurring_bill (org_id, contact_id) WHERE NOT is_deleted;

CREATE TABLE recurring_bill_generation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recurring_bill_id UUID NOT NULL REFERENCES recurring_bill(id) ON DELETE CASCADE,
    bill_id UUID NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    auto_posted BOOLEAN NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX uq_recurring_bill_gen_bill ON recurring_bill_generation (bill_id);
CREATE INDEX idx_recurring_bill_gen_template ON recurring_bill_generation (recurring_bill_id);

CREATE TABLE recurring_journal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    profile_name VARCHAR(200) NOT NULL,
    frequency VARCHAR(20) NOT NULL
        CHECK (frequency IN ('WEEKLY', 'MONTHLY', 'QUARTERLY', 'HALF_YEARLY', 'YEARLY')),
    start_date DATE NOT NULL,
    end_date DATE,
    next_run_date DATE NOT NULL,
    narration TEXT NOT NULL,
    lines JSONB NOT NULL DEFAULT '[]',
    auto_post BOOLEAN NOT NULL DEFAULT false,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'PAUSED', 'STOPPED', 'EXPIRED')),
    total_generated INTEGER NOT NULL DEFAULT 0,
    last_generated_at TIMESTAMPTZ,
    notes TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
CREATE INDEX idx_recurring_journal_org ON recurring_journal (org_id) WHERE NOT is_deleted;
CREATE INDEX idx_recurring_journal_due ON recurring_journal (status, next_run_date) WHERE NOT is_deleted;

CREATE TABLE recurring_journal_generation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recurring_journal_id UUID NOT NULL REFERENCES recurring_journal(id) ON DELETE CASCADE,
    journal_entry_id UUID NOT NULL,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    auto_posted BOOLEAN NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX uq_recurring_journal_gen_entry ON recurring_journal_generation (journal_entry_id);
CREATE INDEX idx_recurring_journal_gen_template ON recurring_journal_generation (recurring_journal_id);
