-- V60: Supply Chain Module
-- item_supplier, supplier_performance, demand_forecast, purchase_requisition,
-- return_order, abc_classification, supply_chain_alert, reorder_policy

-- ============================================================
-- 1. Item-Supplier mapping (multi-supplier per item)
-- ============================================================
CREATE TABLE item_supplier (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    item_id         UUID NOT NULL REFERENCES item(id),
    supplier_id     UUID NOT NULL REFERENCES supplier(id),
    lead_time_days  INT NOT NULL DEFAULT 7,
    min_order_qty   NUMERIC(15,4) NOT NULL DEFAULT 1,
    unit_price      NUMERIC(15,4) NOT NULL DEFAULT 0,
    is_preferred     BOOLEAN NOT NULL DEFAULT FALSE,
    supplier_sku    VARCHAR(50),
    notes           TEXT,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID,
    UNIQUE (org_id, item_id, supplier_id)
);

CREATE INDEX idx_item_supplier_org ON item_supplier(org_id);
CREATE INDEX idx_item_supplier_item ON item_supplier(org_id, item_id) WHERE NOT is_deleted;
CREATE INDEX idx_item_supplier_supplier ON item_supplier(org_id, supplier_id) WHERE NOT is_deleted;

-- ============================================================
-- 2. Supplier Performance tracking
-- ============================================================
CREATE TABLE supplier_performance (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    supplier_id         UUID NOT NULL REFERENCES supplier(id),
    period_start        DATE NOT NULL,
    period_end          DATE NOT NULL,
    total_orders        INT NOT NULL DEFAULT 0,
    on_time_deliveries  INT NOT NULL DEFAULT 0,
    late_deliveries     INT NOT NULL DEFAULT 0,
    total_qty_ordered   NUMERIC(15,4) NOT NULL DEFAULT 0,
    total_qty_received  NUMERIC(15,4) NOT NULL DEFAULT 0,
    total_qty_rejected  NUMERIC(15,4) NOT NULL DEFAULT 0,
    total_amount        NUMERIC(15,4) NOT NULL DEFAULT 0,
    avg_lead_time_days  NUMERIC(8,2) NOT NULL DEFAULT 0,
    on_time_rate        NUMERIC(5,2) NOT NULL DEFAULT 0,
    quality_rate        NUMERIC(5,2) NOT NULL DEFAULT 0,
    overall_score       NUMERIC(5,2) NOT NULL DEFAULT 0,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID,
    UNIQUE (org_id, supplier_id, period_start, period_end)
);

CREATE INDEX idx_supplier_perf_org ON supplier_performance(org_id);
CREATE INDEX idx_supplier_perf_supplier ON supplier_performance(org_id, supplier_id);

-- ============================================================
-- 3. Demand Forecast
-- ============================================================
CREATE TABLE demand_forecast (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    item_id         UUID NOT NULL REFERENCES item(id),
    warehouse_id    UUID REFERENCES warehouse(id),
    forecast_month  DATE NOT NULL,
    forecast_qty    NUMERIC(15,4) NOT NULL DEFAULT 0,
    actual_qty      NUMERIC(15,4),
    method          VARCHAR(30) NOT NULL DEFAULT 'MOVING_AVG',
    confidence      NUMERIC(5,2),
    notes           TEXT,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID,
    UNIQUE (org_id, item_id, warehouse_id, forecast_month)
);

CREATE INDEX idx_demand_forecast_org ON demand_forecast(org_id);
CREATE INDEX idx_demand_forecast_item ON demand_forecast(org_id, item_id) WHERE NOT is_deleted;
CREATE INDEX idx_demand_forecast_month ON demand_forecast(org_id, forecast_month);

-- ============================================================
-- 4. Purchase Requisition (approval before PO)
-- ============================================================
CREATE TABLE purchase_requisition (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    requisition_number  VARCHAR(30) NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    requested_by        UUID,
    approved_by         UUID,
    approved_at         TIMESTAMPTZ,
    required_by_date    DATE,
    supplier_id         UUID REFERENCES supplier(id),
    warehouse_id        UUID REFERENCES warehouse(id),
    total_amount        NUMERIC(15,4) NOT NULL DEFAULT 0,
    source              VARCHAR(30) NOT NULL DEFAULT 'MANUAL',
    purchase_order_id   UUID,
    notes               TEXT,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID,
    UNIQUE (org_id, requisition_number)
);

