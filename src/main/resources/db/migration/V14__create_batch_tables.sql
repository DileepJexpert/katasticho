-- ============================================================================
-- V14: Batch / lot master + FEFO foundation — Sprint 26 (v2 Feature 2)
--
-- Why this migration:
--   v1 inventory treated "batch_number" and "expiry_date" as free-text
--   strings on stock_receipt_line and left dangling batch_id columns on
--   invoice_line / credit_note_line as placeholders. That was enough to
--   print the batch on the invoice PDF but NOT enough to enforce
--   First-Expiry-First-Out (FEFO) picking on sale, or to track remaining
--   quantity per batch so near-expiry stock can be flagged.
--
--   This migration turns those placeholders into a real batch master and
--   introduces a per-batch / per-warehouse balance so FEFO queries are a
--   single indexed lookup.
--
-- What this migration does:
--   1. Creates stock_batch — the batch master (org-scoped, one row per
--      distinct batch received). batch_number is UNIQUE within (org, item)
--      so re-receiving the same batch number from the same supplier adds
--      qty to the existing batch instead of creating a duplicate.
--   2. Creates stock_batch_balance — per (org, batch, warehouse). This is
--      the grain FEFO picking queries against. stock_balance stays
--      item×warehouse aggregated; stock_batch_balance is a sub-grain that
--      sums back to it.
--   3. Adds batch_id to stock_movement as a nullable FK. Existing rows
--      (pre-V14) keep batch_id NULL and continue to work unchanged.
--   4. Backfills the dangling batch_id FK on invoice_line / credit_note_line
--      to reference stock_batch(id). Columns already exist from V8.
--   5. Adds FK on stock_receipt_line.batch_id (the placeholder from V10).
--   6. Adds track_batches to item (default FALSE). Only items with this
--      flag participate in FEFO deduction; everything else uses the v1
--      item×warehouse aggregate path and is untouched.
--
-- What this migration does NOT do:
--   - It does NOT migrate existing stock_receipt_line.batch_number strings
--     into stock_batch rows. Pre-V14 receipts stay as loose strings; new
--     receipts after V14 create batch rows via BatchService. A follow-up
--     data job can backfill historical batches if the business cares.
--   - It does NOT enforce NOT NULL on stock_movement.batch_id for
--     track_batches items. The service layer enforces that contract — the
--     DB allows NULL so legacy rows still validate.
--   - It does NOT rebuild the stock_movement immutability trigger. The
--     V8 trigger already blocks UPDATE/DELETE on every column including
--     the new batch_id — nothing to change.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. Batch master
--
-- One row per distinct batch the org has received. Keyed on
-- (org_id, item_id, batch_number) so the same batch number can exist for
-- different items (e.g. "LOT-2024-A" from two different suppliers for
-- two different SKUs) without collision.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE stock_batch (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    item_id             UUID NOT NULL REFERENCES item(id),
    batch_number        VARCHAR(100) NOT NULL,
    expiry_date         DATE,
    manufacturing_date  DATE,
    -- Original purchase cost — FEFO deduction copies this into
    -- stock_movement.unit_cost so COGS is calculated at the batch's
    -- own landed cost, not the item's moving average.
    unit_cost           NUMERIC(15,4) NOT NULL DEFAULT 0,
    -- First supplier who brought this batch in — nullable because adjustments
    -- and opening balances don't always have a supplier.
    supplier_id         UUID REFERENCES supplier(id),
    -- Free-form notes (country of origin, GRN reference, etc.)
    notes               TEXT,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID
);

-- Uniqueness: one batch row per (org, item, batch_number). Partial index so
-- soft-deleted rows don't block recreation of a batch that was mistakenly
-- deleted.
CREATE UNIQUE INDEX idx_stock_batch_org_item_number
    ON stock_batch(org_id, item_id, batch_number)
    WHERE NOT is_deleted;

