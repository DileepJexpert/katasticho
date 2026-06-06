-- Serial number tracking (Sprint 27)
ALTER TABLE item ADD COLUMN IF NOT EXISTS track_serial_numbers BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE serial_number (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    item_id         UUID NOT NULL REFERENCES item(id),
    serial          VARCHAR(100) NOT NULL,
    warehouse_id    UUID REFERENCES warehouse(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'IN_STOCK'
                    CHECK (status IN ('IN_STOCK','SOLD','DAMAGED','RETURNED','RESERVED')),
    batch_id        UUID REFERENCES stock_batch(id),
    received_at     TIMESTAMPTZ,
    sold_at         TIMESTAMPTZ,
    receipt_line_id UUID,
    invoice_line_id UUID,
    notes           TEXT,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID,
    CONSTRAINT uq_serial_number UNIQUE (org_id, item_id, serial)
);

CREATE INDEX idx_serial_number_org_item ON serial_number(org_id, item_id) WHERE NOT is_deleted;
CREATE INDEX idx_serial_number_status ON serial_number(org_id, status) WHERE NOT is_deleted;
CREATE INDEX idx_serial_number_warehouse ON serial_number(org_id, warehouse_id, status) WHERE NOT is_deleted;

-- Transfer orders (Sprint 30)
CREATE TABLE transfer_order (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    transfer_number     VARCHAR(30) NOT NULL,
    from_warehouse_id   UUID NOT NULL REFERENCES warehouse(id),
    to_warehouse_id     UUID NOT NULL REFERENCES warehouse(id),
    transfer_date       DATE NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
                        CHECK (status IN ('DRAFT','IN_TRANSIT','RECEIVED','CANCELLED')),
    notes               TEXT,
    shipped_at          TIMESTAMPTZ,
    shipped_by          UUID,
    received_at         TIMESTAMPTZ,
    received_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    CONSTRAINT uq_transfer_order_number UNIQUE (org_id, transfer_number),
    CONSTRAINT chk_transfer_order_warehouses CHECK (from_warehouse_id <> to_warehouse_id)
);

CREATE INDEX idx_transfer_order_org ON transfer_order(org_id, status) WHERE NOT is_deleted;

CREATE TABLE transfer_order_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_order_id   UUID NOT NULL REFERENCES transfer_order(id) ON DELETE CASCADE,
    item_id             UUID NOT NULL REFERENCES item(id),
    batch_id            UUID REFERENCES stock_batch(id),
    quantity            NUMERIC(15,4) NOT NULL CHECK (quantity > 0),
    received_quantity   NUMERIC(15,4) NOT NULL DEFAULT 0,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transfer_order_line_order ON transfer_order_line(transfer_order_id);
