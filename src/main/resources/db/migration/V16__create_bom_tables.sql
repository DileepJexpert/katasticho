-- ============================================================================
-- V16: Composite items / Bill of Materials — Sprint 27 (v2 Feature 4)
--
-- Why this migration:
--   v1 items come in two flavours only: GOODS (track stock) and SERVICE
--   (don't). The moment a user sells a "kit" — say a gift hamper
--   containing 2× chocolate boxes + 1× greeting card — they have no way
--   to express that on an invoice without manually adding three lines
--   and then worrying about deducting the right children from stock.
--
--   This migration introduces COMPOSITE items: a parent SKU that is
--   "assembled" from 1..N child items via a new bom_component table.
--   The parent itself is never received into stock and never produces
--   its own stock_movement — at invoice send time InventoryService
--   explodes the BOM and deducts each child according to its configured
--   quantity. Credit notes mirror the restore path so returns are
--   symmetric.
--
-- What this migration does:
--   1. Creates bom_component — one row per (parent, child) pair with a
--      NUMERIC(15,4) quantity. UNIQUE on (parent_item_id, child_item_id)
--      for live rows so the same child can't be added twice to the same
--      parent (operators should edit the quantity instead).
--   2. CHECK constraint: parent_item_id <> child_item_id. Enforces the
--      no-self-reference rule at the DB level.
--   3. Partial unique index ignores soft-deleted rows so a child can be
--      removed and re-added.
--
-- What this migration does NOT do:
--   - Does NOT add is_composite to item — the existing item.item_type
--     enum column already carries that information (the new COMPOSITE
--     value was added in the Java enum alongside this migration). The
--     column is VARCHAR so no ALTER TYPE is required.
--   - Does NOT enforce "child must be GOODS, not COMPOSITE" in SQL.
--     That rule (no nested BOMs in v1) is a service-layer guard — it
--     returns a clearer error, and relaxing the rule in v2 shouldn't
--     require a migration.
--   - Does NOT back-fill any rows. An org with no composite items is
--     unaffected.
--   - Does NOT cascade-delete children when a parent is soft-deleted.
--     The service marks bom_component rows deleted in the same tx as
--     the item.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. BOM component table
--
-- One row per (parent, child) pair. Quantity is NUMERIC(15,4) to match
-- stock_movement.quantity so the explosion math at invoice-send time
-- produces values the ledger can store without rounding.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE bom_component (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    parent_item_id      UUID NOT NULL REFERENCES item(id),
    child_item_id       UUID NOT NULL REFERENCES item(id),
    quantity            NUMERIC(15,4) NOT NULL,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID,

    CONSTRAINT chk_bom_component_no_self_ref
        CHECK (parent_item_id <> child_item_id),

    CONSTRAINT chk_bom_component_positive_qty
        CHECK (quantity > 0)
);

-- A child can only appear once per parent. Operators change the
-- quantity instead of adding a second row. Partial index ignores
-- soft-deleted rows so a removed child can be re-added cleanly.
CREATE UNIQUE INDEX idx_bom_component_unique
    ON bom_component(parent_item_id, child_item_id)
    WHERE NOT is_deleted;

-- Explosion hot path: given a parent item, list every live child row.
-- Called from InventoryService.deductStockForInvoice() once per
-- composite invoice line, so this index is load-bearing.
CREATE INDEX idx_bom_component_parent
    ON bom_component(parent_item_id) WHERE NOT is_deleted;

CREATE INDEX idx_bom_component_org
    ON bom_component(org_id) WHERE NOT is_deleted;
