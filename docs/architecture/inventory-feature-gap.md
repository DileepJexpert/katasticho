# Inventory Module — Feature Gap Analysis & Expansion Plan

**Status:** Planning
**Owner:** Engineering
**Last updated:** 2026-04-12

This document compares the current Katasticho inventory module against
Zoho Inventory's feature surface, identifies gaps, and lays out a sprint
plan to reach full parity while retaining our architectural advantages
(append-only ledger, single movement gate, event sourcing, bitemporality,
offline-first, AI-native).

## TL;DR

- **Architecture is sound.** The tables and patterns shipped in
  Sprint 25–25.5 (`item`, `stock_movement`, `stock_balance`, batch,
  warehouse, stock receipt) will support every feature below **without
  schema rewrites** — we only need *additive* schema for new concepts.
- **Feature surface is thin.** Sprint 25 covers the foundation, not the
  full module. A real inventory tool needs ~12 sub-features; we have 5.
- **Plan:** Sprints 26–30 (one feature family per sprint) bring us to
  100% parity while preserving the immutable-ledger backbone.

## Feature Comparison Matrix

| # | Zoho Feature | Current State | Gap | Target Sprint |
|---|---|---|---|---|
| 1 | Basic item + stock tracking | ✅ Shipped (S25) | None | — |
| 2 | Reorder levels + low-stock alert | ✅ Shipped (S25) | None | — |
| 3 | Batch tracking + expiry | ✅ Schema shipped (S25.5) | Need FEFO consumption, expiry alert job | **S26** |
| 4 | Damage / expired stock movement | ✅ `DAMAGE` movement type | No UI flow | **S26** |
| 5 | Single-item stock adjustment | ✅ Shipped (S25) | Bulk adjustment missing | **S27** |
| 6 | Physical stock count | ⚠️ Schema exists, flagged "skip" | Needs form + bulk commit | **S27** |
| 7 | Serial number tracking | ⚠️ `track_serial_numbers` flag only | No `serial_number` table / flow | **S27** |
| 8 | Barcode generation + scan | ❌ Missing | Label template engine + scanner | **S27** |
| 9 | Composite items (BOM) | ❌ Missing | New `composite_item_component` table | **S28** |
| 10 | Item variants / groups | ❌ Missing | New attribute / variant tables | **S28** |
| 11 | Price lists | ❌ Missing | New `price_list` + `price_list_item` tables | **S29** |
| 12 | Unit-of-measure conversion | ❌ Partial | New `uom` + `uom_conversion` tables | **S29** |
| 13 | Multi-warehouse + transfer orders | ⚠️ Schema exists, 1 warehouse in use | Transfer document + UI | **S30** |
| 14 | Picklist (warehouse pick) | ❌ Missing | New picklist entity | **S30** |
| 15 | Package / shipment tracking | ❌ Missing | Out of scope for v2 | v3 |
| 16 | Drop shipping | ❌ Missing | Out of scope for v2 | v3 |
| 17 | Backorder auto-PO | ❌ Missing | Needs procurement expansion | v3 |
| 18 | FIFO costing alongside WAC | ⚠️ Only WAC | Lot-level cost tracking on batches | **S29** (alongside UoM) |

## Revised Sprint Plan

| Sprint | Theme | Deliverables |
|---|---|---|
| **S25** *(done)* | Core inventory foundation | `item`, `stock_movement` ledger, `stock_balance` cache, invoice wiring, low-stock alerts, single-item adjust, dashboard widget |
| **S25.5** *(done)* | Procurement + catalog setup | Stock receipt (GRN), bulk item import from CSV, dual-input UI (paste + file picker) |
| **S25.6** *(in flight)* | Import preview | Dry-run preview endpoint, per-row verdicts, 3-step UI (Choose → Preview → Result) |
| **S26** | Batch-aware selling | Batch form on GRN, FEFO consumption on invoice, expiry alert job, damaged-stock UI |
| **S27** | Physical inventory & identity | Bulk stock count form, serial-number table + assignment flow, barcode scan on GRN/sale, label printing |
| **S28** | Product assembly & variants | Composite items (BOM), component auto-deduction on sale, item groups with size/colour variants |
| **S29** | Pricing & units | Price lists with customer default, UoM + conversion factors, optional FIFO costing per batch |
| **S30** | Warehouse operations | Multi-warehouse live, transfer orders, picklist generation for packing |

## Schema Sketches for Missing Features

All new tables follow existing conventions: `id UUID`, `org_id UUID`,
soft-delete via `is_deleted boolean`, audit timestamps, org-scoped
uniqueness.

