-- ============================================================
-- V2: Authentication & RBAC tables
-- app_user, refresh_token, user_invitation, audit_log
-- ============================================================

-- App User: belongs to an organisation. Roles: OWNER, ACCOUNTANT, OPERATOR, VIEWER.
CREATE TABLE app_user (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organisation(id),
    email               VARCHAR(255),
    phone               VARCHAR(20),
    password_hash       VARCHAR(255),
    full_name           VARCHAR(255) NOT NULL,
    role                VARCHAR(20) NOT NULL DEFAULT 'VIEWER'
                        CHECK (role IN ('OWNER', 'ACCOUNTANT', 'OPERATOR', 'VIEWER')),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    failed_login_count  INTEGER NOT NULL DEFAULT 0,
    locked_until        TIMESTAMPTZ,
    last_login_at       TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uq_user_email_org UNIQUE (org_id, email),
    CONSTRAINT uq_user_phone_org UNIQUE (org_id, phone),
    CONSTRAINT chk_user_has_login CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX idx_user_org ON app_user (org_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_user_email ON app_user (email) WHERE email IS NOT NULL AND is_deleted = FALSE;
CREATE INDEX idx_user_phone ON app_user (phone) WHERE phone IS NOT NULL AND is_deleted = FALSE;


-- Refresh Token: for JWT refresh token rotation.
-- Old tokens are revoked when a new one is issued.
CREATE TABLE refresh_token (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES app_user(id),
    token_hash      VARCHAR(255) NOT NULL UNIQUE,
    device_info     VARCHAR(255),
    ip_address      VARCHAR(45),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_token_user ON refresh_token (user_id);
CREATE INDEX idx_refresh_token_hash ON refresh_token (token_hash) WHERE revoked_at IS NULL;


-- User Invitation: Owner invites new users with a pre-assigned role.
-- Token expires in 72 hours.
CREATE TABLE user_invitation (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organisation(id),
    email           VARCHAR(255),
    phone           VARCHAR(20),
    role            VARCHAR(20) NOT NULL DEFAULT 'VIEWER'
                    CHECK (role IN ('OWNER', 'ACCOUNTANT', 'OPERATOR', 'VIEWER')),
    token           VARCHAR(255) NOT NULL UNIQUE,
    invited_by      UUID NOT NULL REFERENCES app_user(id),
    expires_at      TIMESTAMPTZ NOT NULL,
    accepted_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_invite_has_contact CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX idx_invitation_token ON user_invitation (token) WHERE accepted_at IS NULL;
CREATE INDEX idx_invitation_org ON user_invitation (org_id);


-- Audit Log: tracks every data mutation with before/after JSON.
-- Owner and Accountant roles only can view this.
CREATE TABLE audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    user_id         UUID,
    entity_type     VARCHAR(50) NOT NULL,
    entity_id       UUID,
    action          VARCHAR(20) NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'DELETE')),
    before_json     JSONB,
    after_json      JSONB,
    ip_address      VARCHAR(45),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_org_entity ON audit_log (org_id, entity_type, created_at DESC);
CREATE INDEX idx_audit_org_user ON audit_log (org_id, user_id, created_at DESC);
