-- ============================================================
-- V2: Unified Contact — F6
--
-- Replaces the narrow 'customer' master with a unified 'contact'
-- table that covers customers, vendors, and contacts that are both.
-- The 'customer' table is NOT dropped here — it stays as a FK anchor
-- for existing invoice/payment/credit_note rows. contact_id columns
-- are added alongside customer_id (nullable) so both paths work.
--
-- Migration path for existing data:
--   1. Every customer row is copied into contact (same UUID preserved
--      so customer_id and contact_id point to the same row value).
--   2. contact_id is backfilled from customer_id on all dependent tables.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Contact master
-- ─────────────────────────────────────────────────────────────
CREATE TABLE contact (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID          NOT NULL REFERENCES organisation(id),

    -- Classification
    contact_type            VARCHAR(10)   NOT NULL DEFAULT 'CUSTOMER'
                            CHECK (contact_type IN ('CUSTOMER','VENDOR','BOTH')),

    -- Identity
    display_name            VARCHAR(255)  NOT NULL,
    company_name            VARCHAR(255),
    first_name              VARCHAR(100),
    last_name               VARCHAR(100),
    salutation              VARCHAR(20),

    -- Tax identifiers
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

    -- Contact channels
    email                   VARCHAR(255),
    phone                   VARCHAR(30),
    mobile                  VARCHAR(30),
    website                 VARCHAR(255),

    -- Billing address
    billing_address_line1   VARCHAR(255),
    billing_address_line2   VARCHAR(255),
    billing_city            VARCHAR(100),
    billing_state           VARCHAR(100),
    billing_state_code      VARCHAR(5),
    billing_postal_code     VARCHAR(20),
    billing_country         VARCHAR(2)    NOT NULL DEFAULT 'IN',

    -- Shipping address
    shipping_address_line1  VARCHAR(255),
    shipping_address_line2  VARCHAR(255),
    shipping_city           VARCHAR(100),
    shipping_state          VARCHAR(100),
    shipping_state_code     VARCHAR(5),
    shipping_postal_code    VARCHAR(20),
    shipping_country        VARCHAR(2)    NOT NULL DEFAULT 'IN',

    -- Financial terms
    currency                VARCHAR(3)    NOT NULL DEFAULT 'INR',
    payment_terms_days      INTEGER       NOT NULL DEFAULT 30,
    credit_limit            NUMERIC(15,2) NOT NULL DEFAULT 0,
    opening_balance         NUMERIC(15,2) NOT NULL DEFAULT 0,
    outstanding_ar          NUMERIC(15,2) NOT NULL DEFAULT 0,
    outstanding_ap          NUMERIC(15,2) NOT NULL DEFAULT 0,
    default_price_list_id   UUID REFERENCES price_list(id),

    -- TDS (vendor side)
    tds_applicable          BOOLEAN       NOT NULL DEFAULT FALSE,
    tds_section             VARCHAR(20),
    tds_rate                NUMERIC(5,2),

    -- Bank details (vendor payments)
    bank_name               VARCHAR(255),
    bank_account_no         VARCHAR(50),
    bank_ifsc               VARCHAR(20),
    upi_id                  VARCHAR(50),

    -- Portal
    portal_enabled          BOOLEAN       NOT NULL DEFAULT FALSE,
    portal_url              VARCHAR(500),

    notes                   TEXT,

    -- Lifecycle
    is_active               BOOLEAN       NOT NULL DEFAULT TRUE,
    is_deleted              BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by              UUID
);

CREATE INDEX        idx_contact_org      ON contact(org_id)                 WHERE NOT is_deleted;
CREATE INDEX        idx_contact_org_type ON contact(org_id, contact_type)   WHERE NOT is_deleted;
CREATE INDEX        idx_contact_org_name ON contact(org_id, display_name)   WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_contact_org_gstin ON contact(org_id, gstin)
    WHERE gstin IS NOT NULL AND NOT is_deleted;
CREATE INDEX        idx_contact_default_pl ON contact(default_price_list_id)
    WHERE default_price_list_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 2. Contact person  (multiple people per contact)
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
-- 3. Data migration: copy customer rows into contact
--    UUIDs are preserved so contact_id = customer_id for all
--    existing documents.
-- ─────────────────────────────────────────────────────────────
INSERT INTO contact (
    id, org_id, contact_type, display_name,
    gstin, pan, tax_id,
    email, phone,
    billing_address_line1, billing_address_line2,
    billing_city, billing_state, billing_state_code,
    billing_postal_code, billing_country,
    shipping_address_line1, shipping_address_line2,
    shipping_city, shipping_state, shipping_state_code,
    shipping_postal_code, shipping_country,
    credit_limit, payment_terms_days,
    default_price_list_id,
    notes, is_active, is_deleted, created_at, updated_at, created_by
)
SELECT
    id, org_id, 'CUSTOMER', name,
    gstin, pan, tax_id,
    email, phone,
    billing_address_line1, billing_address_line2,
    billing_city, billing_state, billing_state_code,
    billing_postal_code, billing_country,
    shipping_address_line1, shipping_address_line2,
    shipping_city, shipping_state, shipping_state_code,
    shipping_postal_code, shipping_country,
    credit_limit, payment_terms_days,
    default_price_list_id,
    notes, is_active, is_deleted, created_at, updated_at, created_by
FROM customer;


-- ─────────────────────────────────────────────────────────────
-- 4. Add contact_id to AR documents (nullable — old rows get
--    backfilled; new rows use contact_id going forward)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE invoice     ADD COLUMN contact_id UUID REFERENCES contact(id);
ALTER TABLE payment     ADD COLUMN contact_id UUID REFERENCES contact(id);
ALTER TABLE credit_note ADD COLUMN contact_id UUID REFERENCES contact(id);

UPDATE invoice     SET contact_id = customer_id;
UPDATE payment     SET contact_id = customer_id;
UPDATE credit_note SET contact_id = customer_id;

CREATE INDEX idx_invoice_contact     ON invoice(contact_id)     WHERE contact_id IS NOT NULL;
CREATE INDEX idx_payment_contact     ON payment(contact_id)     WHERE contact_id IS NOT NULL;
CREATE INDEX idx_credit_note_contact ON credit_note(contact_id) WHERE contact_id IS NOT NULL;
