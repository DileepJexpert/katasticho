-- ============================================================
-- V1: Base tables for Katasticho ERP
-- Organisation (tenant root) + Exchange Rate (v3-ready)
-- ============================================================

-- Organisation: the root of multi-tenancy.
-- Every other table references org_id back to this table.
CREATE TABLE organisation (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,

    -- Country & Currency (multi-country ready from day 1)
    country_code    CHAR(2) NOT NULL DEFAULT 'IN',           -- ISO 3166-1 alpha-2
    base_currency   CHAR(3) NOT NULL DEFAULT 'INR',          -- ISO 4217
    timezone        VARCHAR(50) NOT NULL DEFAULT 'Asia/Kolkata',
    tax_regime      VARCHAR(30) NOT NULL DEFAULT 'INDIA_GST', -- drives TaxEngine selection
    fiscal_year_start INTEGER NOT NULL DEFAULT 4,             -- month (April for India)

    -- India-specific tax ID (keep separate — has specific 15-char format validation)
    gstin           VARCHAR(15),
    -- Generic tax ID for non-India countries (KRA PIN, FIRS TIN, TRN, etc.)
    tax_id          VARCHAR(50),

    -- India-specific for CGST/SGST determination
    state_code      VARCHAR(5),
    -- Generic sub-national region for state-level taxes
    region_code     VARCHAR(20),

    -- Business details
    industry        VARCHAR(50),
    plan_tier       VARCHAR(20) NOT NULL DEFAULT 'FREE_BETA',
    address_line1   VARCHAR(255),
    address_line2   VARCHAR(255),
    city            VARCHAR(100),
    state           VARCHAR(100),
    postal_code     VARCHAR(20),
    phone           VARCHAR(20),
    email           VARCHAR(255),
    logo_url        VARCHAR(500),

    -- Lifecycle
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID
);

CREATE INDEX idx_org_active ON organisation (is_active) WHERE is_active = TRUE;


-- Exchange Rate: created now, populated in v3 by daily job from Open Exchange Rates API.
-- In v1 this table is empty — SimpleCurrencyService always returns rate 1.0.
CREATE TABLE exchange_rate (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency   CHAR(3) NOT NULL,
    to_currency     CHAR(3) NOT NULL,
    rate            DECIMAL(15,6) NOT NULL,
    rate_date       DATE NOT NULL,
    source          VARCHAR(50) NOT NULL DEFAULT 'MANUAL',    -- 'OPEN_EXCHANGE_RATES' or 'MANUAL'
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_exchange_rate UNIQUE (from_currency, to_currency, rate_date)
);

CREATE INDEX idx_exchange_rate_lookup ON exchange_rate (from_currency, to_currency, rate_date);
