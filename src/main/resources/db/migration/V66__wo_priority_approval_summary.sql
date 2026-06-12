-- V66: Work order priority, approval workflow wiring, production summary report support.
--
-- NOTE: work_order.priority was added in V46 and approval_status/approved_by/approved_at
-- in V59, but neither was wired into application logic until now. This migration is a
-- safety net for databases that predate those columns, adds a value guard for priority,
-- and adds the indexes that back priority filtering/sorting and the period-based
-- production summary report.

-- ── Safety net (no-ops on up-to-date databases) ──────────────────────
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS priority VARCHAR(10) DEFAULT 'NORMAL';
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) DEFAULT 'NONE';
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS approved_by UUID;
ALTER TABLE work_order ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- ── Priority value guard ─────────────────────────────────────────────
UPDATE work_order SET priority = 'NORMAL' WHERE priority IS NULL;
ALTER TABLE work_order ALTER COLUMN priority SET DEFAULT 'NORMAL';
ALTER TABLE work_order DROP CONSTRAINT IF EXISTS work_order_priority_check;
ALTER TABLE work_order ADD CONSTRAINT work_order_priority_check
    CHECK (priority IN ('URGENT', 'HIGH', 'NORMAL', 'LOW'));

-- ── Indexes ──────────────────────────────────────────────────────────
-- Priority filter + URGENT-first default sort on the WO list
CREATE INDEX IF NOT EXISTS idx_work_order_org_priority
    ON work_order (org_id, priority)
    WHERE is_deleted = FALSE;

-- Production summary report scans WOs created in a period
CREATE INDEX IF NOT EXISTS idx_work_order_org_created
    ON work_order (org_id, created_at)
    WHERE is_deleted = FALSE;

-- Scrap-by-reason aggregation in the production summary report
CREATE INDEX IF NOT EXISTS idx_production_scrap_org_scrapped_at
    ON production_scrap (org_id, scrapped_at)
    WHERE is_deleted = FALSE;
