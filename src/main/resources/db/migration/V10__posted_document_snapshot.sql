CREATE TABLE posted_document_snapshot (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    document_type VARCHAR(50) NOT NULL,
    document_id UUID NOT NULL,
    document_number VARCHAR(80),
    snapshot_json JSONB NOT NULL,
    snapshot_hash VARCHAR(128),
    posted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    posted_by UUID,
    UNIQUE(document_type, document_id)
);

CREATE INDEX idx_posted_document_snapshot_org_type
    ON posted_document_snapshot(org_id, document_type);
