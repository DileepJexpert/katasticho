-- V30 — User-configurable Workflow Rules (Zoho "workflow rules" / Odoo
-- "automated actions" parity). On a document event (rides the existing
-- domain_events bus — no new publish sites needed for the engine itself),
-- evaluate org-defined CRITERIA on the document's fields and run org-defined
-- ACTIONS: send email, POST a signed outgoing webhook, create an AI-inbox
-- suggestion, or update a whitelisted soft field.
--
-- New package com.katasticho.erp.workflow (distinct from common.workflow,
-- which is the approval engine).

CREATE TABLE workflow_rule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    entity_type VARCHAR(50) NOT NULL,        -- INVOICE / PURCHASE_BILL / PAYMENT / ...
    trigger_event VARCHAR(80) NOT NULL,      -- matches DomainEvent.eventType, e.g. INVOICE_POSTED
    match_type VARCHAR(3) NOT NULL DEFAULT 'ALL' CHECK (match_type IN ('ALL', 'ANY')),
    criteria JSONB NOT NULL DEFAULT '[]',    -- [{field, operator, value}]
    actions JSONB NOT NULL DEFAULT '[]',     -- [{type: EMAIL|WEBHOOK|FIELD_UPDATE|AI_SUGGESTION, config:{}}]
    active BOOLEAN NOT NULL DEFAULT false,   -- seed inactive, like approval workflows
    run_order INTEGER NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
-- The dispatch lookup: active rules for a given (org, entity, trigger).
CREATE INDEX idx_workflow_rule_dispatch
    ON workflow_rule (org_id, entity_type, trigger_event)
    WHERE active AND NOT is_deleted;
CREATE INDEX idx_workflow_rule_org ON workflow_rule (org_id) WHERE NOT is_deleted;

CREATE TABLE workflow_rule_execution (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    rule_id UUID NOT NULL,
    event_id UUID,                           -- the DomainEvent.id (dedupe key)
    entity_type VARCHAR(50),
    entity_id UUID,
    matched BOOLEAN NOT NULL DEFAULT false,
    status VARCHAR(20) NOT NULL,             -- MATCHED / NO_MATCH / ACTION_FAILED / SKIPPED
    actions_run INTEGER NOT NULL DEFAULT 0,
    detail JSONB,                            -- per-action results
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);
-- Idempotency backstop for the at-least-once bus: one execution per (rule, event).
CREATE UNIQUE INDEX uq_workflow_rule_execution
    ON workflow_rule_execution (org_id, rule_id, event_id)
    WHERE event_id IS NOT NULL AND NOT is_deleted;
CREATE INDEX idx_workflow_rule_execution_log
    ON workflow_rule_execution (org_id, rule_id, created_at DESC)
    WHERE NOT is_deleted;
