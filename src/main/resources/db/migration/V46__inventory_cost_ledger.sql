-- Immutable cost ledger for landed cost and manufacturing conversion costs.
-- Stock movements remain the source of quantity and valuation; these tables
-- explain how a movement's cost was built and provide an audit trail.

CREATE TABLE IF NOT EXISTS inventory_cost_event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    event_number VARCHAR(30) NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    source_type VARCHAR(40) NOT NULL,
    source_id UUID NOT NULL,
    source_number VARCHAR(60),
    warehouse_id UUID,
    total_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    allocation_basis VARCHAR(30) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'POSTED',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT uq_inventory_cost_event_number UNIQUE (org_id, event_number),
    CONSTRAINT ck_inventory_cost_event_amount CHECK (total_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_inventory_cost_event_source
    ON inventory_cost_event (org_id, source_type, source_id, created_at);

CREATE TABLE IF NOT EXISTS inventory_cost_component (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    event_id UUID NOT NULL REFERENCES inventory_cost_event(id),
    component_type VARCHAR(40) NOT NULL,
    description VARCHAR(250),
    amount NUMERIC(15,2) NOT NULL,
    source_type VARCHAR(40),
    source_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT ck_inventory_cost_component_amount CHECK (amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_inventory_cost_component_event
    ON inventory_cost_component (org_id, event_id);

CREATE TABLE IF NOT EXISTS inventory_cost_allocation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    event_id UUID NOT NULL REFERENCES inventory_cost_event(id),
    stock_movement_id UUID NOT NULL,
    item_id UUID NOT NULL,
    batch_id UUID,
    quantity NUMERIC(15,4) NOT NULL,
    allocated_amount NUMERIC(15,2) NOT NULL,
    unit_cost_addition NUMERIC(15,6) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT ck_inventory_cost_allocation_quantity CHECK (quantity > 0),
    CONSTRAINT ck_inventory_cost_allocation_amount CHECK (allocated_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_inventory_cost_allocation_movement
    ON inventory_cost_allocation (org_id, stock_movement_id);

CREATE INDEX IF NOT EXISTS idx_inventory_cost_allocation_batch
    ON inventory_cost_allocation (org_id, batch_id)
    WHERE batch_id IS NOT NULL;
