-- V66: Inter-Branch Stock In-Transit Tracking & Vehicle GPS Live Map
CREATE TABLE IF NOT EXISTS transfer_order_dispatch (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id) ON DELETE CASCADE,
    transfer_order_id UUID NOT NULL REFERENCES transfer_order(id) ON DELETE CASCADE,
    vehicle_number VARCHAR(50) NOT NULL,
    driver_name VARCHAR(100) NOT NULL,
    driver_phone VARCHAR(30),
    dispatched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expected_delivery_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    status VARCHAR(30) NOT NULL DEFAULT 'DISPATCHED', -- DISPATCHED, IN_TRANSIT, DELIVERED, CANCELLED
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    last_location_name VARCHAR(255),
    last_ping_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS transfer_order_transit_event (
    id UUID PRIMARY KEY,
    dispatch_id UUID NOT NULL REFERENCES transfer_order_dispatch(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL, -- DISPATCHED, CHECKPOINT, DELAY_ALERT, DELIVERED
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    location_name VARCHAR(255),
    event_notes TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transfer_dispatch_org ON transfer_order_dispatch(org_id, status) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_transfer_transit_dispatch ON transfer_order_transit_event(dispatch_id);
