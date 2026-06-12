-- BOM enhancements: scrap/yield percentage, phantom BOMs,
-- alternate/substitute materials, co-products/by-products.

-- ── Scrap / yield percentage on BOM lines ────────────────────────────
-- Extra material issued to cover expected process loss. issueToProduction
-- issues requiredQty × (1 + scrap_percent/100) for each component.
ALTER TABLE bom_component
    ADD COLUMN IF NOT EXISTS scrap_percent NUMERIC(5,2) DEFAULT 0;

-- ── Phantom BOM flag on item ─────────────────────────────────────────
-- A phantom is a COMPOSITE that is never stocked or produced on its own:
-- BOM explosion flattens through it, pulling in its own components
-- (scaled by quantity) instead of listing the phantom itself.
ALTER TABLE item
    ADD COLUMN IF NOT EXISTS is_phantom BOOLEAN NOT NULL DEFAULT FALSE;

-- ── Alternate / substitute materials ─────────────────────────────────
-- Registered substitutes for one BOM line. A work-order line can be
-- substituted with one of these while the WO is still DRAFT.
CREATE TABLE IF NOT EXISTS bom_alternate (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID          NOT NULL REFERENCES organisation(id),
    bom_component_id    UUID          NOT NULL REFERENCES bom_component(id),
    alternate_item_id   UUID          NOT NULL REFERENCES item(id),
    priority            INT           NOT NULL DEFAULT 1,
    notes               TEXT,
    is_deleted          BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by          UUID
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bom_alternate_unique
    ON bom_alternate (bom_component_id, alternate_item_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_bom_alternate_component
    ON bom_alternate (bom_component_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_bom_alternate_org
    ON bom_alternate (org_id) WHERE NOT is_deleted;

-- ── Co-products / by-products ────────────────────────────────────────
-- Secondary outputs of producing one unit of parent_item_id. On FG
-- receipt the WO also receives qty × quantity_per_unit of each
-- co-product, costed at total WO cost × cost_allocation_percent/100;
-- the main FG keeps the remaining percentage.
CREATE TABLE IF NOT EXISTS bom_co_product (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID          NOT NULL REFERENCES organisation(id),
    parent_item_id          UUID          NOT NULL REFERENCES item(id),
    co_product_item_id      UUID          NOT NULL REFERENCES item(id),
    quantity_per_unit       NUMERIC(15,4) NOT NULL,
    cost_allocation_percent NUMERIC(5,2)  NOT NULL DEFAULT 0,
    is_deleted              BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by              UUID,
    CONSTRAINT chk_bom_co_product_no_self_ref   CHECK (parent_item_id <> co_product_item_id),
    CONSTRAINT chk_bom_co_product_positive_qty  CHECK (quantity_per_unit > 0),
    CONSTRAINT chk_bom_co_product_pct_range     CHECK (cost_allocation_percent >= 0 AND cost_allocation_percent <= 100)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_bom_co_product_unique
    ON bom_co_product (parent_item_id, co_product_item_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_bom_co_product_parent
    ON bom_co_product (org_id, parent_item_id) WHERE NOT is_deleted;
CREATE INDEX IF NOT EXISTS idx_bom_co_product_org
    ON bom_co_product (org_id) WHERE NOT is_deleted;
