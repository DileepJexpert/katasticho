CREATE TABLE manufacturer_master (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL UNIQUE,
    country         VARCHAR(100),
    website         VARCHAR(255),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_manufacturer_master_name ON manufacturer_master(name);

CREATE TABLE hsn_gst_master (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hsn_code        VARCHAR(10) NOT NULL UNIQUE,
    description     VARCHAR(255) NOT NULL,
    category        VARCHAR(100),
    gst_rate        NUMERIC(5,2) NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_hsn_gst_master_code ON hsn_gst_master(hsn_code);

CREATE TABLE rack_location (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    warehouse_id    UUID NOT NULL,
    code            VARCHAR(50) NOT NULL,
    name            VARCHAR(100),
    zone            VARCHAR(50),
    aisle           VARCHAR(50),
    shelf           VARCHAR(50),
    bin             VARCHAR(50),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    CONSTRAINT uq_rack_location_code UNIQUE (org_id, warehouse_id, code)
);

CREATE INDEX idx_rack_location_org_wh ON rack_location(org_id, warehouse_id) WHERE is_deleted = FALSE;

ALTER TABLE item
    ADD COLUMN IF NOT EXISTS rack_location_id UUID REFERENCES rack_location(id);

CREATE TABLE generic_substitution (
    id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drug_master_id             UUID NOT NULL REFERENCES drug_master(id),
    substitute_drug_master_id  UUID NOT NULL REFERENCES drug_master(id),
    reason                     VARCHAR(255),
    estimated_savings          NUMERIC(15,2),
    is_active                  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_generic_substitution_self CHECK (drug_master_id <> substitute_drug_master_id),
    CONSTRAINT uq_generic_substitution_pair UNIQUE (drug_master_id, substitute_drug_master_id)
);

CREATE INDEX idx_generic_substitution_drug ON generic_substitution(drug_master_id);

CREATE TABLE drug_interaction (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    primary_salt_id      UUID NOT NULL REFERENCES salt_master(id),
    interacting_salt_id  UUID NOT NULL REFERENCES salt_master(id),
    severity             VARCHAR(20) NOT NULL,
    warning              TEXT NOT NULL,
    recommendation       TEXT,
    is_active            BOOLEAN NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_drug_interaction_severity CHECK (severity IN ('LOW','MODERATE','HIGH','CRITICAL')),
    CONSTRAINT chk_drug_interaction_self CHECK (primary_salt_id <> interacting_salt_id),
    CONSTRAINT uq_drug_interaction_pair UNIQUE (primary_salt_id, interacting_salt_id)
);

CREATE INDEX idx_drug_interaction_primary ON drug_interaction(primary_salt_id);
CREATE INDEX idx_drug_interaction_interacting ON drug_interaction(interacting_salt_id);

INSERT INTO hsn_gst_master (hsn_code, description, category, gst_rate) VALUES
('3002', 'Human blood, vaccines, toxins and cultures', 'PHARMA', 5),
('3003', 'Medicaments not put up for retail sale', 'PHARMA', 12),
('3004', 'Medicaments put up for retail sale', 'PHARMA', 12),
('3005', 'Wadding, gauze, bandages and similar medical articles', 'PHARMA', 12),
('3006', 'Pharmaceutical goods specified in note 4', 'PHARMA', 12),
('2106', 'Food preparations and supplements', 'SUPPLEMENT', 18),
('9018', 'Medical instruments and appliances', 'MEDICAL_DEVICE', 12)
ON CONFLICT (hsn_code) DO NOTHING;

INSERT INTO manufacturer_master (name)
SELECT DISTINCT TRIM(manufacturer)
FROM drug_master
WHERE manufacturer IS NOT NULL AND TRIM(manufacturer) <> ''
ON CONFLICT (name) DO NOTHING;

INSERT INTO drug_interaction (primary_salt_id, interacting_salt_id, severity, warning, recommendation)
SELECT s1.id, s2.id, 'HIGH',
       'Aspirin with warfarin-like anticoagulants can increase bleeding risk.',
       'Review prescription and advise pharmacist/doctor confirmation before billing.'
FROM salt_master s1, salt_master s2
WHERE LOWER(s1.name) = 'aspirin'
  AND LOWER(s2.name) LIKE 'warfarin%'
ON CONFLICT (primary_salt_id, interacting_salt_id) DO NOTHING;
