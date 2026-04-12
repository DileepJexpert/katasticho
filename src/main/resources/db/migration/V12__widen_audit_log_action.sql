-- V12: Drop the narrow CHECK constraint on audit_log.action.
--
-- The V2 constraint only allowed ('CREATE','UPDATE','DELETE'), but many
-- services legitimately log richer action verbs — SEND, CANCEL, RECEIVE,
-- REVERSE, ISSUE, BULK_IMPORT, etc. The DB is the wrong place to enforce
-- a closed enum here: services keep adding verbs and every one of them
-- would need a migration. Enum validation lives in application code.
--
-- We keep the NOT NULL + VARCHAR(20) shape so the column still rejects
-- garbage, just without the hard-coded verb list.

ALTER TABLE audit_log DROP CONSTRAINT IF EXISTS audit_log_action_check;
