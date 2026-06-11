-- FIFO valuation: per-receipt cost lots consumed oldest-first on issue.
--
-- The org setting `inventory.valuation_method` already existed (default FIFO)
-- but the engine silently did weighted-average. These two tables make FIFO
-- real WITHOUT touching the immutable stock_movement ledger: each incoming
-- movement opens a `cost_lot`; each outgoing movement consumes open lots
-- oldest-first and records the allocation in `cost_lot_consumption`. The
-- true FIFO cost is baked into stock_movement.unit_cost/total_cost at insert
-- time (computed before the row is built), so every cost report stays correct.
--
-- Weighted-average orgs (valuation_method <> FIFO) never touch these tables.

CREATE TABLE cost_lot (
    id                 UUID PRIMARY KEY,
    org_id             UUID NOT NULL,
    item_id            UUID NOT NULL,
    warehouse_id       UUID NOT NULL,
    -- The incoming movement that opened this lot. NULL for a lazily-seeded
    -- opening lot (stock that existed before FIFO tracking began).
    source_movement_id UUID,
    received_date      DATE NOT NULL,
    original_qty       NUMERIC(15,4) NOT NULL,
    remaining_qty      NUMERIC(15,4) NOT NULL,
    unit_cost          NUMERIC(15,4) NOT NULL DEFAULT 0,
    is_active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by         UUID
);

-- FIFO consumption order: oldest received_date first, then insertion order.
CREATE INDEX idx_cost_lot_fifo
    ON cost_lot(org_id, item_id, warehouse_id, received_date, created_at)
    WHERE is_active;

CREATE INDEX idx_cost_lot_source ON cost_lot(source_movement_id)
    WHERE source_movement_id IS NOT NULL;

CREATE TABLE cost_lot_consumption (
    id          UUID PRIMARY KEY,
    org_id      UUID NOT NULL,
    lot_id      UUID NOT NULL,
    -- The outgoing stock_movement that consumed this slice of the lot.
    movement_id UUID NOT NULL,
    qty         NUMERIC(15,4) NOT NULL,
    unit_cost   NUMERIC(15,4) NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_cost_lot_consumption_movement ON cost_lot_consumption(movement_id);
CREATE INDEX idx_cost_lot_consumption_lot ON cost_lot_consumption(lot_id);
