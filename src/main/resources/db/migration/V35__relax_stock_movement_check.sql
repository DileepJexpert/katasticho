-- V35 — Drop the stale stock_movement.movement_type / reference_type CHECK constraints.
--
-- Mirrors the V34 precedent for journal_entry.source_module. The V1 baseline pinned
-- movement_type and reference_type to fixed vocabularies that the code has since
-- outgrown: the 5 manufacturing movement types (PRODUCTION_ISSUE, PRODUCTION_RECEIVE,
-- PRODUCTION_SCRAP, JOB_WORK_OUT, JOB_WORK_IN) and 6 newer reference types
-- (WORK_ORDER, JOB_WORK_ORDER, VAN_LOAD, VAN_UNLOAD, VAN_RETURN, TRANSFER_ORDER, ...)
-- all throw a CHECK violation on a real INSERT. They only "passed" because the
-- inventory movement gate is mocked in unit tests, so the constraints were never
-- exercised against the real schema.
--
-- These columns are set from Java enum constants (MovementType / ReferenceType), never
-- from user input, and are used only for reporting/filtering (idx_stock_movement_*).
-- The enum guard's sole net effect has been latent crashes for legitimate movements,
-- and the same drift recurs every time a new movement/reference type is added. Drop the
-- CHECKs; the columns stay movement_type VARCHAR(20) NOT NULL / reference_type VARCHAR(30)
-- (the longest current values fit: PRODUCTION_RECEIVE=17, TRANSFER_ORDER=14).

ALTER TABLE stock_movement DROP CONSTRAINT IF EXISTS stock_movement_movement_type_check;
ALTER TABLE stock_movement DROP CONSTRAINT IF EXISTS stock_movement_reference_type_check;
