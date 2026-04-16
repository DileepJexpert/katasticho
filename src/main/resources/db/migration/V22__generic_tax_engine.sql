-- ============================================================
-- V22: GENERIC TAX ENGINE
--
-- Replaces hardcoded India GST logic with database-driven
-- tax configuration. Works for any country: GST, VAT,
-- Sales Tax, SST, PPN, etc.
--
-- Zero code changes to expand to a new country — only seed
-- tax_configuration + tax_rates + tax_groups for that country.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. TAX CONFIGURATION  (one active config per org)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE tax_configuration (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID          NOT NULL REFERENCES organisation(id),
    country_code    VARCHAR(5)    NOT NULL,   -- IN, VN, AE, GB, US, MY, ID
    tax_system      VARCHAR(20)   NOT NULL,   -- GST, VAT, SALES_TAX, SST, PPN
    name            VARCHAR(50)   NOT NULL,   -- "India GST", "UAE VAT", etc.
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_tax_config_org_active
    ON tax_configuration(org_id) WHERE is_active;


-- ─────────────────────────────────────────────────────────────
-- 2. TAX RATE  (individual rates: CGST 9%, VAT 10%, etc.)
--
-- gl_output_account_id: liability account for sales
--   (e.g. 2020 CGST Payable, 2040 VAT Output)
-- gl_input_account_id: asset account for purchases
--   (e.g. 1500 GST Input Credit, 1510 VAT Input)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE tax_rate (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                UUID          NOT NULL REFERENCES organisation(id),
    tax_config_id         UUID          NOT NULL REFERENCES tax_configuration(id),
    name                  VARCHAR(50)   NOT NULL,     -- "CGST 9%", "VAT 10%"
    rate_code             VARCHAR(20)   NOT NULL,     -- "CGST", "SGST", "IGST", "VAT"
    percentage            NUMERIC(5,2)  NOT NULL,     -- 9.00, 10.00
    tax_type              VARCHAR(20)   NOT NULL
                          CHECK (tax_type IN ('OUTPUT','INPUT','BOTH')),
    gl_output_account_id  UUID          REFERENCES account(id),
    gl_input_account_id   UUID          REFERENCES account(id),
    is_recoverable        BOOLEAN       NOT NULL DEFAULT TRUE,
    is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_tax_rate_org     ON tax_rate(org_id) WHERE is_active;
CREATE INDEX idx_tax_rate_config  ON tax_rate(tax_config_id);


-- ─────────────────────────────────────────────────────────────
-- 3. TAX GROUP  (bundles rates: "GST 18%" = CGST 9% + SGST 9%)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE tax_group (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID          NOT NULL REFERENCES organisation(id),
    name            VARCHAR(50)   NOT NULL,    -- "GST 18%", "VAT 10%", "Exempt"
    description     VARCHAR(200),
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_tax_group_org_name
    ON tax_group(org_id, name) WHERE is_active;


-- ─────────────────────────────────────────────────────────────
-- 4. TAX GROUP RATE  (junction: which rates in which group)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE tax_group_rate (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tax_group_id    UUID NOT NULL REFERENCES tax_group(id) ON DELETE CASCADE,
    tax_rate_id     UUID NOT NULL REFERENCES tax_rate(id),
    UNIQUE(tax_group_id, tax_rate_id)
);

CREATE INDEX idx_tax_group_rate_group ON tax_group_rate(tax_group_id);


-- ─────────────────────────────────────────────────────────────
-- 5. ADD tax_group_id TO EXISTING LINE TABLES
--
-- Nullable: existing rows keep NULL (backward compat).
-- New rows should populate this; gst_rate kept for display.
-- ─────────────────────────────────────────────────────────────
ALTER TABLE item              ADD COLUMN default_tax_group_id UUID REFERENCES tax_group(id);
ALTER TABLE invoice_line      ADD COLUMN tax_group_id         UUID REFERENCES tax_group(id);
ALTER TABLE credit_note_line  ADD COLUMN tax_group_id         UUID REFERENCES tax_group(id);
ALTER TABLE purchase_bill_line ADD COLUMN tax_group_id        UUID REFERENCES tax_group(id);
ALTER TABLE vendor_credit_line ADD COLUMN tax_group_id        UUID REFERENCES tax_group(id);
ALTER TABLE expense           ADD COLUMN tax_group_id         UUID REFERENCES tax_group(id);