-- FEFO hot path: "find all non-expired, active batches for this item
-- ordered by expiry_date ASC". NULL expiry sorts last (NULLS LAST) because
-- batches without an expiry should never be consumed before a dated one.
CREATE INDEX idx_stock_batch_fefo
    ON stock_batch(org_id, item_id, expiry_date NULLS LAST)
    WHERE is_active AND NOT is_deleted;

CREATE INDEX idx_stock_batch_org_item
    ON stock_batch(org_id, item_id) WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Per-batch per-warehouse balance
--
-- This is the grain the FEFO picker reads. Each row tracks
-- quantity_on_hand for a specific (batch, warehouse) pair. Sum over
-- warehouses = remaining batch quantity; sum over batches for an item =
-- the same total as stock_balance.quantity_on_hand (the aggregate stays
-- authoritative for non-batch-aware callers).
--
-- Updated synchronously inside InventoryService.recordMovement() alongside
-- the existing stock_balance cache write.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE stock_batch_balance (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    batch_id            UUID NOT NULL REFERENCES stock_batch(id),
    warehouse_id        UUID NOT NULL REFERENCES warehouse(id),
    quantity_on_hand    NUMERIC(15,4) NOT NULL DEFAULT 0,
    last_movement_at    TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_stock_batch_balance_unique
    ON stock_batch_balance(org_id, batch_id, warehouse_id);

-- FEFO lookup joins stock_batch → stock_batch_balance by batch_id. A plain
-- index on batch_id is enough; the FEFO ORDER BY happens on stock_batch.
CREATE INDEX idx_stock_batch_balance_batch
    ON stock_batch_balance(batch_id);

CREATE INDEX idx_stock_batch_balance_warehouse
    ON stock_batch_balance(org_id, warehouse_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Wire stock_movement to stock_batch
--
-- The ledger gains an optional batch_id pointer. NULL means "non-batch
-- movement" (service items, items without track_batches, or pre-V14 rows).
-- The column is added with NO default and NO constraint change because
-- the V8 immutability trigger already blocks UPDATE/DELETE on every
-- column — the new column inherits that protection.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE stock_movement
    ADD COLUMN batch_id UUID REFERENCES stock_batch(id);

CREATE INDEX idx_stock_movement_batch
    ON stock_movement(batch_id) WHERE batch_id IS NOT NULL;


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Promote the invoice_line / credit_note_line placeholders to real FKs
--
-- V8 left these columns as bare UUIDs with a comment "FK added in
-- Sprint 26 when batch table exists". That sprint is this one.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE invoice_line
    ADD CONSTRAINT fk_invoice_line_batch
    FOREIGN KEY (batch_id) REFERENCES stock_batch(id);

CREATE INDEX idx_invoice_line_batch
    ON invoice_line(batch_id) WHERE batch_id IS NOT NULL;

ALTER TABLE credit_note_line
    ADD CONSTRAINT fk_credit_note_line_batch
    FOREIGN KEY (batch_id) REFERENCES stock_batch(id);

CREATE INDEX idx_credit_note_line_batch
    ON credit_note_line(batch_id) WHERE batch_id IS NOT NULL;


-- ────────────────────────────────────────────────────────────────────────────
-- 5. Promote the stock_receipt_line placeholder to a real FK
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE stock_receipt_line
    ADD CONSTRAINT fk_stock_receipt_line_batch
    FOREIGN KEY (batch_id) REFERENCES stock_batch(id);

CREATE INDEX idx_stock_receipt_line_batch
    ON stock_receipt_line(batch_id) WHERE batch_id IS NOT NULL;


-- ────────────────────────────────────────────────────────────────────────────
-- 6. track_batches flag on item master
--
-- Default FALSE so every existing item continues to use the v1 aggregate
-- path unchanged. Turning this flag on for an item is a forward-only
-- decision — the service layer enforces that you can't toggle it off
-- while the item still has batch_balance > 0, but enforcement lives in
-- ItemService, not here.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE item
    ADD COLUMN track_batches BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX idx_item_track_batches
    ON item(org_id) WHERE track_batches AND NOT is_deleted;