### Composite Items / BOM (Sprint 28)

```sql
-- A composite item IS a row in `item` with item_type = 'COMPOSITE'.
-- The BOM lives in a separate table so one composite can have many lines.
CREATE TABLE composite_item_component (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id            UUID NOT NULL,
    composite_item_id UUID NOT NULL REFERENCES item(id),
    component_item_id UUID NOT NULL REFERENCES item(id),
    quantity          NUMERIC(18,4) NOT NULL CHECK (quantity > 0),
    uom_id            UUID REFERENCES uom(id),      -- optional; falls back to component's base uom
    is_deleted        BOOLEAN NOT NULL DEFAULT false,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT composite_component_unique UNIQUE (composite_item_id, component_item_id) WHERE is_deleted = false,
    CONSTRAINT composite_no_self_ref CHECK (composite_item_id <> component_item_id)
);

-- New item_type enum value
ALTER TABLE item ADD CONSTRAINT item_type_check
    CHECK (item_type IN ('GOODS', 'SERVICE', 'COMPOSITE'));
```

**Behaviour:** on invoice line insert, if the item is `COMPOSITE`, the
sales service explodes one movement per component through the existing
single-gate `InventoryService.recordMovement()`. The composite item
itself never gets a stock movement — its "stock" is derived from the
minimum buildable count across its components.

### Item Variants / Groups (Sprint 28)

```sql
-- Org-level attribute dictionary: "Size", "Colour", "Weight"
CREATE TABLE item_attribute (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id     UUID NOT NULL,
    name       VARCHAR(50) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT attribute_name_unique UNIQUE (org_id, name) WHERE is_deleted = false
);

-- Values per attribute: Size = {S, M, L, XL}
CREATE TABLE item_attribute_value (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attribute_id UUID NOT NULL REFERENCES item_attribute(id),
    value        VARCHAR(50) NOT NULL,
    sort_order   INT NOT NULL DEFAULT 0,
    is_deleted   BOOLEAN NOT NULL DEFAULT false
);

-- Group is a parent item (item.is_group = true). Variants are real items
-- with parent_item_id pointing at the group and a JSON attribute map.
ALTER TABLE item ADD COLUMN is_group BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE item ADD COLUMN parent_item_id UUID REFERENCES item(id);
ALTER TABLE item ADD COLUMN variant_attributes JSONB;  -- {"size":"M","colour":"Red"}
```

**Why this shape:** each variant is a first-class `item` row with its
own SKU, stock, and price. The group is a UI convenience for catalog
display and bulk create. Zoho uses the same pattern.

### Price Lists (Sprint 29)

```sql
CREATE TABLE price_list (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID NOT NULL,
    name        VARCHAR(100) NOT NULL,
    currency    VARCHAR(3) NOT NULL DEFAULT 'INR',
    is_default  BOOLEAN NOT NULL DEFAULT false,
    -- For margin-based lists instead of absolute prices:
    discount_pct NUMERIC(5,2),   -- e.g. 10.00 = 10% off item.sale_price
    is_deleted  BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE price_list_item (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    price_list_id UUID NOT NULL REFERENCES price_list(id),
    item_id      UUID NOT NULL REFERENCES item(id),
    price        NUMERIC(18,4) NOT NULL,
    min_quantity NUMERIC(18,4),   -- tiered pricing: "price when qty >= X"
    CONSTRAINT price_list_item_unique UNIQUE (price_list_id, item_id, min_quantity)
);

ALTER TABLE customer ADD COLUMN default_price_list_id UUID REFERENCES price_list(id);
```

**Resolution order** on invoice line: explicit override → customer's
`default_price_list_id` → org default price list → `item.sale_price`.

### UoM Conversion (Sprint 29)

```sql
CREATE TABLE uom (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    name          VARCHAR(50) NOT NULL,         -- "Kilogram"
    abbreviation  VARCHAR(20) NOT NULL,         -- "KG"
    category      VARCHAR(20) NOT NULL,         -- WEIGHT / VOLUME / COUNT / LENGTH
    is_base       BOOLEAN NOT NULL DEFAULT false,
    is_deleted    BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT uom_abbr_unique UNIQUE (org_id, abbreviation) WHERE is_deleted = false
);

-- Per-item conversion: "1 BOX of Paracetamol = 10 STRIP"
-- Stock is always stored in the item's base UoM; conversion happens at
-- I/O boundaries (receipt, sale, report display).
CREATE TABLE uom_conversion (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         UUID NOT NULL,
    item_id        UUID REFERENCES item(id),    -- NULL = org-wide (e.g. 1 KG = 1000 GM)
    from_uom_id    UUID NOT NULL REFERENCES uom(id),
    to_uom_id      UUID NOT NULL REFERENCES uom(id),
    factor         NUMERIC(18,6) NOT NULL CHECK (factor > 0),
    is_deleted     BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE item ADD COLUMN base_uom_id UUID REFERENCES uom(id);
ALTER TABLE item ADD COLUMN purchase_uom_id UUID REFERENCES uom(id);
ALTER TABLE item ADD COLUMN sale_uom_id UUID REFERENCES uom(id);
```

