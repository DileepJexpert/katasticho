-- ============================================================
-- V24: ORG DEFAULT ACCOUNTS
--
-- Per-org mapping from a "purpose" to a Chart-of-Accounts row.
-- Replaces hardcoded GL codes scattered across services
-- (e.g. "5000" for purchases, "2010" for AP).
--
-- Each (org_id, purpose) is unique. Services call
-- DefaultAccountService.get(orgId, purpose) instead of
-- looking up by string code, so users can re-point a purpose
-- at any account from Settings → Accounting → Default Accounts.
-- ============================================================

CREATE TABLE org_default_account (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID         NOT NULL REFERENCES organisation(id),
    purpose         VARCHAR(40)  NOT NULL,   -- AR, AP, CASH, BANK, SALES_REVENUE, ...
    account_id      UUID         NOT NULL REFERENCES account(id),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (org_id, purpose)
);

CREATE INDEX idx_org_default_account_org ON org_default_account(org_id);
