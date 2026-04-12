-- ============================================================================
-- V8: Inventory module — Sprint 25 (Core)
--
-- Mirrors the accounting "single posting gate" pattern:
--   stock_movement is the immutable append-only ledger (like journal_line)
--   stock_balance  is a denormalised cache (like an account balance)
--
-- Source of truth is ALWAYS SUM(stock_movement.quantity). The cache exists
-- only for fast list/dashboard queries; a nightly job verifies it.
--
-- Tables created:
--   item, warehouse, stock_movement, stock_balance,
--   stock_count, stock_count_line
--
-- Trigger: prevent_stock_movement_mutation() — same defensive posture as
-- prevent_journal_entry_update(). Even if app code has bugs, the database
-- refuses to mutate a posted movement.
--
-- Also alters invoice_line to add nullable item_id / batch_id (free-text
-- lines remain valid; itemised lines flow through inventory).
-- ============================================================================

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Item master
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE item (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    sku             VARCHAR(50) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    item_type       VARCHAR(20) NOT NULL DEFAULT 'GOODS'
                    CHECK (item_type IN ('GOODS','SERVICE')),
    -- Classification
    category        VARCHAR(100),
    brand           VARCHAR(100),
    hsn_code        VARCHAR(10),
    unit_of_measure VARCHAR(20) NOT NULL DEFAULT 'PCS',
    -- Pricing (in org base currency for v1)
    purchase_price  NUMERIC(15,2) NOT NULL DEFAULT 0,
    sale_price      NUMERIC(15,2) NOT NULL DEFAULT 0,
    mrp             NUMERIC(15,2),
    -- Tax
    gst_rate        NUMERIC(5,2) NOT NULL DEFAULT 0,
    -- Inventory control
    track_inventory BOOLEAN NOT NULL DEFAULT TRUE,   -- FALSE for SERVICE items
    reorder_level   NUMERIC(12,4) NOT NULL DEFAULT 0,
    reorder_quantity NUMERIC(12,4) NOT NULL DEFAULT 0,
    -- Default revenue / COGS / inventory accounts (CoA codes)
    revenue_account_code   VARCHAR(20),
    cogs_account_code      VARCHAR(20),
    inventory_account_code VARCHAR(20),
    -- Lifecycle
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_item_org_sku ON item(org_id, sku) WHERE NOT is_deleted;
CREATE INDEX idx_item_org_name ON item(org_id, name) WHERE NOT is_deleted;
CREATE INDEX idx_item_org_category ON item(org_id, category) WHERE NOT is_deleted;
CREATE INDEX idx_item_org_active ON item(org_id, is_active) WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Warehouse master
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE warehouse (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    code            VARCHAR(20) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    address_line1   VARCHAR(255),
    address_line2   VARCHAR(255),
    city            VARCHAR(100),
    state           VARCHAR(100),
    state_code      VARCHAR(5),
    postal_code     VARCHAR(20),
    country         VARCHAR(2) DEFAULT 'IN',
    is_default      BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_warehouse_org_code ON warehouse(org_id, code) WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_warehouse_org_default ON warehouse(org_id) WHERE is_default AND NOT is_deleted;
CREATE INDEX idx_warehouse_org ON warehouse(org_id) WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Stock movement — IMMUTABLE APPEND-ONLY LEDGER
--    (mirrors journal_line; corrections via reverse movements only)
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE stock_movement (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    item_id         UUID NOT NULL REFERENCES item(id),
    warehouse_id    UUID NOT NULL REFERENCES warehouse(id),
    -- Bitemporality: business time vs system time
    movement_date   DATE NOT NULL,                   -- effective_date (LocalDate)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),  -- system time
    -- Movement classification
    movement_type   VARCHAR(20) NOT NULL
                    CHECK (movement_type IN (
                        'PURCHASE','SALE','ADJUSTMENT','TRANSFER_IN','TRANSFER_OUT',
                        'OPENING','RETURN_IN','RETURN_OUT','STOCK_COUNT','REVERSAL'
                    )),
    -- Quantity: SIGNED. Positive = stock in, negative = stock out.
    -- Cost: per-unit cost in base currency at time of movement (for COGS).
    quantity        NUMERIC(15,4) NOT NULL,
    unit_cost       NUMERIC(15,4) NOT NULL DEFAULT 0,
    total_cost      NUMERIC(15,2) NOT NULL DEFAULT 0,  -- quantity * unit_cost
    -- Source linkage (which document created this movement?)
    reference_type  VARCHAR(30)
                    CHECK (reference_type IN (
                        'INVOICE','CREDIT_NOTE','BILL','DEBIT_NOTE',
                        'STOCK_ADJUSTMENT','STOCK_TRANSFER','STOCK_COUNT','OPENING_BALANCE'
                    )),
    reference_id    UUID,                             -- e.g. invoice.id
    reference_number VARCHAR(50),                     -- denormalised for display
    -- Reversal tracking (immutability rules: never UPDATE quantity / type;
    -- only allowed transition is is_reversed FALSE -> TRUE)
    is_reversal     BOOLEAN NOT NULL DEFAULT FALSE,
    reversal_of_id  UUID REFERENCES stock_movement(id),
    is_reversed     BOOLEAN NOT NULL DEFAULT FALSE,
    -- Free-text metadata
    notes           TEXT,
    created_by      UUID
);

CREATE INDEX idx_stock_movement_item ON stock_movement(org_id, item_id, movement_date);
CREATE INDEX idx_stock_movement_warehouse ON stock_movement(org_id, warehouse_id, movement_date);
CREATE INDEX idx_stock_movement_reference ON stock_movement(reference_type, reference_id);
CREATE INDEX idx_stock_movement_org_date ON stock_movement(org_id, movement_date);
CREATE INDEX idx_stock_movement_org_type ON stock_movement(org_id, movement_type);


-- ────────────────────────────────────────────────────────────────────────────
-- 4. Stock balance — DENORMALISED CACHE
--    Source of truth is SUM(stock_movement.quantity); this exists for speed.
--    Updated synchronously inside InventoryService.recordMovement().
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE stock_balance (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    item_id         UUID NOT NULL REFERENCES item(id),
    warehouse_id    UUID NOT NULL REFERENCES warehouse(id),
    quantity_on_hand NUMERIC(15,4) NOT NULL DEFAULT 0,
    -- Weighted average cost (recomputed on every PURCHASE / OPENING)
    average_cost    NUMERIC(15,4) NOT NULL DEFAULT 0,
    last_movement_at TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_stock_balance_item_wh
    ON stock_balance(org_id, item_id, warehouse_id);
CREATE INDEX idx_stock_balance_org_wh ON stock_balance(org_id, warehouse_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 5. Stock count (physical inventory) header + lines
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE stock_count (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    warehouse_id    UUID NOT NULL REFERENCES warehouse(id),
    count_number    VARCHAR(30) NOT NULL,
    count_date      DATE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                    CHECK (status IN ('DRAFT','POSTED','CANCELLED')),
    notes           TEXT,
    posted_at       TIMESTAMPTZ,
    posted_by       UUID,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE UNIQUE INDEX idx_stock_count_org_number ON stock_count(org_id, count_number) WHERE NOT is_deleted;
CREATE INDEX idx_stock_count_org ON stock_count(org_id, count_date);

CREATE TABLE stock_count_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_count_id      UUID NOT NULL REFERENCES stock_count(id) ON DELETE CASCADE,
    item_id             UUID NOT NULL REFERENCES item(id),
    expected_quantity   NUMERIC(15,4) NOT NULL DEFAULT 0,
    counted_quantity    NUMERIC(15,4) NOT NULL DEFAULT 0,
    variance            NUMERIC(15,4) NOT NULL DEFAULT 0,  -- counted - expected
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_stock_count_line_count ON stock_count_line(stock_count_id);


-- ────────────────────────────────────────────────────────────────────────────
-- 6. Stock movement immutability triggers
--    (mirrors V4 journal entry triggers)
-- ────────────────────────────────────────────────────────────────────────────

-- 6a. Block UPDATE on quantity, type, dates etc. — only is_reversed
--     may flip from FALSE to TRUE.
CREATE OR REPLACE FUNCTION prevent_stock_movement_mutation()
RETURNS TRIGGER AS $$
BEGIN
    -- Allow exactly one transition: marking a movement as reversed.
    IF OLD.is_reversed = FALSE AND NEW.is_reversed = TRUE
       AND NEW.quantity = OLD.quantity
       AND NEW.unit_cost = OLD.unit_cost
       AND NEW.total_cost = OLD.total_cost
       AND NEW.movement_type = OLD.movement_type
       AND NEW.movement_date = OLD.movement_date
       AND NEW.item_id = OLD.item_id
       AND NEW.warehouse_id = OLD.warehouse_id
       AND NEW.org_id = OLD.org_id THEN
        RETURN NEW;
    END IF;

    -- Block any other modification.
    IF NEW.quantity != OLD.quantity
       OR NEW.unit_cost != OLD.unit_cost
       OR NEW.movement_type != OLD.movement_type
       OR NEW.movement_date != OLD.movement_date
       OR NEW.item_id != OLD.item_id
       OR NEW.warehouse_id != OLD.warehouse_id
       OR NEW.org_id != OLD.org_id THEN
        RAISE EXCEPTION 'Cannot modify posted stock_movement % — record a reversal instead', OLD.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_movement_immutable
BEFORE UPDATE ON stock_movement
FOR EACH ROW EXECUTE FUNCTION prevent_stock_movement_mutation();

-- 6b. Block DELETE outright. Reversals are the only correction mechanism.
CREATE OR REPLACE FUNCTION prevent_stock_movement_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Cannot delete stock_movement % — record a reversal instead', OLD.id;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_movement_no_delete
BEFORE DELETE ON stock_movement
FOR EACH ROW EXECUTE FUNCTION prevent_stock_movement_delete();


-- ────────────────────────────────────────────────────────────────────────────
-- 7. Helper: compute current on-hand from the ledger (canonical query)
--    Used by the nightly cache verification job and integration tests.
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_item_balance(
    p_item_id      UUID,
    p_warehouse_id UUID,
    p_org_id       UUID,
    p_as_of_date   DATE DEFAULT CURRENT_DATE
) RETURNS NUMERIC(15,4) AS $$
DECLARE
    v_balance NUMERIC(15,4);
BEGIN
    SELECT COALESCE(SUM(quantity), 0)
    INTO v_balance
    FROM stock_movement
    WHERE org_id = p_org_id
      AND item_id = p_item_id
      AND warehouse_id = p_warehouse_id
      AND movement_date <= p_as_of_date;
    RETURN v_balance;
END;
$$ LANGUAGE plpgsql;


-- ────────────────────────────────────────────────────────────────────────────
-- 8. Extend invoice_line with optional item linkage
--    Free-text invoice lines (item_id NULL) remain fully valid for backward
--    compatibility — only invoice lines with item_id participate in inventory.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE invoice_line
    ADD COLUMN item_id  UUID REFERENCES item(id),
    ADD COLUMN batch_id UUID;  -- FK added in Sprint 26 when batch table exists

CREATE INDEX idx_invoice_line_item ON invoice_line(item_id) WHERE item_id IS NOT NULL;

-- Same extension for credit note lines so returns can restore stock.
ALTER TABLE credit_note_line
    ADD COLUMN item_id  UUID REFERENCES item(id),
    ADD COLUMN batch_id UUID;

CREATE INDEX idx_credit_note_line_item ON credit_note_line(item_id) WHERE item_id IS NOT NULL;