CREATE TABLE purchase_requisition_line (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL REFERENCES organisation(id),
    requisition_id          UUID NOT NULL REFERENCES purchase_requisition(id),
    item_id                 UUID NOT NULL REFERENCES item(id),
    required_qty            NUMERIC(15,4) NOT NULL,
    estimated_unit_price    NUMERIC(15,4) NOT NULL DEFAULT 0,
    estimated_line_total    NUMERIC(15,4) NOT NULL DEFAULT 0,
    notes                   TEXT,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_purchase_req_org ON purchase_requisition(org_id);
CREATE INDEX idx_purchase_req_status ON purchase_requisition(org_id, status) WHERE NOT is_deleted;

-- ============================================================
-- 5. Return Order (formal returns workflow)
-- ============================================================
CREATE TABLE return_order (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    return_number       VARCHAR(30) NOT NULL,
    return_type         VARCHAR(20) NOT NULL DEFAULT 'PURCHASE_RETURN',
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    contact_id          UUID,
    original_reference_id UUID,
    original_reference_type VARCHAR(30),
    warehouse_id        UUID REFERENCES warehouse(id),
    reason_code         VARCHAR(30),
    reason_notes        TEXT,
    total_amount        NUMERIC(15,4) NOT NULL DEFAULT 0,
    restock_fee         NUMERIC(15,4) NOT NULL DEFAULT 0,
    net_refund          NUMERIC(15,4) NOT NULL DEFAULT 0,
    approved_by         UUID,
    approved_at         TIMESTAMPTZ,
    notes               TEXT,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID,
    UNIQUE (org_id, return_number)
);

CREATE TABLE return_order_line (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    return_order_id UUID NOT NULL REFERENCES return_order(id),
    item_id         UUID NOT NULL REFERENCES item(id),
    batch_id        UUID,
    quantity        NUMERIC(15,4) NOT NULL,
    unit_price      NUMERIC(15,4) NOT NULL DEFAULT 0,
    line_total      NUMERIC(15,4) NOT NULL DEFAULT 0,
    condition       VARCHAR(20) NOT NULL DEFAULT 'GOOD',
    restock         BOOLEAN NOT NULL DEFAULT TRUE,
    notes           TEXT,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_return_order_org ON return_order(org_id);
CREATE INDEX idx_return_order_status ON return_order(org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_return_order_contact ON return_order(org_id, contact_id) WHERE NOT is_deleted;

-- ============================================================
-- 6. Reorder Policy (per-item supply chain settings)
-- ============================================================
CREATE TABLE reorder_policy (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    item_id             UUID NOT NULL REFERENCES item(id),
    warehouse_id        UUID REFERENCES warehouse(id),
    safety_stock        NUMERIC(15,4) NOT NULL DEFAULT 0,
    reorder_point       NUMERIC(15,4) NOT NULL DEFAULT 0,
    reorder_qty         NUMERIC(15,4) NOT NULL DEFAULT 0,
    max_stock           NUMERIC(15,4) NOT NULL DEFAULT 0,
    eoq                 NUMERIC(15,4) NOT NULL DEFAULT 0,
    lead_time_days      INT NOT NULL DEFAULT 7,
    service_level_pct   NUMERIC(5,2) NOT NULL DEFAULT 95.00,
    abc_class           VARCHAR(1),
    last_calculated     TIMESTAMPTZ,
    auto_reorder        BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID,
    UNIQUE (org_id, item_id, warehouse_id)
);

CREATE INDEX idx_reorder_policy_org ON reorder_policy(org_id);
CREATE INDEX idx_reorder_policy_item ON reorder_policy(org_id, item_id) WHERE NOT is_deleted;
CREATE INDEX idx_reorder_policy_abc ON reorder_policy(org_id, abc_class) WHERE NOT is_deleted;

-- ============================================================
-- 7. Supply Chain Alert
-- ============================================================
CREATE TABLE supply_chain_alert (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    alert_type      VARCHAR(30) NOT NULL,
    severity        VARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    item_id         UUID,
    supplier_id     UUID,
    warehouse_id    UUID,
    reference_id    UUID,
    reference_type  VARCHAR(30),
    status          VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    resolved_at     TIMESTAMPTZ,
    resolved_by     UUID,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID
);

CREATE INDEX idx_sc_alert_org ON supply_chain_alert(org_id);
CREATE INDEX idx_sc_alert_status ON supply_chain_alert(org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_sc_alert_type ON supply_chain_alert(org_id, alert_type) WHERE NOT is_deleted;

-- ============================================================
-- 8. Supplier lead_time_days + rating on supplier table
-- ============================================================
ALTER TABLE supplier ADD COLUMN IF NOT EXISTS lead_time_days INT NOT NULL DEFAULT 7;
ALTER TABLE supplier ADD COLUMN IF NOT EXISTS quality_rating NUMERIC(5,2) NOT NULL DEFAULT 0;
ALTER TABLE supplier ADD COLUMN IF NOT EXISTS delivery_rating NUMERIC(5,2) NOT NULL DEFAULT 0;
ALTER TABLE supplier ADD COLUMN IF NOT EXISTS overall_rating NUMERIC(5,2) NOT NULL DEFAULT 0;

-- ============================================================
-- 9. Indexes for supply chain analytics queries
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_stock_movement_item_date
    ON stock_movement(org_id, item_id, movement_date);
CREATE INDEX IF NOT EXISTS idx_stock_movement_type_date
    ON stock_movement(org_id, movement_type, movement_date);
