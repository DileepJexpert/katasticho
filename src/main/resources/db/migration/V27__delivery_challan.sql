-- ─────────────────────────────────────────────────────────────
-- Delivery Challan (dispatch document for goods issue / PGI)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE delivery_challan (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL REFERENCES organisation(id),
    branch_id               UUID REFERENCES branch(id),
    challan_number          VARCHAR(30) NOT NULL,
    sales_order_id          UUID NOT NULL REFERENCES sales_order(id),
    contact_id              UUID NOT NULL REFERENCES contact(id),
    challan_date            DATE NOT NULL,
    status                  VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT','DISPATCHED','DELIVERED','CANCELLED')),
    dispatch_date           DATE,
    warehouse_id            UUID REFERENCES warehouse(id),
    delivery_method         VARCHAR(50),
    vehicle_number          VARCHAR(30),
    tracking_number         VARCHAR(100),
    notes                   VARCHAR(2000),
    shipping_address        JSONB,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID REFERENCES app_user(id),
    UNIQUE(org_id, challan_number)
);

CREATE TABLE delivery_challan_line (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_challan_id     UUID NOT NULL REFERENCES delivery_challan(id) ON DELETE CASCADE,
    sales_order_line_id     UUID NOT NULL REFERENCES sales_order_line(id),
    line_number             INT NOT NULL,
    item_id                 UUID REFERENCES item(id),
    description             VARCHAR(500),
    quantity                NUMERIC(12,4) NOT NULL,
    unit                    VARCHAR(20),
    batch_id                UUID,
    UNIQUE(delivery_challan_id, line_number)
);

-- Add challan count tracking to sales_order for fast response mapping
-- (avoid count query on every SO detail fetch)

CREATE INDEX idx_delivery_challan_org ON delivery_challan(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_delivery_challan_so ON delivery_challan(sales_order_id) WHERE NOT is_deleted;
CREATE INDEX idx_delivery_challan_contact ON delivery_challan(org_id, contact_id) WHERE NOT is_deleted;
CREATE INDEX idx_delivery_challan_status ON delivery_challan(org_id, status) WHERE NOT is_deleted;
