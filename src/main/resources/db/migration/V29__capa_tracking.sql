-- Tracker #88: CAPA (Corrective & Preventive Action) tracking.
--
-- Lifecycle layer on top of the existing non_conformance_report (NCR)
-- table. An NCR records that something went wrong; a CAPA records the
-- action taken (or planned) to fix it AND to prevent recurrence. Each
-- NCR can spawn one or many CAPA rows. A CAPA can also stand alone
-- (no ncr_id) for PREVENTIVE actions raised from a trend, audit
-- finding, customer complaint, etc.
--
-- ISO 9001 / 13485 (medical devices) / IATF 16949 (auto) all require
-- this layer. The DB-level CHECK constraints keep the enum surface
-- closed; the service layer handles transitions.

CREATE TABLE capa_action (
    id                  UUID PRIMARY KEY,
    org_id              UUID NOT NULL,
    is_deleted          BOOLEAN NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID,
    updated_by          UUID,

    capa_number         VARCHAR(30) NOT NULL,
    ncr_id              UUID,
    capa_type           VARCHAR(15) NOT NULL,
    title               VARCHAR(200) NOT NULL,
    description         TEXT,
    proposed_action     TEXT,
    assigned_to         UUID,
    due_date            DATE,
    priority            VARCHAR(10) NOT NULL DEFAULT 'NORMAL',
    status              VARCHAR(15) NOT NULL DEFAULT 'OPEN',

    completion_notes    TEXT,
    completed_at        TIMESTAMPTZ,
    completed_by        UUID,

    verified_at         TIMESTAMPTZ,
    verified_by         UUID,
    effectiveness_notes TEXT,

    CONSTRAINT capa_type_check
        CHECK (capa_type IN ('CORRECTIVE', 'PREVENTIVE')),
    CONSTRAINT capa_priority_check
        CHECK (priority IN ('URGENT', 'HIGH', 'NORMAL', 'LOW')),
    CONSTRAINT capa_status_check
        CHECK (status IN ('OPEN', 'IN_PROGRESS', 'COMPLETED', 'VERIFIED', 'CANCELLED')),

    CONSTRAINT capa_ncr_fk FOREIGN KEY (ncr_id)
        REFERENCES non_conformance_report (id)
);

-- Unique CAPA number per org (CAPA-YYYY-NNNNN style).
CREATE UNIQUE INDEX capa_number_org_uq
    ON capa_action (org_id, capa_number) WHERE is_deleted = false;

-- Common access patterns:
CREATE INDEX capa_org_open_idx
    ON capa_action (org_id, status)
    WHERE is_deleted = false AND status IN ('OPEN', 'IN_PROGRESS');

CREATE INDEX capa_org_due_idx
    ON capa_action (org_id, due_date)
    WHERE is_deleted = false AND status IN ('OPEN', 'IN_PROGRESS');

CREATE INDEX capa_org_assignee_idx
    ON capa_action (org_id, assigned_to)
    WHERE is_deleted = false;

CREATE INDEX capa_org_ncr_idx
    ON capa_action (org_id, ncr_id)
    WHERE is_deleted = false AND ncr_id IS NOT NULL;
