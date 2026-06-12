-- V62: Multi-Currency Support + Consignment/VMI + EDI Integration Connectors
-- Next migration after V61 (MRP Engine)

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 1: MULTI-CURRENCY
-- ══════════════════════════════════════════════════════════════════════════════

-- Platform-level currency catalogue (no org_id — shared across all tenants)
CREATE TABLE IF NOT EXISTS currency (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(3)  NOT NULL UNIQUE,
    name            VARCHAR(50) NOT NULL,
    symbol          VARCHAR(5),
    decimal_places  INT         NOT NULL DEFAULT 2,
    is_active       BOOLEAN     NOT NULL DEFAULT true
);

-- Seed common currencies
INSERT INTO currency (code, name, symbol, decimal_places, is_active) VALUES
    ('INR', 'Indian Rupee',          '₹',  2, true),
    ('USD', 'US Dollar',             '$',  2, true),
    ('EUR', 'Euro',                  '€',  2, true),
    ('GBP', 'British Pound',         '£',  2, true),
    ('AED', 'UAE Dirham',            'د.إ',2, true),
    ('SGD', 'Singapore Dollar',      'S$', 2, true),
    ('JPY', 'Japanese Yen',          '¥',  0, true),
    ('AUD', 'Australian Dollar',     'A$', 2, true),
    ('CAD', 'Canadian Dollar',       'C$', 2, true),
    ('CHF', 'Swiss Franc',           'Fr', 2, true)
ON CONFLICT (code) DO NOTHING;

-- Org-scoped exchange rates
-- V1 shipped a legacy exchange_rate table (no org_id / is_deleted / effective_date).
-- It never matched the ExchangeRate entity and holds no org-scoped data — replace it.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'exchange_rate' AND table_schema = current_schema())
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = 'exchange_rate' AND column_name = 'org_id'
                 AND table_schema = current_schema()) THEN
        DROP TABLE exchange_rate;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS exchange_rate (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID        NOT NULL,
    from_currency   VARCHAR(3)  NOT NULL,
    to_currency     VARCHAR(3)  NOT NULL,
    rate            NUMERIC(15,6) NOT NULL,
    effective_date  DATE        NOT NULL,
    source          VARCHAR(30) NOT NULL DEFAULT 'MANUAL',
    is_deleted      BOOLEAN     NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID,
    UNIQUE (org_id, from_currency, to_currency, effective_date)
);

CREATE INDEX idx_exchange_rate_org_pair_date ON exchange_rate(org_id, from_currency, to_currency, effective_date DESC) WHERE NOT is_deleted;

-- Add currency columns to transactional tables. Guarded per column: some
-- tables (e.g. invoice from V1) already have exchange_rate but not currency_code.
ALTER TABLE sales_order     ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3)    NOT NULL DEFAULT 'INR';
ALTER TABLE sales_order     ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(15,6) NOT NULL DEFAULT 1;
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3)    NOT NULL DEFAULT 'INR';
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(15,6) NOT NULL DEFAULT 1;
ALTER TABLE invoice         ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3)    NOT NULL DEFAULT 'INR';
ALTER TABLE invoice         ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(15,6) NOT NULL DEFAULT 1;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 2: CONSIGNMENT / VMI (Vendor Managed Inventory)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS consignment_stock (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID           NOT NULL,
    item_id             UUID           NOT NULL REFERENCES item(id),
    warehouse_id        UUID           NOT NULL REFERENCES warehouse(id),
    supplier_id         UUID           NOT NULL,
    quantity            NUMERIC(15,4)  NOT NULL DEFAULT 0,
    unit_cost           NUMERIC(15,4)  NOT NULL DEFAULT 0,
    consignment_date    DATE,
    agreement_ref       VARCHAR(50),
    status              VARCHAR(20)    NOT NULL DEFAULT 'ACTIVE',
    settlement_method   VARCHAR(20)    NOT NULL DEFAULT 'ON_SALE',
    notes               TEXT,
    is_deleted          BOOLEAN        NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    created_by          UUID,
    UNIQUE (org_id, item_id, warehouse_id, supplier_id)
);

CREATE INDEX idx_consignment_stock_org         ON consignment_stock(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_consignment_stock_supplier    ON consignment_stock(org_id, supplier_id) WHERE NOT is_deleted;
CREATE INDEX idx_consignment_stock_item        ON consignment_stock(org_id, item_id) WHERE NOT is_deleted;

CREATE TABLE IF NOT EXISTS consignment_settlement (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID           NOT NULL,
    consignment_stock_id    UUID           NOT NULL REFERENCES consignment_stock(id),
    settlement_number       VARCHAR(30),
    quantity_sold           NUMERIC(15,4)  NOT NULL DEFAULT 0,
    unit_cost               NUMERIC(15,4)  NOT NULL DEFAULT 0,
    total_amount            NUMERIC(15,4)  NOT NULL DEFAULT 0,
    settlement_date         DATE,
    status                  VARCHAR(20)    NOT NULL DEFAULT 'DRAFT',
    notes                   TEXT,
    is_deleted              BOOLEAN        NOT NULL DEFAULT false,
    created_at              TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ    NOT NULL DEFAULT now(),
    created_by              UUID
);

CREATE INDEX idx_consignment_settlement_org         ON consignment_settlement(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_consignment_settlement_stock       ON consignment_settlement(consignment_stock_id) WHERE NOT is_deleted;
CREATE INDEX idx_consignment_settlement_status      ON consignment_settlement(org_id, status) WHERE NOT is_deleted;

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 3: EDI / INTEGRATION CONNECTORS
-- ══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS integration_config (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID        NOT NULL,
    integration_type    VARCHAR(30) NOT NULL,   -- TALLY / ZOHO / BUSY / SAP / CUSTOM
    name                VARCHAR(100) NOT NULL,
    base_url            TEXT,
    api_key_hash        TEXT,
    settings            JSONB,
    is_active           BOOLEAN     NOT NULL DEFAULT true,
    last_sync_at        TIMESTAMPTZ,
    is_deleted          BOOLEAN     NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID
);

CREATE INDEX idx_integration_config_org_type ON integration_config(org_id, integration_type) WHERE NOT is_deleted AND is_active;

CREATE TABLE IF NOT EXISTS integration_sync_log (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID        NOT NULL,
    integration_id      UUID        NOT NULL REFERENCES integration_config(id),
    sync_type           VARCHAR(30),
    direction           VARCHAR(10),       -- IMPORT / EXPORT
    status              VARCHAR(20) NOT NULL DEFAULT 'RUNNING',
    records_processed   INT         NOT NULL DEFAULT 0,
    records_failed      INT         NOT NULL DEFAULT 0,
    error_message       TEXT,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,
    is_deleted          BOOLEAN     NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_integration_sync_log_org        ON integration_sync_log(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_integration_sync_log_config     ON integration_sync_log(integration_id, started_at DESC) WHERE NOT is_deleted;
