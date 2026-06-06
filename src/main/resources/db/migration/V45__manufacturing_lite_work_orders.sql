-- V45: Manufacturing-Lite — work orders and production lines
-- Supports: work order lifecycle, raw material issue, finished goods receipt,
-- WIP tracking, production costing.

-- Work order: production request for a finished good from BOM
CREATE TABLE work_order (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                UUID          NOT NULL REFERENCES organisation(id),
    work_order_number     VARCHAR(30)   NOT NULL,
    finished_good_id      UUID          NOT NULL REFERENCES item(id),
    warehouse_id          UUID          NOT NULL REFERENCES warehouse(id),
    quantity_to_produce   NUMERIC(15,4) NOT NULL,
    quantity_produced     NUMERIC(15,4) NOT NULL DEFAULT 0,
    status                VARCHAR(20)   NOT NULL DEFAULT 'DRAFT',
    planned_start_date    DATE,
    planned_end_date      DATE,
    actual_start_date     DATE,
    actual_end_date       DATE,
    raw_material_cost     NUMERIC(15,2) NOT NULL DEFAULT 0,
    direct_labor_cost     NUMERIC(15,2) NOT NULL DEFAULT 0,
    overhead_cost         NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_cost            NUMERIC(15,2) NOT NULL DEFAULT 0,
    unit_cost             NUMERIC(15,4) NOT NULL DEFAULT 0,
    notes                 TEXT,
    is_deleted            BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by            UUID
);

-- Work order line: one BOM component's planned/issued quantities
CREATE TABLE work_order_line (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id            UUID          NOT NULL REFERENCES organisation(id),
    work_order_id     UUID          NOT NULL REFERENCES work_order(id),
    item_id           UUID          NOT NULL REFERENCES item(id),
    required_qty      NUMERIC(15,4) NOT NULL,
    issued_qty        NUMERIC(15,4) NOT NULL DEFAULT 0,
    unit_cost         NUMERIC(15,4) NOT NULL DEFAULT 0,
    line_cost         NUMERIC(15,2) NOT NULL DEFAULT 0,
    status            VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    is_deleted        BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_work_order_org ON work_order(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_work_order_status ON work_order(org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_work_order_fg ON work_order(org_id, finished_good_id) WHERE NOT is_deleted;
CREATE UNIQUE INDEX idx_work_order_number ON work_order(org_id, work_order_number) WHERE NOT is_deleted;
CREATE INDEX idx_work_order_line_wo ON work_order_line(work_order_id) WHERE NOT is_deleted;
CREATE INDEX idx_work_order_line_item ON work_order_line(org_id, item_id) WHERE NOT is_deleted;
