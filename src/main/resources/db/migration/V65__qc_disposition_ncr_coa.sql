-- V65: QC disposition workflow + Non-Conformance Reports (CoA is JSON-only, no schema)

-- ===== 1. QC INSPECTION DISPOSITION =====
-- accepted_qty / rejected_qty already exist on qc_inspection (V46) and are
-- reused as the authoritative disposition split; only the new columns are added.
ALTER TABLE qc_inspection ADD COLUMN IF NOT EXISTS disposition VARCHAR(10);
ALTER TABLE qc_inspection ADD COLUMN IF NOT EXISTS hold_qty NUMERIC(15,4);
ALTER TABLE qc_inspection ADD COLUMN IF NOT EXISTS quarantine_zone_id UUID;
ALTER TABLE qc_inspection ADD COLUMN IF NOT EXISTS disposition_notes TEXT;
ALTER TABLE qc_inspection ADD COLUMN IF NOT EXISTS disposition_at TIMESTAMPTZ;
ALTER TABLE qc_inspection ADD COLUMN IF NOT EXISTS disposition_by UUID;

-- ===== 2. NON-CONFORMANCE REPORT =====
CREATE TABLE IF NOT EXISTS non_conformance_report (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id            UUID NOT NULL,
    ncr_number        VARCHAR(30) NOT NULL,
    qc_inspection_id  UUID REFERENCES qc_inspection(id),
    item_id           UUID NOT NULL,
    batch_number      VARCHAR(100),
    severity          VARCHAR(10) NOT NULL DEFAULT 'MAJOR',
    reason            VARCHAR(500),
    description       TEXT,
    status            VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    corrective_action TEXT,
    root_cause        TEXT,
    closed_at         TIMESTAMPTZ,
    closed_by         UUID,
    is_deleted        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by        UUID
);
CREATE INDEX IF NOT EXISTS idx_ncr_org_status ON non_conformance_report(org_id, status) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_ncr_inspection ON non_conformance_report(qc_inspection_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_ncr_item ON non_conformance_report(item_id) WHERE NOT is_deleted;
