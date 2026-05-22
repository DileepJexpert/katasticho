ALTER TABLE app_user
    ADD COLUMN IF NOT EXISTS ca_firm_id UUID;

ALTER TABLE app_user
    DROP CONSTRAINT IF EXISTS app_user_role_check;

ALTER TABLE app_user
    ADD CONSTRAINT app_user_role_check
        CHECK (role IN ('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER',
                        'CA_EXTERNAL','CA_PARTNER','CA_STAFF'));

ALTER TABLE user_invitation
    DROP CONSTRAINT IF EXISTS user_invitation_role_check;

ALTER TABLE user_invitation
    ADD CONSTRAINT user_invitation_role_check
        CHECK (role IN ('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER',
                        'CA_EXTERNAL','CA_PARTNER','CA_STAFF'));

CREATE TABLE IF NOT EXISTS ca_firm (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    firm_name VARCHAR(255) NOT NULL,
    icai_number VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id)
);

ALTER TABLE app_user
    ADD CONSTRAINT fk_app_user_ca_firm
        FOREIGN KEY (ca_firm_id) REFERENCES ca_firm(id);

CREATE TABLE IF NOT EXISTS ca_client_link (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ca_firm_id UUID NOT NULL REFERENCES ca_firm(id),
    client_org_id UUID NOT NULL REFERENCES organisation(id),
    assigned_user_id UUID REFERENCES app_user(id),
    backup_user_id UUID REFERENCES app_user(id),
    engagement_type VARCHAR(50) NOT NULL DEFAULT 'FULL_SERVICE',
    engagement_start DATE NOT NULL DEFAULT CURRENT_DATE,
    engagement_end DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE','PAUSED','ENDED')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES app_user(id),
    UNIQUE(ca_firm_id, client_org_id)
);

CREATE INDEX IF NOT EXISTS idx_ca_client_link_firm_status
    ON ca_client_link(ca_firm_id, status);

CREATE INDEX IF NOT EXISTS idx_ca_client_link_client_status
    ON ca_client_link(client_org_id, status);

CREATE INDEX IF NOT EXISTS idx_ca_client_link_assigned
    ON ca_client_link(assigned_user_id, backup_user_id);

CREATE TABLE IF NOT EXISTS ca_compliance_deadline (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ca_client_link_id UUID NOT NULL REFERENCES ca_client_link(id),
    client_org_id UUID NOT NULL REFERENCES organisation(id),
    deadline_type VARCHAR(50) NOT NULL,
    period_label VARCHAR(20) NOT NULL,
    due_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','FILED','OVERDUE','NOT_APPLICABLE')),
    filed_at TIMESTAMPTZ,
    filed_by UUID REFERENCES app_user(id),
    filing_reference VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(ca_client_link_id, deadline_type, period_label)
);

CREATE INDEX IF NOT EXISTS idx_ca_deadline_client_due
    ON ca_compliance_deadline(client_org_id, due_date);

CREATE INDEX IF NOT EXISTS idx_ca_deadline_link_status_due
    ON ca_compliance_deadline(ca_client_link_id, status, due_date);

CREATE TABLE IF NOT EXISTS ca_report_dispatch (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ca_client_link_id UUID REFERENCES ca_client_link(id),
    client_org_id UUID REFERENCES organisation(id),
    dispatched_by UUID REFERENCES app_user(id),
    period_label VARCHAR(20) NOT NULL,
    report_types JSONB NOT NULL DEFAULT '[]',
    sent_via VARCHAR(20) NOT NULL DEFAULT 'EMAIL'
        CHECK (sent_via IN ('EMAIL','WHATSAPP','BOTH')),
    sent_to_email VARCHAR(255),
    sent_to_phone VARCHAR(20),
    ai_commentary BOOLEAN NOT NULL DEFAULT false,
    report_urls JSONB NOT NULL DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'QUEUED'
        CHECK (status IN ('QUEUED','SENT','FAILED')),
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ca_report_dispatch_client_created
    ON ca_report_dispatch(client_org_id, created_at DESC);

CREATE TABLE IF NOT EXISTS delegated_access_token (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ca_user_id UUID NOT NULL REFERENCES app_user(id),
    client_org_id UUID NOT NULL REFERENCES organisation(id),
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used BOOLEAN NOT NULL DEFAULT false,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delegated_access_user_client
    ON delegated_access_token(ca_user_id, client_org_id, expires_at DESC);

CREATE TABLE IF NOT EXISTS ca_alert_dismissal (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ca_firm_id UUID NOT NULL REFERENCES ca_firm(id),
    suggestion_id UUID NOT NULL REFERENCES ai_suggestion(id),
    dismissed_by UUID NOT NULL REFERENCES app_user(id),
    assigned_user_id UUID REFERENCES app_user(id),
    dismissed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(ca_firm_id, suggestion_id)
);

CREATE INDEX IF NOT EXISTS idx_ca_alert_dismissal_firm
    ON ca_alert_dismissal(ca_firm_id, suggestion_id);

INSERT INTO org_feature_flag (org_id, feature, is_enabled, created_at, updated_at)
SELECT id, 'CA_CONSOLE', false, NOW(), NOW()
FROM organisation
WHERE is_deleted = false
ON CONFLICT (org_id, feature) DO NOTHING;
