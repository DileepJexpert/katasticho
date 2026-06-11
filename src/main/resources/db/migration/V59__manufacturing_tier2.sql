-- Manufacturing Tier 2: BOM versioning, batch traceability, WIP journals,
-- production reports, work order enhancements, backflush mode.

-- ── BOM versioning ───────────────────────────────────────────────────
ALTER TABLE bom_component
    ADD COLUMN IF NOT EXISTS version         INT DEFAULT 1,
    ADD COLUMN IF NOT EXISTS effective_from   DATE,
    ADD COLUMN IF NOT EXISTS effective_to     DATE,
    ADD COLUMN IF NOT EXISTS change_notes     TEXT;

-- ── Work order enhancements ──────────────────────────────────────────
ALTER TABLE work_order
    ADD COLUMN IF NOT EXISTS journal_entry_id      UUID,
    ADD COLUMN IF NOT EXISTS wip_journal_entry_id  UUID,
    ADD COLUMN IF NOT EXISTS backflush_mode         BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS bom_version            INT,
    ADD COLUMN IF NOT EXISTS approval_status        VARCHAR(20) DEFAULT 'NONE',
    ADD COLUMN IF NOT EXISTS approved_by            UUID,
    ADD COLUMN IF NOT EXISTS approved_at            TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_disassembly         BOOLEAN DEFAULT FALSE;

-- ── Batch traceability on WO lines ──────────────────────────────────
ALTER TABLE work_order_line
    ADD COLUMN IF NOT EXISTS batch_id  UUID,
    ADD COLUMN IF NOT EXISTS batch_number VARCHAR(50);

-- ── WIP + Manufacturing accounts in CoA ─────────────────────────────
INSERT INTO coa_template (industry, code, name, type, sub_type, level)
VALUES
    ('TRADING', '1210', 'Work-In-Progress', 'ASSET', 'CURRENT_ASSET', 2),
    ('TRADING', '5030', 'Manufacturing Overhead', 'EXPENSE', 'COGS', 2),
    ('TRADING', '5040', 'Direct Labor', 'EXPENSE', 'COGS', 2),
    ('TRADING', '5050', 'Material Variance', 'EXPENSE', 'COGS', 2)
ON CONFLICT DO NOTHING;

-- Seed these accounts for existing orgs that have the TRADING CoA
INSERT INTO account (id, org_id, code, name, type, sub_type, level, system, is_deleted, created_at, updated_at)
SELECT gen_random_uuid(), a.org_id, t.code, t.name, t.type, t.sub_type, t.level, TRUE, FALSE, NOW(), NOW()
FROM coa_template t
CROSS JOIN (SELECT DISTINCT org_id FROM account WHERE is_deleted = FALSE) a
WHERE t.code IN ('1210', '5030', '5040', '5050')
  AND t.industry = 'TRADING'
  AND NOT EXISTS (
    SELECT 1 FROM account x
    WHERE x.org_id = a.org_id AND x.code = t.code AND x.is_deleted = FALSE
  );

-- ── Production cost summary view (for reports) ──────────────────────
CREATE TABLE IF NOT EXISTS production_cost_summary (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL,
    work_order_id       UUID NOT NULL REFERENCES work_order(id),
    work_order_number   VARCHAR(30) NOT NULL,
    finished_good_id    UUID NOT NULL,
    planned_rm_cost     NUMERIC(15,2) DEFAULT 0,
    actual_rm_cost      NUMERIC(15,2) DEFAULT 0,
    planned_labor_cost  NUMERIC(15,2) DEFAULT 0,
    actual_labor_cost   NUMERIC(15,2) DEFAULT 0,
    planned_overhead    NUMERIC(15,2) DEFAULT 0,
    actual_overhead     NUMERIC(15,2) DEFAULT 0,
    planned_total       NUMERIC(15,2) DEFAULT 0,
    actual_total        NUMERIC(15,2) DEFAULT 0,
    material_variance   NUMERIC(15,2) DEFAULT 0,
    labor_variance      NUMERIC(15,2) DEFAULT 0,
    overhead_variance   NUMERIC(15,2) DEFAULT 0,
    total_variance      NUMERIC(15,2) DEFAULT 0,
    planned_qty         NUMERIC(15,4) DEFAULT 0,
    produced_qty        NUMERIC(15,4) DEFAULT 0,
    scrap_qty           NUMERIC(15,4) DEFAULT 0,
    yield_percentage    NUMERIC(5,2) DEFAULT 0,
    completed_at        TIMESTAMPTZ,
    is_deleted          BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_prod_cost_summary_org
    ON production_cost_summary (org_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_prod_cost_summary_wo
    ON production_cost_summary (work_order_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_prod_cost_summary_fg
    ON production_cost_summary (org_id, finished_good_id) WHERE NOT is_deleted;

-- ── Indexes for new columns ──────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_bom_component_version
    ON bom_component (org_id, parent_item_id, version) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_work_order_journal
    ON work_order (journal_entry_id) WHERE journal_entry_id IS NOT NULL;
