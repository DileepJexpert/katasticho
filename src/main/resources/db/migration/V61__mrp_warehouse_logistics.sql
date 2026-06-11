-- V61: MRP Engine + Warehouse Zones + Shipments + Batch Traceability
-- Next migration after V60 (Supply Chain)

-- ── MRP Run ──────────────────────────────────────────────────────────────────
CREATE TABLE mrp_run (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    run_date        DATE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'RUNNING',
    horizon_days    INT NOT NULL DEFAULT 90,
    notes           TEXT,
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE INDEX idx_mrp_run_org_status ON mrp_run(org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_mrp_run_org_date   ON mrp_run(org_id, run_date DESC) WHERE NOT is_deleted;

-- ── MRP Demand ────────────────────────────────────────────────────────────────
CREATE TABLE mrp_demand (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    mrp_run_id      UUID NOT NULL REFERENCES mrp_run(id),
    item_id         UUID NOT NULL,
    warehouse_id    UUID,
    source_type     VARCHAR(30) NOT NULL,   -- SALES_ORDER | FORECAST | MRP_EXPLOSION
    source_id       UUID,
    required_date   DATE NOT NULL,
    required_qty    NUMERIC(18,4) NOT NULL,
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mrp_demand_run     ON mrp_demand(mrp_run_id) WHERE NOT is_deleted;
CREATE INDEX idx_mrp_demand_item    ON mrp_demand(org_id, item_id) WHERE NOT is_deleted;

-- ── MRP Supply ────────────────────────────────────────────────────────────────
CREATE TABLE mrp_supply (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    mrp_run_id      UUID NOT NULL REFERENCES mrp_run(id),
    item_id         UUID NOT NULL,
    warehouse_id    UUID,
    supply_type     VARCHAR(30) NOT NULL,   -- ON_HAND | PURCHASE_ORDER | WORK_ORDER
    supply_id       UUID,
    available_date  DATE NOT NULL,
    available_qty   NUMERIC(18,4) NOT NULL,
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_mrp_supply_run     ON mrp_supply(mrp_run_id) WHERE NOT is_deleted;
CREATE INDEX idx_mrp_supply_item    ON mrp_supply(org_id, item_id) WHERE NOT is_deleted;

-- ── Planned Order ────────────────────────────────────────────────────────────
CREATE TABLE planned_order (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL,
    mrp_run_id          UUID NOT NULL REFERENCES mrp_run(id),
    item_id             UUID NOT NULL,
    warehouse_id        UUID,
    order_type          VARCHAR(20) NOT NULL,   -- PURCHASE | PRODUCTION
    planned_qty         NUMERIC(18,4) NOT NULL,
    planned_start_date  DATE,
    planned_end_date    DATE,
    lead_time_days      INT NOT NULL DEFAULT 7,
    supplier_id         UUID,
    status              VARCHAR(20) NOT NULL DEFAULT 'PLANNED',
    purchase_order_id   UUID,
    work_order_id       UUID,
    notes               TEXT,
    is_deleted          BOOLEAN NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID
);

CREATE INDEX idx_planned_order_run      ON planned_order(mrp_run_id) WHERE NOT is_deleted;
CREATE INDEX idx_planned_order_item     ON planned_order(org_id, item_id) WHERE NOT is_deleted;
CREATE INDEX idx_planned_order_status   ON planned_order(org_id, status) WHERE NOT is_deleted;

-- ── Warehouse Zone ────────────────────────────────────────────────────────────
CREATE TABLE warehouse_zone (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL,
    warehouse_id            UUID NOT NULL,
    code                    VARCHAR(20) NOT NULL,
    name                    VARCHAR(200) NOT NULL,
    zone_type               VARCHAR(20) NOT NULL DEFAULT 'STORAGE',  -- STORAGE|QUARANTINE|STAGING|CROSS_DOCK|RETURNS
    capacity                NUMERIC(18,4),
    current_utilization     NUMERIC(18,4) NOT NULL DEFAULT 0,
    temperature_controlled  BOOLEAN NOT NULL DEFAULT false,
    notes                   TEXT,
    is_deleted              BOOLEAN NOT NULL DEFAULT false,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID,
    CONSTRAINT uq_warehouse_zone_code UNIQUE (org_id, warehouse_id, code)
);

CREATE INDEX idx_warehouse_zone_wh ON warehouse_zone(org_id, warehouse_id) WHERE NOT is_deleted;

-- ── Shipment ─────────────────────────────────────────────────────────────────
CREATE TABLE shipment (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL,
    shipment_number         VARCHAR(30) NOT NULL,
    shipment_type           VARCHAR(20) NOT NULL,   -- OUTBOUND | INBOUND | TRANSFER
    status                  VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    origin_warehouse_id     UUID,
    destination_warehouse_id UUID,
    carrier                 VARCHAR(100),
    tracking_number         VARCHAR(100),
    vehicle_number          VARCHAR(30),
    estimated_departure     TIMESTAMPTZ,
    actual_departure        TIMESTAMPTZ,
    estimated_arrival       TIMESTAMPTZ,
    actual_arrival          TIMESTAMPTZ,
    total_weight            NUMERIC(18,4),
    total_packages          INT,
    freight_cost            NUMERIC(18,2) NOT NULL DEFAULT 0,
    notes                   TEXT,
    is_deleted              BOOLEAN NOT NULL DEFAULT false,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID,
    CONSTRAINT uq_shipment_number UNIQUE (org_id, shipment_number)
);

CREATE INDEX idx_shipment_org_status ON shipment(org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_shipment_org_type   ON shipment(org_id, shipment_type) WHERE NOT is_deleted;

-- ── Shipment Line ─────────────────────────────────────────────────────────────
CREATE TABLE shipment_line (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    shipment_id     UUID NOT NULL REFERENCES shipment(id),
    reference_type  VARCHAR(30),    -- SALES_ORDER | PURCHASE_ORDER | TRANSFER_ORDER
    reference_id    UUID,
    item_id         UUID NOT NULL,
    quantity        NUMERIC(18,4) NOT NULL,
    weight          NUMERIC(18,4),
    packages        INT NOT NULL DEFAULT 1,
    notes           TEXT,
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_shipment_line_shipment ON shipment_line(shipment_id) WHERE NOT is_deleted;
CREATE INDEX idx_shipment_line_item     ON shipment_line(org_id, item_id) WHERE NOT is_deleted;

-- ── Batch Trace ───────────────────────────────────────────────────────────────
CREATE TABLE batch_trace (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    batch_id        UUID NOT NULL,
    item_id         UUID NOT NULL,
    trace_type      VARCHAR(20) NOT NULL,   -- FORWARD | BACKWARD
    source_batch_id UUID,
    source_item_id  UUID,
    work_order_id   UUID,
    movement_id     UUID,
    quantity        NUMERIC(18,4),
    traced_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_batch_trace_batch      ON batch_trace(org_id, batch_id) WHERE NOT is_deleted;
CREATE INDEX idx_batch_trace_source     ON batch_trace(org_id, source_batch_id) WHERE NOT is_deleted;
CREATE INDEX idx_batch_trace_work_order ON batch_trace(work_order_id) WHERE NOT is_deleted;
