-- Migration V61: Store Shelf Merchandising & Photo Audits (Step 4.4)
-- Allows field sales representatives to capture shelf photos, facing counts, shelf share %, planogram compliance, and competitor presence.

CREATE TABLE IF NOT EXISTS store_merchandising_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    field_visit_id UUID NOT NULL REFERENCES field_visit(id) ON DELETE CASCADE,
    route_execution_id UUID NOT NULL REFERENCES route_execution(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    audit_type VARCHAR(50) NOT NULL DEFAULT 'PRIMARY_SHELF',
    photo_url TEXT,
    shelf_share_pct NUMERIC(5, 2),
    facing_count INT,
    is_stock_out BOOLEAN NOT NULL DEFAULT FALSE,
    competitor_brand_names TEXT,
    planogram_compliance VARCHAR(30) NOT NULL DEFAULT 'COMPLIANT',
    notes TEXT,
    audited_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_sma_org_exec
    ON store_merchandising_audit (org_id, route_execution_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_sma_org_visit
    ON store_merchandising_audit (org_id, field_visit_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_sma_org_contact
    ON store_merchandising_audit (org_id, contact_id)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_sma_org_salesperson
    ON store_merchandising_audit (org_id, salesperson_id, audited_at)
    WHERE is_deleted = FALSE;
