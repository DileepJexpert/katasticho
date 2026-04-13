-- ============================================================================
-- V15: Price lists + tiered pricing — Sprint 26 (v2 Feature 3)
--
-- Why this migration:
--   v1 invoices trust the client-supplied unitPrice on every line — there's
--   no server-side way to say "customer X always gets wholesale pricing"
--   or "order 100+ of this SKU and the price drops from 45 to 40". The
--   Flutter app just reads item.sale_price and sends it back. That's OK
--   for single-proprietor shops but falls apart the moment the user
--   manages a distributor/retail split or runs quantity breaks.
--
--   This migration introduces a price list layer that sits BETWEEN
--   item.sale_price (the base) and the invoice line (the outcome). The
--   resolution chain at invoice-create time becomes:
--
--      explicit line.unitPrice (if set by client AND no price list hit)
--         → customer.default_price_list_id lookup
--            → org default price_list (is_default = true)
--               → item.sale_price (fallback)
--
--   Each price list carries its own currency (so a USD export price list
--   can coexist with an INR retail list), and each row carries a
--   min_quantity column so a single (list, item) pair can have multiple
--   tiers — the service picks the row with the highest min_quantity
--   whose min_quantity <= ordered quantity.
--
-- What this migration does:
--   1. Creates price_list — the header table, org-scoped, with
--      is_default UNIQUE per org (partial index).
--   2. Creates price_list_item — one row per (list, item, tier). UNIQUE
--      on (price_list_id, item_id, min_quantity) so tiers don't
--      overlap.
--   3. Adds default_price_list_id FK to customer (nullable — customers
--      without an assigned list fall through to org default → item
--      sale_price).
--
-- What this migration does NOT do:
--   - Does NOT touch invoice_line. The resolver is service-side only;
--     the line still stores the frozen unit_price that was applied at
--     create time (so changing a price list later never back-dates
--     historical invoices).
--   - Does NOT seed any rows. An org with no price lists behaves
--     identically to pre-V15 — the resolver short-circuits and falls
--     through to item.sale_price.
--   - Does NOT enforce any constraints on price sign or currency code
--     beyond the basic NUMERIC / VARCHAR(3) types. The service layer
--     rejects negative prices and unknown currencies.
-- ============================================================================


-- ────────────────────────────────────────────────────────────────────────────
-- 1. Price list header
--
-- One row per named list per org. currency is stored here (not on
-- price_list_item) so a list can't mix currencies by accident. is_default
-- is UNIQUE per org via a partial index so an org can't have two default
-- lists — if you set a second list as default the service layer flips
-- the old one off first inside the same tx.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE price_list (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    name                VARCHAR(100) NOT NULL,
    description         TEXT,
    currency            VARCHAR(3) NOT NULL DEFAULT 'INR',
    is_default          BOOLEAN NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID
);

-- One default list per org, ignoring soft-deleted rows.
CREATE UNIQUE INDEX idx_price_list_org_default
    ON price_list(org_id)
    WHERE is_default AND NOT is_deleted;

-- Name is unique within an org (partial, ignores soft-deleted rows so
-- you can recreate a deleted list with the same name).
CREATE UNIQUE INDEX idx_price_list_org_name
    ON price_list(org_id, name)
    WHERE NOT is_deleted;

CREATE INDEX idx_price_list_org
    ON price_list(org_id) WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 2. Price list line item (with tier support)
--
-- UNIQUE (price_list_id, item_id, min_quantity) lets one item appear
-- multiple times per list — once per tier. The resolver picks the row
-- with the HIGHEST min_quantity ≤ requested quantity, so:
--
--   item 'WIDGET' in list 'WHOLESALE':
--     min_quantity=1   price=50
--     min_quantity=10  price=45
--     min_quantity=100 price=40
--
--   order 5  → 50, order 10 → 45, order 250 → 40
--
-- min_quantity defaults to 1 (not 0) so every row is reachable. The
-- service rejects min_quantity <= 0 with a 400.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE price_list_item (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    price_list_id       UUID NOT NULL REFERENCES price_list(id),
    item_id             UUID NOT NULL REFERENCES item(id),
    min_quantity        NUMERIC(15,4) NOT NULL DEFAULT 1,
    price               NUMERIC(15,4) NOT NULL,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID
);

CREATE UNIQUE INDEX idx_price_list_item_unique
    ON price_list_item(price_list_id, item_id, min_quantity)
    WHERE NOT is_deleted;

-- The resolver's hot path: given a (list, item) pair find all tiers
-- ordered by min_quantity so it can walk from highest to lowest and
-- pick the first one that fits.
CREATE INDEX idx_price_list_item_lookup
    ON price_list_item(price_list_id, item_id, min_quantity DESC)
    WHERE NOT is_deleted;

CREATE INDEX idx_price_list_item_org
    ON price_list_item(org_id) WHERE NOT is_deleted;


-- ────────────────────────────────────────────────────────────────────────────
-- 3. Customer → default price list
--
-- Nullable FK — customers without a pinned list still get org-default
-- pricing via the resolver's chain. Setting this column does NOT cascade
-- to any existing invoice; only newly created invoice lines consult it.
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE customer
    ADD COLUMN default_price_list_id UUID REFERENCES price_list(id);

CREATE INDEX idx_customer_default_price_list
    ON customer(default_price_list_id) WHERE default_price_list_id IS NOT NULL;
