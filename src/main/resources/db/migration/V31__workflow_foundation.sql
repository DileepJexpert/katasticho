CREATE TABLE IF NOT EXISTS document_state_config (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id),
    document_type VARCHAR(50) NOT NULL,
    from_state VARCHAR(30) NOT NULL,
    to_state VARCHAR(30) NOT NULL,
    allowed_roles TEXT[] NOT NULL,
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uk_document_state_config_transition
        UNIQUE (org_id, document_type, from_state, to_state)
);

CREATE TABLE IF NOT EXISTS workflow_definition (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id),
    code VARCHAR(80) NOT NULL,
    name VARCHAR(160) NOT NULL,
    document_type VARCHAR(80) NOT NULL,
    trigger_condition JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uk_workflow_definition_code UNIQUE (org_id, code)
);

CREATE TABLE IF NOT EXISTS workflow_step (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id),
    workflow_definition_id UUID NOT NULL REFERENCES workflow_definition(id) ON DELETE CASCADE,
    step_number SMALLINT NOT NULL,
    approver_role VARCHAR(40),
    approver_user_id UUID REFERENCES app_user(id),
    timeout_hours SMALLINT NOT NULL DEFAULT 24,
    on_timeout VARCHAR(20) NOT NULL DEFAULT 'ESCALATE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uk_workflow_step_order UNIQUE (workflow_definition_id, step_number)
);

CREATE TABLE IF NOT EXISTS approval_request (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id),
    workflow_id UUID REFERENCES workflow_definition(id),
    document_type VARCHAR(80) NOT NULL,
    document_id UUID NOT NULL,
    current_step SMALLINT NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    requested_by UUID REFERENCES app_user(id),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    trigger_reason TEXT,
    context_json JSONB,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS approval_decision (
    id UUID PRIMARY KEY,
    org_id UUID NOT NULL REFERENCES organisation(id),
    approval_request_id UUID NOT NULL REFERENCES approval_request(id) ON DELETE CASCADE,
    step_number SMALLINT NOT NULL,
    decision VARCHAR(20) NOT NULL,
    note TEXT,
    decided_by UUID NOT NULL REFERENCES app_user(id),
    decided_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_document_state_config_org
    ON document_state_config(org_id, document_type)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_workflow_definition_org_doc
    ON workflow_definition(org_id, document_type)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_approval_request_org_status
    ON approval_request(org_id, status)
    WHERE is_deleted = FALSE;

CREATE INDEX IF NOT EXISTS idx_approval_request_document
    ON approval_request(org_id, document_type, document_id)
    WHERE is_deleted = FALSE;
