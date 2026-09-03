-- V64: Multi-Step Warehouse Putaway & Staging Optimization
CREATE TABLE IF NOT EXISTS warehouse_putaway_task (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    task_number VARCHAR(50) NOT NULL,
    goods_receipt_id UUID REFERENCES stock_receipt(id) ON DELETE SET NULL,
    warehouse_id UUID NOT NULL REFERENCES warehouse(id) ON DELETE CASCADE,
    source_location VARCHAR(100) NOT NULL DEFAULT 'RECEIVING_DOCK',
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING', -- PENDING, IN_PROGRESS, COMPLETED, CANCELLED
    assigned_to UUID,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_putaway_task_no UNIQUE (org_id, task_number)
);

CREATE TABLE IF NOT EXISTS warehouse_putaway_line (
    id UUID PRIMARY KEY,
    putaway_task_id UUID NOT NULL REFERENCES warehouse_putaway_task(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES item(id) ON DELETE RESTRICT,
    batch_number VARCHAR(100),
    quantity NUMERIC(15, 4) NOT NULL,
    suggested_rack_id UUID REFERENCES rack_location(id) ON DELETE SET NULL,
    confirmed_rack_id UUID REFERENCES rack_location(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING', -- PENDING, CONFIRMED, SKIPPED
    confirmed_at TIMESTAMPTZ,
    confirmed_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_putaway_task_org ON warehouse_putaway_task(org_id, status) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_putaway_line_task ON warehouse_putaway_line(putaway_task_id);
