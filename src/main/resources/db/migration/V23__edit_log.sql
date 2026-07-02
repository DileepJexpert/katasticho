-- V23: Edit Log / audit trail (MCA account-rules audit trail; TallyPrime 6.1
-- "Edit Log" parity).
--
-- Append-only ledger of who created / altered / deleted books documents and
-- masters, with a field-level before/after diff for alterations. Rows are
-- written by a Hibernate post-event listener on the SAME JDBC connection and
-- transaction as the business write, so a rolled-back transaction takes its
-- log rows with it and a committed one is guaranteed to have them.
--
-- Deliberately no org_settings toggle and no soft-delete column: an audit
-- trail that can be switched off or edited is not an audit trail.

CREATE TABLE edit_log (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL,
    entity_type VARCHAR(40) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(10) NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'DELETE', 'RESTORE')),
    entity_label VARCHAR(255),
    field_changes JSONB,
    changed_by UUID,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Per-document history ("show me every alteration of this invoice").
CREATE INDEX idx_edit_log_org_entity
    ON edit_log (org_id, entity_type, entity_id, changed_at DESC);

-- Org-wide recent-activity feed and date-range queries.
CREATE INDEX idx_edit_log_org_time
    ON edit_log (org_id, changed_at DESC);

-- "What did this user change" queries.
CREATE INDEX idx_edit_log_org_user
    ON edit_log (org_id, changed_by, changed_at DESC);
