-- V67: Field location tracking
-- Live GPS breadcrumbs for field salespeople + geofence verification on visit check-in.

-- Append-only GPS ping trail. One row per ping; no soft delete.
CREATE TABLE field_location_ping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    route_execution_id UUID,
    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL,
    accuracy_m DECIMAL(8,2),
    recorded_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_flp_org_salesperson_time ON field_location_ping(org_id, salesperson_id, recorded_at DESC);
CREATE INDEX idx_flp_org_execution ON field_location_ping(org_id, route_execution_id);

-- Geofence verification result captured at check-in.
-- geo_verified is NULL when the beat customer has no stored coordinates.
ALTER TABLE field_visit ADD COLUMN geo_verified BOOLEAN;
ALTER TABLE field_visit ADD COLUMN geo_distance_m DECIMAL(10,2);
