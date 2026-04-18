-- ============================================================
-- V1: Katasticho ERP — complete initial schema
-- Consolidates original V1-V17 into one clean baseline.
-- All CHAR(n) replaced with VARCHAR(n) (Hibernate 6 compat).
-- Tables defined in dependency order; no ALTER statements.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. ORGANISATION (tenant root)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE organisation (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(255) NOT NULL,
    country_code        VARCHAR(2)   NOT NULL DEFAULT 'IN',
    base_currency       VARCHAR(3)   NOT NULL DEFAULT 'INR',
    timezone            VARCHAR(50)  NOT NULL DEFAULT 'Asia/Kolkata',
    tax_regime          VARCHAR(30)  NOT NULL DEFAULT 'INDIA_GST',
    fiscal_year_start   INTEGER      NOT NULL DEFAULT 4,
    gstin               VARCHAR(15),
    tax_id              VARCHAR(50),
    state_code          VARCHAR(5),
    region_code         VARCHAR(20),
    industry            VARCHAR(50),
    plan_tier           VARCHAR(20)  NOT NULL DEFAULT 'FREE_BETA',
    address_line1       VARCHAR(255),
    address_line2       VARCHAR(255),
    city                VARCHAR(100),
    state               VARCHAR(100),
    postal_code         VARCHAR(20),
    phone               VARCHAR(20),
    email               VARCHAR(255),
    logo_url            VARCHAR(500),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by          UUID
);

CREATE INDEX idx_org_active ON organisation(is_active) WHERE is_active = TRUE;


-- ─────────────────────────────────────────────────────────────
-- 2. EXCHANGE RATE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE exchange_rate (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency   VARCHAR(3)      NOT NULL,
    to_currency     VARCHAR(3)      NOT NULL,
    rate            DECIMAL(15,6)   NOT NULL,
    rate_date       DATE            NOT NULL,
    source          VARCHAR(50)     NOT NULL DEFAULT 'MANUAL',
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_exchange_rate UNIQUE (from_currency, to_currency, rate_date)
);

CREATE INDEX idx_exchange_rate_lookup ON exchange_rate(from_currency, to_currency, rate_date);