**Invariant:** every movement in `stock_movement` is recorded in the
item's `base_uom_id`. Purchase and sale UoMs are display-only; the
service layer converts at the boundary. This keeps balance math trivial.

### Bulk Stock Adjustment / Physical Count (Sprint 27)

The `stock_count` + `stock_count_line` tables are already sketched in
Sprint 25's plan but flagged "skip". Promote to Sprint 27:

```sql
-- Already exists in Sprint 25 plan — reconfirming shape:
CREATE TABLE stock_count (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         UUID NOT NULL,
    warehouse_id   UUID NOT NULL REFERENCES warehouse(id),
    count_date     DATE NOT NULL,
    status         VARCHAR(20) NOT NULL,   -- DRAFT / POSTED / CANCELLED
    reason         TEXT,
    counted_by     UUID,
    posted_at      TIMESTAMPTZ,
    posted_by      UUID,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE stock_count_line (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_count_id   UUID NOT NULL REFERENCES stock_count(id),
    item_id          UUID NOT NULL REFERENCES item(id),
    batch_id         UUID REFERENCES batch(id),
    system_quantity  NUMERIC(18,4) NOT NULL,   -- frozen at count start
    counted_quantity NUMERIC(18,4) NOT NULL,
    variance         NUMERIC(18,4) GENERATED ALWAYS AS (counted_quantity - system_quantity) STORED
);
```

**Post flow:** POSTING a stock_count walks every line and calls
`InventoryService.recordMovement()` with `MovementType.ADJUST_IN` or
`ADJUST_OUT` depending on variance sign. All adjustments happen in one
transaction; audit trail ties every movement back to the same
`stock_count_id` via the existing `reference_type / reference_id`
columns. Zero schema conflict with the immutable ledger.

### Serial Number Tracking (Sprint 27)

```sql
CREATE TABLE serial_number (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID NOT NULL,
    item_id       UUID NOT NULL REFERENCES item(id),
    serial        VARCHAR(100) NOT NULL,
    warehouse_id  UUID REFERENCES warehouse(id),
    status        VARCHAR(20) NOT NULL,   -- IN_STOCK / SOLD / DAMAGED / RETURNED
    received_at   TIMESTAMPTZ,
    sold_at       TIMESTAMPTZ,
    invoice_line_id UUID,                 -- nullable, set on sale
    receipt_line_id UUID,                 -- nullable, set on GRN
    CONSTRAINT serial_unique UNIQUE (org_id, item_id, serial)
);
```

**Interaction with ledger:** a serial number is not a stock movement
itself — it's a side-table pointer into which specific units moved on
a given line. Movement quantities remain the source of truth.

## Architectural Invariants (Preserved Through v2)

None of the v2 features break these:

1. **Single movement gate** — every stock-affecting operation, including
   BOM explosion, stock count posting, and variant sales, flows through
   `InventoryService.recordMovement()`.
2. **Immutable ledger** — `stock_movement` is append-only. Corrections
   use `REVERSE` entries, never UPDATE/DELETE.
3. **Derived balances** — `stock_balance` remains a projection; it can
   be rebuilt at any time from the ledger.
4. **Bitemporality** — `posted_date` vs `effective_date` stays intact;
   backdated adjustments remain safe.
5. **Tenant isolation** — every new table carries `org_id` and respects
   `TenantContext`.

## What to Build First

Recommended starting point for the next coding sprint: **Sprint 26
(Batch-aware selling + FEFO)** because:

- The batch schema already exists from Sprint 25.5 — no new tables
  needed, just service + UI wiring.
- It unblocks pharmacy and FMCG customers immediately (every Indian
  pharmacy needs batch + expiry or they can't legally sell).
- Small blast radius — touches the sales invoice line creator and
  adds one scheduled job.
- Sets up the data quality needed for Sprint 27's stock counting (you
  can only count what you can identify by batch).

Alternative, if retail is the pilot segment: jump to **Sprint 28
(Composite items + variants)** instead.

---

*See also:* `docs/architecture/` — additional design notes as features land.
