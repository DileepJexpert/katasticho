-- V38 — Make the bom_component unique index version-aware.
--
-- createBomVersion snapshots the current BOM into a new `version` and keeps the
-- old rows live (they are the history that getBomVersion / diffBomVersions read).
-- But the V1 index idx_bom_component_unique is on (parent_item_id, child_item_id)
-- WHERE NOT is_deleted — it has no `version` column, so a second live version
-- carrying the same child would violate it. Recreate the index including
-- `version` so multiple live versions of a BOM can coexist as history.
--
-- (The companion service fix routes every "current BOM" reader through a
-- MAX(version) query so consumers only ever see the latest version's rows,
-- while version-specific readers keep seeing history.)

DROP INDEX IF EXISTS idx_bom_component_unique;
CREATE UNIQUE INDEX idx_bom_component_unique
    ON bom_component (parent_item_id, child_item_id, version)
    WHERE (NOT is_deleted);
