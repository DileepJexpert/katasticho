-- V23: Drug License & Compliance tracking for pharmacy
CREATE TABLE drug_licenses (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL,
    license_type VARCHAR(50) NOT NULL,  -- DRUG_LICENSE, FSSAI, DEA, WHOLESALE_DRUG, RETAIL_DRUG
    license_number VARCHAR(100) NOT NULL,
    issued_by   VARCHAR(200),
    issue_date  DATE,
    expiry_date DATE NOT NULL,
    notes       TEXT,
    is_deleted  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_drug_licenses_org ON drug_licenses(org_id, is_deleted);
CREATE INDEX idx_drug_licenses_expiry ON drug_licenses(expiry_date) WHERE is_deleted = FALSE;
