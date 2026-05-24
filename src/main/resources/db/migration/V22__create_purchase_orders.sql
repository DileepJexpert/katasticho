-- V22: Purchase Orders module
-- Lifecycle: DRAFT → SENT → PARTIAL/RECEIVED → CANCELLED

CREATE TABLE purchase_orders (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                 UUID NOT NULL,
    supplier_id            UUID NOT NULL,
    po_number              VARCHAR(30) NOT NULL,
    status                 VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    order_date             DATE NOT NULL,
    expected_delivery_date DATE,
    notes                  TEXT,
    warehouse_id           UUID,
    total_amount           DECIMAL(19, 4) NOT NULL DEFAULT 0,
    is_deleted             BOOLEAN NOT NULL DEFAULT FALSE,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE purchase_order_lines (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    po_id             UUID NOT NULL REFERENCES purchase_orders (id) ON DELETE CASCADE,
    item_id           UUID NOT NULL,
    description       VARCHAR(500),
    quantity          DECIMAL(19, 4) NOT NULL,
    received_quantity DECIMAL(19, 4) NOT NULL DEFAULT 0,
    unit_price        DECIMAL(19, 4) NOT NULL DEFAULT 0,
    tax_group_id      UUID,
    line_total        DECIMAL(19, 4) NOT NULL DEFAULT 0
);

CREATE INDEX idx_po_org_status ON purchase_orders (org_id, status, is_deleted);
CREATE INDEX idx_po_org_created ON purchase_orders (org_id, created_at DESC) WHERE is_deleted = FALSE;
CREATE INDEX idx_po_lines_po_id ON purchase_order_lines (po_id);
