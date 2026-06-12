-- V70: Relaxed TA/DA claiming — salesperson-adjusted distance with GPS reference
-- The claimed km can differ from the GPS-tracked km (personal detours,
-- missed tracking). Both are stored so approvers can compare.
ALTER TABLE field_allowance_claim ADD COLUMN gps_distance_km NUMERIC(10,2) NOT NULL DEFAULT 0;

-- Backfill: existing claims were GPS-exact
UPDATE field_allowance_claim SET gps_distance_km = distance_km;
