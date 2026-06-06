-- Picklist: warehouse picking document generated from a Sales Order.
-- Guides warehouse staff to pick items before creating a Delivery Challan.

CREATE TABLE picklist (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    picklist_number VARCHAR(30) NOT NULL,
    sales_order_id  UUID NOT NULL REFERENCES sales_order(id),
    warehouse_id    UUID NOT NULL REFERENCES warehouse(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','CANCELLED')),
    assigned_to     UUID,
    notes           TEXT,
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (org_id, picklist_number)
);

CREATE TABLE picklist_line (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    picklist_id           UUID NOT NULL REFERENCES picklist(id) ON DELETE CASCADE,
    sales_order_line_id   UUID NOT NULL REFERENCES sales_order_line(id),
    item_id               UUID NOT NULL REFERENCES item(id),
    required_quantity     NUMERIC(15,4) NOT NULL CHECK (required_quantity > 0),
    picked_quantity       NUMERIC(15,4) NOT NULL DEFAULT 0,
    batch_id              UUID REFERENCES stock_batch(id),
    rack_location_id      UUID REFERENCES rack_location(id),
    notes                 TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_picklist_org_deleted ON picklist(org_id, is_deleted);
CREATE INDEX idx_picklist_so ON picklist(sales_order_id);
CREATE INDEX idx_picklist_line_picklist ON picklist_line(picklist_id);