-- ─────────────────────────────────────────────────────────────
-- 3. BRANCH  (org location / division — every warehouse, user,
--            invoice, payment, etc. is scoped to a branch)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE branch (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID         NOT NULL REFERENCES organisation(id),
    code            VARCHAR(20)  NOT NULL,
    name            VARCHAR(255) NOT NULL,
    address_line1   VARCHAR(255),
    address_line2   VARCHAR(255),
    city            VARCHAR(100),
    state           VARCHAR(100),
    state_code      VARCHAR(5),
    postal_code     VARCHAR(20),
    country         VARCHAR(2)   DEFAULT 'IN',
    gstin           VARCHAR(15),
    is_default      BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_branch_org_code    ON branch(org_id, code)  WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_branch_org_default ON branch(org_id)        WHERE is_default AND NOT is_deleted;
CREATE INDEX        idx_branch_org         ON branch(org_id)        WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 4. APP USER
-- ─────────────────────────────────────────────────────────────
CREATE TABLE app_user (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID        NOT NULL REFERENCES organisation(id),
    branch_id           UUID        REFERENCES branch(id),
    email               VARCHAR(255),
    phone               VARCHAR(20),
    password_hash       VARCHAR(255),
    full_name           VARCHAR(255) NOT NULL,
    role                VARCHAR(20)  NOT NULL DEFAULT 'VIEWER'
                        CHECK (role IN ('OWNER','ACCOUNTANT','OPERATOR','VIEWER')),
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    failed_login_count  INTEGER      NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    last_login_at       TIMESTAMPTZ,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by          UUID,
    is_deleted          BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_user_email_org  UNIQUE (org_id, email),
    CONSTRAINT uq_user_phone_org  UNIQUE (org_id, phone),
    CONSTRAINT chk_user_has_login CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX idx_user_org   ON app_user(org_id)  WHERE is_deleted = FALSE;
CREATE INDEX idx_user_email ON app_user(email)   WHERE email IS NOT NULL AND is_deleted = FALSE;
CREATE INDEX idx_user_phone ON app_user(phone)   WHERE phone IS NOT NULL AND is_deleted = FALSE;


-- ─────────────────────────────────────────────────────────────
-- 4. REFRESH TOKEN
-- ─────────────────────────────────────────────────────────────
CREATE TABLE refresh_token (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES app_user(id),
    token_hash  VARCHAR(255) NOT NULL UNIQUE,
    device_info VARCHAR(255),
    ip_address  VARCHAR(45),
    expires_at  TIMESTAMPTZ  NOT NULL,
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_token_user ON refresh_token(user_id);
CREATE INDEX idx_refresh_token_hash ON refresh_token(token_hash) WHERE revoked_at IS NULL;


-- ─────────────────────────────────────────────────────────────
-- 5. USER INVITATION
-- ─────────────────────────────────────────────────────────────
CREATE TABLE user_invitation (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID        NOT NULL REFERENCES organisation(id),
    email       VARCHAR(255),
    phone       VARCHAR(20),
    role        VARCHAR(20)  NOT NULL DEFAULT 'VIEWER'
                CHECK (role IN ('OWNER','ACCOUNTANT','OPERATOR','VIEWER')),
    token       VARCHAR(255) NOT NULL UNIQUE,
    invited_by  UUID        NOT NULL REFERENCES app_user(id),
    expires_at  TIMESTAMPTZ  NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_invite_has_contact CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX idx_invitation_token ON user_invitation(token) WHERE accepted_at IS NULL;
CREATE INDEX idx_invitation_org   ON user_invitation(org_id);


-- ─────────────────────────────────────────────────────────────
-- 6. AUDIT LOG  (no CHECK on action — values grow over time)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE audit_log (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID        NOT NULL,
    user_id     UUID,
    entity_type VARCHAR(50)  NOT NULL,
    entity_id   UUID,
    action      VARCHAR(20)  NOT NULL,
    before_json JSONB,
    after_json  JSONB,
    ip_address  VARCHAR(45),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_org_entity ON audit_log(org_id, entity_type, created_at DESC);
CREATE INDEX idx_audit_org_user   ON audit_log(org_id, user_id,      created_at DESC);


-- ─────────────────────────────────────────────────────────────
-- 7. CHART OF ACCOUNTS
-- ─────────────────────────────────────────────────────────────
CREATE TABLE account (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID        NOT NULL REFERENCES organisation(id),
    code            VARCHAR(20)  NOT NULL,
    name            VARCHAR(255) NOT NULL,
    type            VARCHAR(20)  NOT NULL
                    CHECK (type IN ('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE')),
    sub_type        VARCHAR(50),
    parent_id       UUID REFERENCES account(id),
    level           INTEGER      NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 5),
    is_system       BOOLEAN      NOT NULL DEFAULT FALSE,
    description     VARCHAR(500),
    opening_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    currency        VARCHAR(3)    NOT NULL DEFAULT 'INR',
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    created_by      UUID,
    is_deleted      BOOLEAN       NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_account_code_org UNIQUE (org_id, code)
);

CREATE INDEX idx_account_org      ON account(org_id)       WHERE is_deleted = FALSE;
CREATE INDEX idx_account_org_type ON account(org_id, type) WHERE is_deleted = FALSE;
CREATE INDEX idx_account_parent   ON account(parent_id)    WHERE parent_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 8. JOURNAL ENTRY  (immutable once posted)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE journal_entry (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID        NOT NULL REFERENCES organisation(id),
    entry_number    VARCHAR(30)  NOT NULL,
    effective_date  DATE         NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    description     VARCHAR(500),
    source_module   VARCHAR(30)  NOT NULL
                    CHECK (source_module IN (
                        'AR','AP','PAYROLL','INVENTORY','MANUAL','GST','BANK_REC','OPENING'
                    )),
    source_id       UUID,
    status          VARCHAR(10)  NOT NULL DEFAULT 'DRAFT'
                    CHECK (status IN ('DRAFT','POSTED')),
    reversal_of_id  UUID REFERENCES journal_entry(id),
    is_reversal     BOOLEAN      NOT NULL DEFAULT FALSE,
    is_reversed     BOOLEAN      NOT NULL DEFAULT FALSE,
    approval_status VARCHAR(15)  NOT NULL DEFAULT 'NONE'
                    CHECK (approval_status IN ('NONE','PENDING','APPROVED','REJECTED')),
    approved_by     UUID,
    approved_at     TIMESTAMPTZ,
    period_year     INTEGER      NOT NULL,
    period_month    INTEGER      NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    created_by      UUID         NOT NULL,
    tags            JSONB        DEFAULT '{}',
    CONSTRAINT uq_journal_entry_number UNIQUE (org_id, entry_number)
);

CREATE INDEX idx_je_org_date   ON journal_entry(org_id, effective_date);
CREATE INDEX idx_je_org_status ON journal_entry(org_id, status);
CREATE INDEX idx_je_org_period ON journal_entry(org_id, period_year, period_month);
CREATE INDEX idx_je_source     ON journal_entry(org_id, source_module, source_id);
CREATE INDEX idx_je_reversal   ON journal_entry(reversal_of_id) WHERE reversal_of_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 9. JOURNAL LINE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE journal_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_entry_id    UUID          NOT NULL REFERENCES journal_entry(id) ON DELETE RESTRICT,
    account_id          UUID          NOT NULL REFERENCES account(id),
    description         VARCHAR(500),
    currency            VARCHAR(3)    NOT NULL DEFAULT 'INR',
    debit               DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (debit  >= 0),
    credit              DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    exchange_rate       DECIMAL(15,6) NOT NULL DEFAULT 1.000000,
    base_debit          DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (base_debit  >= 0),
    base_credit         DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (base_credit >= 0),
    tax_component_code  VARCHAR(20),
    cost_centre         VARCHAR(50),
    project_id          UUID,
    CONSTRAINT chk_line_debit_or_credit CHECK (
        (debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0) OR (debit = 0 AND credit = 0)
    )
);

CREATE INDEX idx_jl_entry        ON journal_line(journal_entry_id);
CREATE INDEX idx_jl_account      ON journal_line(account_id);
CREATE INDEX idx_jl_account_entry ON journal_line(account_id, journal_entry_id);


-- ─────────────────────────────────────────────────────────────
-- 10. PERIOD BALANCE  (cached snapshot — not source of truth)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE period_balance (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID          NOT NULL,
    account_id          UUID          NOT NULL REFERENCES account(id),
    period_year         INTEGER       NOT NULL,
    period_month        INTEGER       NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    opening_balance     DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_debit         DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_credit        DECIMAL(15,2) NOT NULL DEFAULT 0,
    closing_balance     DECIMAL(15,2) NOT NULL DEFAULT 0,
    transaction_count   INTEGER       NOT NULL DEFAULT 0,
    currency            VARCHAR(3)    NOT NULL DEFAULT 'INR',
    frozen_at           TIMESTAMPTZ,
    CONSTRAINT uq_period_balance UNIQUE (org_id, account_id, period_year, period_month)
);

CREATE INDEX idx_pb_org_period ON period_balance(org_id, account_id, period_year, period_month);


-- ─────────────────────────────────────────────────────────────
-- 11. ENTRY NUMBER SEQUENCE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE entry_number_sequence (
    org_id      UUID    NOT NULL REFERENCES organisation(id),
    year        INTEGER NOT NULL,
    next_value  BIGINT  NOT NULL DEFAULT 1,
    PRIMARY KEY (org_id, year)
);

-- ─────────────────────────────────────────────────────────────
-- 12. COA TEMPLATE  (reference data, no org_id)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE coa_template (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    industry    VARCHAR(50)  NOT NULL,
    code        VARCHAR(20)  NOT NULL,
    name        VARCHAR(255) NOT NULL,
    type        VARCHAR(20)  NOT NULL,
    sub_type    VARCHAR(50),
    parent_code VARCHAR(20),
    level       INTEGER      NOT NULL DEFAULT 1,
    is_system   BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_coa_template UNIQUE (industry, code)
);

-- TRADING template
INSERT INTO coa_template (industry,code,name,type,sub_type,level) VALUES
('TRADING','1000','Assets','ASSET',NULL,1),
('TRADING','1010','Cash','ASSET','CURRENT_ASSET',2),
('TRADING','1020','Bank Account','ASSET','CURRENT_ASSET',2),
('TRADING','1100','Accounts Receivable','ASSET','CURRENT_ASSET',2),
('TRADING','1200','Inventory','ASSET','CURRENT_ASSET',2),
('TRADING','1300','Prepaid Expenses','ASSET','CURRENT_ASSET',2),
('TRADING','1400','Advances to Suppliers','ASSET','CURRENT_ASSET',2),
('TRADING','1500','GST Input Credit','ASSET','CURRENT_ASSET',2),
('TRADING','1600','Fixed Assets','ASSET','FIXED_ASSET',2),
('TRADING','1610','Furniture & Fixtures','ASSET','FIXED_ASSET',3),
('TRADING','1620','Computer Equipment','ASSET','FIXED_ASSET',3),
('TRADING','1690','Accumulated Depreciation','ASSET','FIXED_ASSET',2);
UPDATE coa_template SET parent_code='1000' WHERE industry='TRADING' AND code IN ('1010','1020','1100','1200','1300','1400','1500','1600','1690');
UPDATE coa_template SET parent_code='1600' WHERE industry='TRADING' AND code IN ('1610','1620');

INSERT INTO coa_template (industry,code,name,type,sub_type,level) VALUES
('TRADING','2000','Liabilities','LIABILITY',NULL,1),
('TRADING','2010','Accounts Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2020','CGST Output Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2021','SGST Output Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2022','IGST Output Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2030','TDS Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2040','Salary Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2050','PF Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2060','ESI Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2070','Professional Tax Payable','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2100','Advance from Customers','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2200','Accrued Expenses','LIABILITY','CURRENT_LIABILITY',2),
('TRADING','2500','Long-term Loans','LIABILITY','LONG_TERM_LIABILITY',2);
UPDATE coa_template SET parent_code='2000' WHERE industry='TRADING' AND code LIKE '2%' AND code!='2000';

INSERT INTO coa_template (industry,code,name,type,sub_type,level) VALUES
('TRADING','3000','Equity','EQUITY',NULL,1),
('TRADING','3010','Owner Capital','EQUITY','OWNERS_EQUITY',2),
('TRADING','3020','Retained Earnings','EQUITY','RETAINED_EARNINGS',2),
('TRADING','3030','Drawings','EQUITY','DRAWINGS',2);
UPDATE coa_template SET parent_code='3000' WHERE industry='TRADING' AND code IN ('3010','3020','3030');

INSERT INTO coa_template (industry,code,name,type,sub_type,level) VALUES
('TRADING','4000','Revenue','REVENUE',NULL,1),
('TRADING','4010','Sales Revenue','REVENUE','OPERATING_REVENUE',2),
('TRADING','4020','Service Revenue','REVENUE','OPERATING_REVENUE',2),
('TRADING','4100','Other Income','REVENUE','OTHER_INCOME',2),
('TRADING','4110','Interest Income','REVENUE','OTHER_INCOME',3),
('TRADING','4120','Discount Received','REVENUE','OTHER_INCOME',3);
UPDATE coa_template SET parent_code='4000' WHERE industry='TRADING' AND code IN ('4010','4020','4100');
UPDATE coa_template SET parent_code='4100' WHERE industry='TRADING' AND code IN ('4110','4120');

INSERT INTO coa_template (industry,code,name,type,sub_type,level) VALUES
('TRADING','5000','Expenses','EXPENSE',NULL,1),
('TRADING','5010','Cost of Goods Sold','EXPENSE','COGS',2),
('TRADING','5020','Purchase Expense','EXPENSE','COGS',2),
('TRADING','5100','Salary Expense','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5110','Employer PF Contribution','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5120','Employer ESI Contribution','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5200','Rent Expense','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5210','Utilities','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5220','Office Supplies','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5230','Telephone & Internet','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5240','Travel & Conveyance','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5250','Insurance','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5260','Legal & Professional Fees','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5270','Depreciation Expense','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5280','Bank Charges','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5290','Discount Allowed','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5300','Miscellaneous Expense','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5400','Inventory Loss/Shrinkage','EXPENSE','OPERATING_EXPENSE',2),
('TRADING','5500','Forex Gain/Loss','EXPENSE','OTHER_EXPENSE',2),
('TRADING','5600','Rounding Adjustment','EXPENSE','OTHER_EXPENSE',2);
UPDATE coa_template SET parent_code='5000' WHERE industry='TRADING' AND code LIKE '5%' AND code!='5000';

-- Clone TRADING template for RETAIL, SERVICES, F_AND_B
INSERT INTO coa_template (industry,code,name,type,sub_type,parent_code,level,is_system)
SELECT 'RETAIL',code,name,type,sub_type,parent_code,level,is_system FROM coa_template WHERE industry='TRADING';
INSERT INTO coa_template (industry,code,name,type,sub_type,parent_code,level,is_system)
SELECT 'SERVICES',code,name,type,sub_type,parent_code,level,is_system FROM coa_template WHERE industry='TRADING';
INSERT INTO coa_template (industry,code,name,type,sub_type,parent_code,level,is_system)
SELECT 'F_AND_B',code,name,type,sub_type,parent_code,level,is_system FROM coa_template WHERE industry='TRADING';


-- ─────────────────────────────────────────────────────────────
-- 13. WAREHOUSE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE warehouse (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID         NOT NULL REFERENCES organisation(id),
    branch_id       UUID         REFERENCES branch(id),
    code            VARCHAR(20)  NOT NULL,
    name            VARCHAR(255) NOT NULL,
    address_line1   VARCHAR(255),
    address_line2   VARCHAR(255),
    city            VARCHAR(100),
    state           VARCHAR(100),
    state_code      VARCHAR(5),
    postal_code     VARCHAR(20),
    country         VARCHAR(2)   DEFAULT 'IN',
    is_default      BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_warehouse_org_code    ON warehouse(org_id, code)    WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_warehouse_org_default ON warehouse(org_id)          WHERE is_default AND NOT is_deleted;
CREATE INDEX        idx_warehouse_org         ON warehouse(org_id)          WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 14. UNIT OF MEASURE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE uom (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID        NOT NULL REFERENCES organisation(id),
    name         VARCHAR(50) NOT NULL,
    abbreviation VARCHAR(20) NOT NULL,
    category     VARCHAR(20) NOT NULL
                 CHECK (category IN ('WEIGHT','VOLUME','COUNT','LENGTH','PACKAGING')),
    is_base      BOOLEAN     NOT NULL DEFAULT FALSE,
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
    is_deleted   BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by   UUID
);

CREATE UNIQUE INDEX idx_uom_org_abbr     ON uom(org_id, abbreviation) WHERE NOT is_deleted;
CREATE INDEX        idx_uom_org_category ON uom(org_id, category)     WHERE NOT is_deleted;
CREATE INDEX        idx_uom_org_active   ON uom(org_id, is_active)    WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 15. ITEM GROUP  (variant template)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE item_group (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID         NOT NULL REFERENCES organisation(id),
    name                    VARCHAR(255) NOT NULL,
    description             TEXT,
    sku_prefix              VARCHAR(50),
    hsn_code                VARCHAR(10),
    gst_rate                NUMERIC(5,2),
    default_uom             VARCHAR(20),
    default_purchase_price  NUMERIC(15,4),
    default_sale_price      NUMERIC(15,4),
    attribute_definitions   JSONB        NOT NULL DEFAULT '[]'::jsonb,
    is_deleted              BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by              UUID,
    CONSTRAINT chk_item_group_attr_defs_array
        CHECK (jsonb_typeof(attribute_definitions) = 'array')
);

CREATE UNIQUE INDEX idx_item_group_org_name ON item_group(org_id, lower(name)) WHERE NOT is_deleted;
CREATE INDEX        idx_item_group_org      ON item_group(org_id)               WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 16. ITEM  (final state: includes base_uom_id, track_batches,
--            group_id, variant_attributes from V13/V14/V17)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE item (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID         NOT NULL REFERENCES organisation(id),
    sku                     VARCHAR(50)  NOT NULL,
    name                    VARCHAR(255) NOT NULL,
    description             TEXT,
    item_type               VARCHAR(20)  NOT NULL DEFAULT 'GOODS'
                            CHECK (item_type IN ('GOODS','SERVICE','COMPOSITE')),
    category                VARCHAR(100),
    brand                   VARCHAR(100),
    hsn_code                VARCHAR(10),
    unit_of_measure         VARCHAR(20)  NOT NULL DEFAULT 'PCS',
    base_uom_id             UUID REFERENCES uom(id),
    purchase_price          NUMERIC(15,2) NOT NULL DEFAULT 0,
    sale_price              NUMERIC(15,2) NOT NULL DEFAULT 0,
    mrp                     NUMERIC(15,2),
    gst_rate                NUMERIC(5,2)  NOT NULL DEFAULT 0,
    track_inventory         BOOLEAN       NOT NULL DEFAULT TRUE,
    track_batches           BOOLEAN       NOT NULL DEFAULT FALSE,
    reorder_level           NUMERIC(12,4) NOT NULL DEFAULT 0,
    reorder_quantity        NUMERIC(12,4) NOT NULL DEFAULT 0,
    revenue_account_code    VARCHAR(20),
    cogs_account_code       VARCHAR(20),
    inventory_account_code  VARCHAR(20),
    group_id                UUID REFERENCES item_group(id),
    variant_attributes      JSONB         NOT NULL DEFAULT '{}'::jsonb,
    barcode                 VARCHAR(50),
    is_active               BOOLEAN       NOT NULL DEFAULT TRUE,
    is_deleted              BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by              UUID,
    CONSTRAINT chk_item_variant_attrs_not_empty CHECK (
        group_id IS NULL
        OR (variant_attributes IS NOT NULL
            AND jsonb_typeof(variant_attributes) = 'object'
            AND variant_attributes <> '{}'::jsonb)
    )
);

CREATE UNIQUE INDEX idx_item_org_sku          ON item(org_id, sku)          WHERE NOT is_deleted;
CREATE INDEX        idx_item_org_name         ON item(org_id, name)         WHERE NOT is_deleted;
CREATE INDEX        idx_item_org_category     ON item(org_id, category)     WHERE NOT is_deleted;
CREATE INDEX        idx_item_org_active       ON item(org_id, is_active)    WHERE NOT is_deleted;
CREATE INDEX        idx_item_base_uom         ON item(base_uom_id)          WHERE base_uom_id IS NOT NULL;
CREATE INDEX        idx_item_track_batches    ON item(org_id)               WHERE track_batches AND NOT is_deleted;
CREATE UNIQUE INDEX idx_item_group_variant_unique ON item(group_id, variant_attributes)
    WHERE group_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX        idx_item_group_id         ON item(group_id)             WHERE group_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX        idx_item_barcode          ON item(barcode)              WHERE barcode IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 17. UOM CONVERSION
-- ─────────────────────────────────────────────────────────────
CREATE TABLE uom_conversion (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID          NOT NULL REFERENCES organisation(id),
    item_id     UUID REFERENCES item(id),
    from_uom_id UUID          NOT NULL REFERENCES uom(id),
    to_uom_id   UUID          NOT NULL REFERENCES uom(id),
    factor      NUMERIC(18,6) NOT NULL CHECK (factor > 0),
    is_deleted  BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by  UUID,
    CONSTRAINT uom_conversion_not_self CHECK (from_uom_id <> to_uom_id)
);

CREATE UNIQUE INDEX idx_uom_conv_org_wide ON uom_conversion(org_id, from_uom_id, to_uom_id)
    WHERE item_id IS NULL AND NOT is_deleted;
CREATE UNIQUE INDEX idx_uom_conv_per_item ON uom_conversion(org_id, item_id, from_uom_id, to_uom_id)
    WHERE item_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX idx_uom_conv_org ON uom_conversion(org_id) WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 18. PRICE LIST
-- ─────────────────────────────────────────────────────────────
CREATE TABLE price_list (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID         NOT NULL REFERENCES organisation(id),
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    currency    VARCHAR(3)   NOT NULL DEFAULT 'INR',
    is_default  BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by  UUID
);

CREATE UNIQUE INDEX idx_price_list_org_default ON price_list(org_id)       WHERE is_default AND NOT is_deleted;
CREATE UNIQUE INDEX idx_price_list_org_name    ON price_list(org_id, name) WHERE NOT is_deleted;
CREATE INDEX        idx_price_list_org         ON price_list(org_id)       WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 19. PRICE LIST ITEM
-- ─────────────────────────────────────────────────────────────
CREATE TABLE price_list_item (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID          NOT NULL REFERENCES organisation(id),
    price_list_id UUID          NOT NULL REFERENCES price_list(id),
    item_id       UUID          NOT NULL REFERENCES item(id),
    min_quantity  NUMERIC(15,4) NOT NULL DEFAULT 1,
    price         NUMERIC(15,4) NOT NULL,
    is_deleted    BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by    UUID
);

CREATE UNIQUE INDEX idx_price_list_item_unique  ON price_list_item(price_list_id, item_id, min_quantity) WHERE NOT is_deleted;
CREATE INDEX        idx_price_list_item_lookup  ON price_list_item(price_list_id, item_id, min_quantity DESC) WHERE NOT is_deleted;
CREATE INDEX        idx_price_list_item_org     ON price_list_item(org_id) WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 20. BOM COMPONENT
-- ─────────────────────────────────────────────────────────────
CREATE TABLE bom_component (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID          NOT NULL REFERENCES organisation(id),
    parent_item_id  UUID          NOT NULL REFERENCES item(id),
    child_item_id   UUID          NOT NULL REFERENCES item(id),
    quantity        NUMERIC(15,4) NOT NULL,
    is_deleted      BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by      UUID,
    CONSTRAINT chk_bom_component_no_self_ref  CHECK (parent_item_id <> child_item_id),
    CONSTRAINT chk_bom_component_positive_qty CHECK (quantity > 0)
);

CREATE UNIQUE INDEX idx_bom_component_unique ON bom_component(parent_item_id, child_item_id) WHERE NOT is_deleted;
CREATE INDEX        idx_bom_component_parent ON bom_component(parent_item_id) WHERE NOT is_deleted;
CREATE INDEX        idx_bom_component_org    ON bom_component(org_id)         WHERE NOT is_deleted;

-- ─────────────────────────────────────────────────────────────
-- 21. SUPPLIER  (minimal vendor master for GRNs)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE supplier (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID         NOT NULL REFERENCES organisation(id),
    name                VARCHAR(255) NOT NULL,
    gstin               VARCHAR(15),
    pan                 VARCHAR(10),
    phone               VARCHAR(30),
    email               VARCHAR(255),
    address_line1       VARCHAR(255),
    address_line2       VARCHAR(255),
    city                VARCHAR(100),
    state               VARCHAR(100),
    state_code          VARCHAR(5),
    postal_code         VARCHAR(20),
    country             VARCHAR(2)   DEFAULT 'IN',
    payment_terms_days  INTEGER      NOT NULL DEFAULT 30,
    notes               TEXT,
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
    is_deleted          BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by          UUID
);

CREATE INDEX        idx_supplier_org_name   ON supplier(org_id, name)  WHERE NOT is_deleted;
CREATE INDEX        idx_supplier_org_active ON supplier(org_id, is_active) WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_supplier_org_gstin  ON supplier(org_id, gstin) WHERE gstin IS NOT NULL AND NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 22. STOCK BATCH  (lot/batch master — FEFO support)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stock_batch (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID          NOT NULL REFERENCES organisation(id),
    item_id             UUID          NOT NULL REFERENCES item(id),
    batch_number        VARCHAR(100)  NOT NULL,
    expiry_date         DATE,
    manufacturing_date  DATE,
    unit_cost           NUMERIC(15,4) NOT NULL DEFAULT 0,
    supplier_id         UUID REFERENCES supplier(id),
    notes               TEXT,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    is_deleted          BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by          UUID
);

CREATE UNIQUE INDEX idx_stock_batch_org_item_number ON stock_batch(org_id, item_id, batch_number) WHERE NOT is_deleted;
CREATE INDEX        idx_stock_batch_fefo             ON stock_batch(org_id, item_id, expiry_date NULLS LAST)
    WHERE is_active AND NOT is_deleted;
CREATE INDEX        idx_stock_batch_org_item         ON stock_batch(org_id, item_id) WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 23. STOCK BATCH BALANCE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stock_batch_balance (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID          NOT NULL REFERENCES organisation(id),
    batch_id         UUID          NOT NULL REFERENCES stock_batch(id),
    warehouse_id     UUID          NOT NULL REFERENCES warehouse(id),
    quantity_on_hand NUMERIC(15,4) NOT NULL DEFAULT 0,
    last_movement_at TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_stock_batch_balance_unique   ON stock_batch_balance(org_id, batch_id, warehouse_id);
CREATE INDEX        idx_stock_batch_balance_batch    ON stock_batch_balance(batch_id);
CREATE INDEX        idx_stock_batch_balance_warehouse ON stock_batch_balance(org_id, warehouse_id);


-- ─────────────────────────────────────────────────────────────
-- 24. STOCK MOVEMENT  (immutable append-only ledger)
--     reference_type final list includes STOCK_RECEIPT (V10)
--     batch_id FK added (V14)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stock_movement (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID          NOT NULL REFERENCES organisation(id),
    branch_id        UUID          REFERENCES branch(id),
    item_id          UUID          NOT NULL REFERENCES item(id),
    warehouse_id     UUID          NOT NULL REFERENCES warehouse(id),
    movement_date    DATE          NOT NULL,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    movement_type    VARCHAR(20)   NOT NULL
                     CHECK (movement_type IN (
                         'PURCHASE','SALE','ADJUSTMENT','TRANSFER_IN','TRANSFER_OUT',
                         'OPENING','RETURN_IN','RETURN_OUT','STOCK_COUNT','REVERSAL'
                     )),
    quantity         NUMERIC(15,4) NOT NULL,
    unit_cost        NUMERIC(15,4) NOT NULL DEFAULT 0,
    total_cost       NUMERIC(15,2) NOT NULL DEFAULT 0,
    reference_type   VARCHAR(30)
                     CHECK (reference_type IN (
                         'INVOICE','CREDIT_NOTE','BILL','DEBIT_NOTE',
                         'STOCK_ADJUSTMENT','STOCK_TRANSFER','STOCK_COUNT',
                         'OPENING_BALANCE','STOCK_RECEIPT'
                     )),
    reference_id     UUID,
    reference_number VARCHAR(50),
    batch_id         UUID REFERENCES stock_batch(id),
    is_reversal      BOOLEAN       NOT NULL DEFAULT FALSE,
    reversal_of_id   UUID REFERENCES stock_movement(id),
    is_reversed      BOOLEAN       NOT NULL DEFAULT FALSE,
    notes            TEXT,
    created_by       UUID
);

CREATE INDEX idx_stock_movement_item      ON stock_movement(org_id, item_id, movement_date);
CREATE INDEX idx_stock_movement_warehouse ON stock_movement(org_id, warehouse_id, movement_date);
CREATE INDEX idx_stock_movement_reference ON stock_movement(reference_type, reference_id);
CREATE INDEX idx_stock_movement_org_date  ON stock_movement(org_id, movement_date);
CREATE INDEX idx_stock_movement_org_type  ON stock_movement(org_id, movement_type);
CREATE INDEX idx_stock_movement_batch     ON stock_movement(batch_id) WHERE batch_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 25. STOCK BALANCE  (denormalised cache)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stock_balance (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID          NOT NULL REFERENCES organisation(id),
    branch_id        UUID          REFERENCES branch(id),
    item_id          UUID          NOT NULL REFERENCES item(id),
    warehouse_id     UUID          NOT NULL REFERENCES warehouse(id),
    quantity_on_hand NUMERIC(15,4) NOT NULL DEFAULT 0,
    average_cost     NUMERIC(15,4) NOT NULL DEFAULT 0,
    last_movement_at TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_stock_balance_item_wh ON stock_balance(org_id, item_id, warehouse_id);
CREATE INDEX        idx_stock_balance_org_wh  ON stock_balance(org_id, warehouse_id);


-- ─────────────────────────────────────────────────────────────
-- 26. STOCK COUNT
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stock_count (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID         NOT NULL REFERENCES organisation(id),
    warehouse_id UUID         NOT NULL REFERENCES warehouse(id),
    count_number VARCHAR(30)  NOT NULL,
    count_date   DATE         NOT NULL,
    status       VARCHAR(20)  NOT NULL DEFAULT 'DRAFT'
                 CHECK (status IN ('DRAFT','POSTED','CANCELLED')),
    notes        TEXT,
    posted_at    TIMESTAMPTZ,
    posted_by    UUID,
    is_deleted   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by   UUID
);

CREATE UNIQUE INDEX idx_stock_count_org_number ON stock_count(org_id, count_number) WHERE NOT is_deleted;
CREATE INDEX        idx_stock_count_org        ON stock_count(org_id, count_date);

CREATE TABLE stock_count_line (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_count_id    UUID          NOT NULL REFERENCES stock_count(id) ON DELETE CASCADE,
    item_id           UUID          NOT NULL REFERENCES item(id),
    expected_quantity NUMERIC(15,4) NOT NULL DEFAULT 0,
    counted_quantity  NUMERIC(15,4) NOT NULL DEFAULT 0,
    variance          NUMERIC(15,4) NOT NULL DEFAULT 0,
    notes             TEXT,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_count_line_count ON stock_count_line(stock_count_id);


-- ─────────────────────────────────────────────────────────────
-- 27. CONTACT  (unified: customers, vendors, both)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE contact (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID          NOT NULL REFERENCES organisation(id),

    contact_type            VARCHAR(10)   NOT NULL DEFAULT 'CUSTOMER'
                            CHECK (contact_type IN ('CUSTOMER','VENDOR','BOTH')),

    display_name            VARCHAR(255)  NOT NULL,
    company_name            VARCHAR(255),
    first_name              VARCHAR(100),
    last_name               VARCHAR(100),
    salutation              VARCHAR(20),

    gstin                   VARCHAR(15),
    pan                     VARCHAR(10),
    tax_id                  VARCHAR(50),
    gst_treatment           VARCHAR(30)   DEFAULT 'UNREGISTERED'
                            CHECK (gst_treatment IN (
                                'REGISTERED','UNREGISTERED','COMPOSITION',
                                'CONSUMER','OVERSEAS','SEZ'
                            )),
    place_of_supply         VARCHAR(5),
    msme_registered         BOOLEAN       NOT NULL DEFAULT FALSE,
    msme_registration_no    VARCHAR(50),

    email                   VARCHAR(255),
    phone                   VARCHAR(30),
    mobile                  VARCHAR(30),
    website                 VARCHAR(255),

    billing_address_line1   VARCHAR(255),
    billing_address_line2   VARCHAR(255),
    billing_city            VARCHAR(100),
    billing_state           VARCHAR(100),
    billing_state_code      VARCHAR(5),
    billing_postal_code     VARCHAR(20),
    billing_country         VARCHAR(2)    NOT NULL DEFAULT 'IN',

    shipping_address_line1  VARCHAR(255),
    shipping_address_line2  VARCHAR(255),
    shipping_city           VARCHAR(100),
    shipping_state          VARCHAR(100),
    shipping_state_code     VARCHAR(5),
    shipping_postal_code    VARCHAR(20),
    shipping_country        VARCHAR(2)    NOT NULL DEFAULT 'IN',

    currency                VARCHAR(3)    NOT NULL DEFAULT 'INR',
    payment_terms_days      INTEGER       NOT NULL DEFAULT 30,
    credit_limit            NUMERIC(15,2) NOT NULL DEFAULT 0,
    opening_balance         NUMERIC(15,2) NOT NULL DEFAULT 0,
    outstanding_ar          NUMERIC(15,2) NOT NULL DEFAULT 0,
    outstanding_ap          NUMERIC(15,2) NOT NULL DEFAULT 0,
    default_price_list_id   UUID REFERENCES price_list(id),

    tds_applicable          BOOLEAN       NOT NULL DEFAULT FALSE,
    tds_section             VARCHAR(20),
    tds_rate                NUMERIC(5,2),

    bank_name               VARCHAR(255),
    bank_account_no         VARCHAR(50),
    bank_ifsc               VARCHAR(20),
    upi_id                  VARCHAR(50),

    portal_enabled          BOOLEAN       NOT NULL DEFAULT FALSE,
    portal_url              VARCHAR(500),

    notes                   TEXT,

    is_active               BOOLEAN       NOT NULL DEFAULT TRUE,
    is_deleted              BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by              UUID
);

CREATE INDEX        idx_contact_org        ON contact(org_id)                 WHERE NOT is_deleted;
CREATE INDEX        idx_contact_org_type   ON contact(org_id, contact_type)   WHERE NOT is_deleted;
CREATE INDEX        idx_contact_org_name   ON contact(org_id, display_name)   WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_contact_org_gstin  ON contact(org_id, gstin)
    WHERE gstin IS NOT NULL AND NOT is_deleted;
CREATE INDEX        idx_contact_default_pl ON contact(default_price_list_id)
    WHERE default_price_list_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 27b. CONTACT PERSON  (multiple people per contact)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE contact_person (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id  UUID         NOT NULL REFERENCES contact(id),
    salutation  VARCHAR(20),
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100),
    designation VARCHAR(100),
    department  VARCHAR(100),
    email       VARCHAR(255),
    phone       VARCHAR(30),
    mobile      VARCHAR(30),
    is_primary  BOOLEAN      NOT NULL DEFAULT FALSE,
    notes       TEXT,
    is_deleted  BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX        idx_contact_person_contact ON contact_person(contact_id) WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_contact_person_primary ON contact_person(contact_id)
    WHERE is_primary AND NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 28. INVOICE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE invoice (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID          NOT NULL REFERENCES organisation(id),
    branch_id        UUID          REFERENCES branch(id),
    contact_id       UUID          NOT NULL REFERENCES contact(id),
    invoice_number   VARCHAR(30)   NOT NULL,
    invoice_date     DATE          NOT NULL,
    due_date         DATE          NOT NULL,
    status           VARCHAR(20)   NOT NULL DEFAULT 'DRAFT'
                     CHECK (status IN ('DRAFT','SENT','PARTIALLY_PAID','PAID','CANCELLED','OVERDUE')),
    subtotal         NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount       NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount     NUMERIC(15,2) NOT NULL DEFAULT 0,
    amount_paid      NUMERIC(15,2) NOT NULL DEFAULT 0,
    balance_due      NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency         VARCHAR(3)    NOT NULL DEFAULT 'INR',
    exchange_rate    NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    base_subtotal    NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount  NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_total       NUMERIC(15,2) NOT NULL DEFAULT 0,
    place_of_supply  VARCHAR(5),
    is_reverse_charge BOOLEAN      NOT NULL DEFAULT FALSE,
    journal_entry_id UUID REFERENCES journal_entry(id),
    notes            TEXT,
    terms_and_conditions TEXT,
    period_year      INTEGER,
    period_month     INTEGER,
    sent_at          TIMESTAMPTZ,
    cancelled_at     TIMESTAMPTZ,
    cancelled_by     UUID,
    cancel_reason    TEXT,
    is_deleted       BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by       UUID
);

CREATE UNIQUE INDEX idx_invoice_org_number ON invoice(org_id, invoice_number) WHERE NOT is_deleted;
CREATE INDEX        idx_invoice_org_status ON invoice(org_id, status);
CREATE INDEX        idx_invoice_contact    ON invoice(contact_id);
CREATE INDEX        idx_invoice_org_date   ON invoice(org_id, invoice_date);
CREATE INDEX        idx_invoice_org_due    ON invoice(org_id, due_date)
    WHERE status IN ('SENT','PARTIALLY_PAID','OVERDUE');


-- ─────────────────────────────────────────────────────────────
-- 29. INVOICE LINE  (item_id + batch_id from V8/V14)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE invoice_line (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id           UUID          NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
    line_number          INTEGER       NOT NULL,
    description          VARCHAR(500)  NOT NULL,
    hsn_code             VARCHAR(10),
    item_id              UUID REFERENCES item(id),
    batch_id             UUID REFERENCES stock_batch(id),
    quantity             NUMERIC(12,4) NOT NULL DEFAULT 1,
    unit_price           NUMERIC(15,2) NOT NULL,
    discount_percent     NUMERIC(5,2)  NOT NULL DEFAULT 0,
    discount_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    taxable_amount       NUMERIC(15,2) NOT NULL,
    gst_rate             NUMERIC(5,2)  NOT NULL DEFAULT 0,
    tax_amount           NUMERIC(15,2) NOT NULL DEFAULT 0,
    line_total           NUMERIC(15,2) NOT NULL,
    account_code         VARCHAR(20)   NOT NULL,
    base_taxable_amount  NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_line_total      NUMERIC(15,2) NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_invoice_line_invoice ON invoice_line(invoice_id);
CREATE INDEX idx_invoice_line_item    ON invoice_line(item_id)   WHERE item_id IS NOT NULL;
CREATE INDEX idx_invoice_line_batch   ON invoice_line(batch_id)  WHERE batch_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 30. TAX LINE ITEM  (generic; covers AR, AP, expenses)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE tax_line_item (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID          NOT NULL REFERENCES organisation(id),
    source_type         VARCHAR(30)   NOT NULL
                        CHECK (source_type IN ('INVOICE','CREDIT_NOTE','BILL','EXPENSE')),
    source_id           UUID          NOT NULL,
    source_line_id      UUID,
    tax_regime          VARCHAR(30)   NOT NULL,
    component_code      VARCHAR(10)   NOT NULL,
    rate                NUMERIC(5,2)  NOT NULL,
    taxable_amount      NUMERIC(15,2) NOT NULL,
    tax_amount          NUMERIC(15,2) NOT NULL,
    account_code        VARCHAR(20)   NOT NULL,
    hsn_code            VARCHAR(10),
    base_taxable_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount     NUMERIC(15,2) NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_tax_line_source ON tax_line_item(source_type, source_id);
CREATE INDEX idx_tax_line_org    ON tax_line_item(org_id);
CREATE INDEX idx_tax_line_regime ON tax_line_item(org_id, tax_regime, component_code);


-- ─────────────────────────────────────────────────────────────
-- 31. PAYMENT
-- ─────────────────────────────────────────────────────────────
CREATE TABLE payment (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id           UUID          NOT NULL REFERENCES organisation(id),
    branch_id        UUID          REFERENCES branch(id),
    contact_id       UUID          NOT NULL REFERENCES contact(id),
    invoice_id       UUID          NOT NULL REFERENCES invoice(id),
    payment_number   VARCHAR(30)   NOT NULL,
    payment_date     DATE          NOT NULL,
    amount           NUMERIC(15,2) NOT NULL,
    currency         VARCHAR(3)    NOT NULL DEFAULT 'INR',
    exchange_rate    NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    base_amount      NUMERIC(15,2) NOT NULL,
    payment_method   VARCHAR(30)   NOT NULL
                     CHECK (payment_method IN ('CASH','BANK_TRANSFER','UPI','CHEQUE','CARD','OTHER')),
    reference_number VARCHAR(100),
    bank_account     VARCHAR(50),
    notes            TEXT,
    journal_entry_id UUID REFERENCES journal_entry(id),
    is_deleted       BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by       UUID
);

CREATE UNIQUE INDEX idx_payment_org_number ON payment(org_id, payment_number) WHERE NOT is_deleted;
CREATE INDEX        idx_payment_org        ON payment(org_id);
CREATE INDEX        idx_payment_invoice    ON payment(invoice_id);
CREATE INDEX        idx_payment_contact    ON payment(contact_id);


-- ─────────────────────────────────────────────────────────────
-- 32. CREDIT NOTE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE credit_note (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id            UUID          NOT NULL REFERENCES organisation(id),
    branch_id         UUID          REFERENCES branch(id),
    contact_id        UUID          NOT NULL REFERENCES contact(id),
    invoice_id        UUID REFERENCES invoice(id),
    credit_note_number VARCHAR(30)  NOT NULL,
    credit_note_date  DATE          NOT NULL,
    reason            TEXT          NOT NULL,
    status            VARCHAR(20)   NOT NULL DEFAULT 'DRAFT'
                      CHECK (status IN ('DRAFT','ISSUED','APPLIED','CANCELLED')),
    subtotal          NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount        NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount      NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency          VARCHAR(3)    NOT NULL DEFAULT 'INR',
    exchange_rate     NUMERIC(12,6) NOT NULL DEFAULT 1.000000,
    base_subtotal     NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount   NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_total        NUMERIC(15,2) NOT NULL DEFAULT 0,
    place_of_supply   VARCHAR(5),
    journal_entry_id  UUID REFERENCES journal_entry(id),
    is_deleted        BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by        UUID
);

CREATE UNIQUE INDEX idx_credit_note_org_number ON credit_note(org_id, credit_note_number) WHERE NOT is_deleted;
CREATE INDEX        idx_credit_note_org        ON credit_note(org_id);
CREATE INDEX        idx_credit_note_invoice    ON credit_note(invoice_id);


-- ─────────────────────────────────────────────────────────────
-- 33. CREDIT NOTE LINE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE credit_note_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_note_id      UUID          NOT NULL REFERENCES credit_note(id) ON DELETE CASCADE,
    line_number         INTEGER       NOT NULL,
    description         VARCHAR(500)  NOT NULL,
    hsn_code            VARCHAR(10),
    item_id             UUID REFERENCES item(id),
    batch_id            UUID REFERENCES stock_batch(id),
    quantity            NUMERIC(12,4) NOT NULL DEFAULT 1,
    unit_price          NUMERIC(15,2) NOT NULL,
    taxable_amount      NUMERIC(15,2) NOT NULL,
    gst_rate            NUMERIC(5,2)  NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
    line_total          NUMERIC(15,2) NOT NULL,
    account_code        VARCHAR(20)   NOT NULL,
    base_taxable_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_tax_amount     NUMERIC(15,2) NOT NULL DEFAULT 0,
    base_line_total     NUMERIC(15,2) NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_credit_note_line_cn    ON credit_note_line(credit_note_id);
CREATE INDEX idx_credit_note_line_item  ON credit_note_line(item_id)  WHERE item_id IS NOT NULL;
CREATE INDEX idx_credit_note_line_batch ON credit_note_line(batch_id) WHERE batch_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 34. INVOICE NUMBER SEQUENCE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE invoice_number_sequence (
    org_id     UUID        NOT NULL REFERENCES organisation(id),
    prefix     VARCHAR(10) NOT NULL DEFAULT 'INV',
    year       INTEGER     NOT NULL,
    next_value BIGINT      NOT NULL DEFAULT 1,
    PRIMARY KEY (org_id, prefix, year)
);


-- ─────────────────────────────────────────────────────────────
-- 35. STOCK RECEIPT  (GRN — currency VARCHAR(3) from V11)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stock_receipt (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                UUID          NOT NULL REFERENCES organisation(id),
    branch_id             UUID          REFERENCES branch(id),
    receipt_number        VARCHAR(30)   NOT NULL,
    receipt_date          DATE          NOT NULL,
    warehouse_id          UUID          NOT NULL REFERENCES warehouse(id),
    supplier_id           UUID          NOT NULL REFERENCES supplier(id),
    supplier_invoice_no   VARCHAR(100),
    supplier_invoice_date DATE,
    subtotal              NUMERIC(15,2) NOT NULL DEFAULT 0,
    tax_amount            NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency              VARCHAR(3)    NOT NULL DEFAULT 'INR',
    status                VARCHAR(15)   NOT NULL DEFAULT 'DRAFT'
                          CHECK (status IN ('DRAFT','RECEIVED','CANCELLED')),
    received_at           TIMESTAMPTZ,
    received_by           UUID,
    cancelled_at          TIMESTAMPTZ,
    cancelled_by          UUID,
    cancel_reason         VARCHAR(500),
    notes                 TEXT,
    period_year           INTEGER,
    period_month          INTEGER,
    is_deleted            BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by            UUID
);

CREATE UNIQUE INDEX idx_stock_receipt_org_number   ON stock_receipt(org_id, receipt_number) WHERE NOT is_deleted;
CREATE INDEX        idx_stock_receipt_org_date     ON stock_receipt(org_id, receipt_date);
CREATE INDEX        idx_stock_receipt_org_supplier ON stock_receipt(org_id, supplier_id);
CREATE INDEX        idx_stock_receipt_org_status   ON stock_receipt(org_id, status);


-- ─────────────────────────────────────────────────────────────
-- 36. STOCK RECEIPT LINE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE stock_receipt_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id          UUID          NOT NULL REFERENCES stock_receipt(id) ON DELETE CASCADE,
    line_number         INTEGER       NOT NULL,
    item_id             UUID          NOT NULL REFERENCES item(id),
    description         VARCHAR(500),
    hsn_code            VARCHAR(10),
    quantity            NUMERIC(15,4) NOT NULL,
    unit_of_measure     VARCHAR(20)   NOT NULL DEFAULT 'PCS',
    unit_price          NUMERIC(15,4) NOT NULL,
    discount_percent    NUMERIC(5,2)  NOT NULL DEFAULT 0,
    discount_amount     NUMERIC(15,2) NOT NULL DEFAULT 0,
    taxable_amount      NUMERIC(15,2) NOT NULL,
    gst_rate            NUMERIC(5,2)  NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(15,2) NOT NULL DEFAULT 0,
    line_total          NUMERIC(15,2) NOT NULL,
    batch_number        VARCHAR(50),
    batch_id            UUID REFERENCES stock_batch(id),
    expiry_date         DATE,
    manufacturing_date  DATE,
    stock_movement_id   UUID REFERENCES stock_movement(id),
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_receipt_line_receipt ON stock_receipt_line(receipt_id);
CREATE INDEX idx_stock_receipt_line_item    ON stock_receipt_line(item_id);
CREATE INDEX idx_stock_receipt_line_batch   ON stock_receipt_line(batch_id) WHERE batch_id IS NOT NULL;

-- ═══════════════════════════════════════════════════════════════
-- TRIGGERS & FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- T1. Journal entry immutability (V4)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION prevent_journal_entry_update()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        IF OLD.is_reversed = FALSE AND NEW.is_reversed = TRUE
           AND NEW.status = OLD.status
           AND NEW.effective_date = OLD.effective_date
           AND NEW.description = OLD.description THEN
            RETURN NEW;
        END IF;
        IF NEW.status != OLD.status
           OR NEW.description IS DISTINCT FROM OLD.description
           OR NEW.effective_date != OLD.effective_date
           OR NEW.source_module != OLD.source_module
           OR NEW.entry_number != OLD.entry_number THEN
            RAISE EXCEPTION 'Cannot modify POSTED journal entry %', OLD.id;
        END IF;
    END IF;
    IF OLD.status = 'DRAFT' AND NEW.status = 'POSTED' THEN RETURN NEW; END IF;
    IF OLD.status = 'DRAFT' AND NEW.status = 'DRAFT'  THEN RETURN NEW; END IF;
    IF OLD.status = 'POSTED' AND NEW.status = 'DRAFT' THEN
        RAISE EXCEPTION 'Cannot revert POSTED journal entry % to DRAFT', OLD.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journal_entry_immutable
BEFORE UPDATE ON journal_entry
FOR EACH ROW EXECUTE FUNCTION prevent_journal_entry_update();

CREATE OR REPLACE FUNCTION prevent_journal_entry_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        RAISE EXCEPTION 'Cannot delete POSTED journal entry %', OLD.id;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journal_entry_no_delete
BEFORE DELETE ON journal_entry
FOR EACH ROW EXECUTE FUNCTION prevent_journal_entry_delete();

CREATE OR REPLACE FUNCTION check_journal_balance()
RETURNS TRIGGER AS $$
DECLARE
    total_debit  DECIMAL(15,2);
    total_credit DECIMAL(15,2);
BEGIN
    IF NEW.status = 'POSTED' AND OLD.status = 'DRAFT' THEN
        SELECT COALESCE(SUM(debit),0), COALESCE(SUM(credit),0)
        INTO total_debit, total_credit
        FROM journal_line WHERE journal_entry_id = NEW.id;
        IF total_debit != total_credit THEN
            RAISE EXCEPTION 'Journal entry % does not balance. Debit: %, Credit: %',
                NEW.id, total_debit, total_credit;
        END IF;
        IF total_debit = 0 AND total_credit = 0 THEN
            RAISE EXCEPTION 'Journal entry % has no lines or zero amounts', NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_balance_on_post
BEFORE UPDATE OF status ON journal_entry
FOR EACH ROW
WHEN (NEW.status = 'POSTED' AND OLD.status = 'DRAFT')
EXECUTE FUNCTION check_journal_balance();

CREATE OR REPLACE FUNCTION prevent_journal_line_mutation()
RETURNS TRIGGER AS $$
DECLARE
    entry_status VARCHAR(10);
BEGIN
    SELECT status INTO entry_status FROM journal_entry
    WHERE id = COALESCE(OLD.journal_entry_id, NEW.journal_entry_id);
    IF entry_status = 'POSTED' THEN
        RAISE EXCEPTION 'Cannot modify lines of POSTED journal entry';
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journal_line_immutable
BEFORE UPDATE OR DELETE ON journal_line
FOR EACH ROW EXECUTE FUNCTION prevent_journal_line_mutation();

CREATE OR REPLACE FUNCTION get_account_balance(
    p_account_id UUID, p_org_id UUID, p_as_of_date DATE DEFAULT CURRENT_DATE
) RETURNS DECIMAL(15,2) AS $$
DECLARE
    v_balance      DECIMAL(15,2);
    v_account_type VARCHAR(20);
BEGIN
    SELECT type INTO v_account_type FROM account WHERE id = p_account_id;
    SELECT COALESCE(SUM(jl.base_debit) - SUM(jl.base_credit), 0)
    INTO v_balance
    FROM journal_line jl
    JOIN journal_entry je ON jl.journal_entry_id = je.id
    WHERE jl.account_id = p_account_id
      AND je.org_id = p_org_id
      AND je.status = 'POSTED'
      AND je.effective_date <= p_as_of_date;
    IF v_account_type IN ('LIABILITY','EQUITY','REVENUE') THEN
        v_balance := -v_balance;
    END IF;
    RETURN v_balance;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────────
-- T2. Stock movement immutability (V8)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION prevent_stock_movement_mutation()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.is_reversed = FALSE AND NEW.is_reversed = TRUE
       AND NEW.quantity      = OLD.quantity
       AND NEW.unit_cost     = OLD.unit_cost
       AND NEW.total_cost    = OLD.total_cost
       AND NEW.movement_type = OLD.movement_type
       AND NEW.movement_date = OLD.movement_date
       AND NEW.item_id       = OLD.item_id
       AND NEW.warehouse_id  = OLD.warehouse_id
       AND NEW.org_id        = OLD.org_id THEN
        RETURN NEW;
    END IF;
    IF NEW.quantity      != OLD.quantity
       OR NEW.unit_cost     != OLD.unit_cost
       OR NEW.movement_type != OLD.movement_type
       OR NEW.movement_date != OLD.movement_date
       OR NEW.item_id       != OLD.item_id
       OR NEW.warehouse_id  != OLD.warehouse_id
       OR NEW.org_id        != OLD.org_id THEN
        RAISE EXCEPTION 'Cannot modify posted stock_movement % — record a reversal instead', OLD.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_movement_immutable
BEFORE UPDATE ON stock_movement
FOR EACH ROW EXECUTE FUNCTION prevent_stock_movement_mutation();

CREATE OR REPLACE FUNCTION prevent_stock_movement_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Cannot delete stock_movement % — record a reversal instead', OLD.id;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_movement_no_delete
BEFORE DELETE ON stock_movement
FOR EACH ROW EXECUTE FUNCTION prevent_stock_movement_delete();

CREATE OR REPLACE FUNCTION get_item_balance(
    p_item_id UUID, p_warehouse_id UUID, p_org_id UUID, p_as_of_date DATE DEFAULT CURRENT_DATE
) RETURNS NUMERIC(15,4) AS $$
DECLARE
    v_balance NUMERIC(15,4);
BEGIN
    SELECT COALESCE(SUM(quantity), 0)
    INTO v_balance
    FROM stock_movement
    WHERE org_id      = p_org_id
      AND item_id     = p_item_id
      AND warehouse_id = p_warehouse_id
      AND movement_date <= p_as_of_date;
    RETURN v_balance;
END;
$$ LANGUAGE plpgsql;


-- ═══════════════════════════════════════════════════════════════
-- VIEWS
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- V1. branch_stock_summary
--     Rolls up on-hand stock per (branch, item) across all
--     warehouses in that branch. Used by the branch dashboard.
-- ─────────────────────────────────────────────────────────────
CREATE VIEW branch_stock_summary AS
SELECT
    w.org_id                                  AS org_id,
    w.branch_id                               AS branch_id,
    sb.item_id                                AS item_id,
    SUM(sb.quantity_on_hand)                  AS quantity_on_hand,
    SUM(sb.quantity_on_hand * sb.average_cost) AS stock_value,
    COUNT(DISTINCT sb.warehouse_id)           AS warehouse_count,
    MAX(sb.last_movement_at)                  AS last_movement_at
FROM stock_balance sb
JOIN warehouse     w  ON w.id = sb.warehouse_id
WHERE w.branch_id IS NOT NULL
  AND NOT w.is_deleted
GROUP BY w.org_id, w.branch_id, sb.item_id;
