-- ============================================================================
-- V9: Seed a default warehouse for every existing organisation.
--
-- New organisations created after this migration get their default warehouse
-- via OrganisationService at signup time. This migration backfills any orgs
-- that already exist in the database.
-- ============================================================================

INSERT INTO warehouse (org_id, code, name, is_default, is_active, created_at, updated_at)
SELECT
    o.id,
    'MAIN',
    'Main Warehouse',
    TRUE,
    TRUE,
    now(),
    now()
FROM organisation o
WHERE NOT EXISTS (
    SELECT 1 FROM warehouse w
    WHERE w.org_id = o.id AND w.is_default = TRUE AND NOT w.is_deleted
);
