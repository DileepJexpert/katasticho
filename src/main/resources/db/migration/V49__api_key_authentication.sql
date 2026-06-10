-- V49: API key authentication
--
-- Per-org programmatic credentials so external agents (the Katasticho MCP
-- server, integrations, scripts) can call the API as the org — without a user
-- JWT. A key carries the org + an acting user (for role + audit). Only the
-- SHA-256 hash is stored; the plaintext key is shown once at creation.

CREATE TABLE api_key (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID NOT NULL,
    user_id      UUID NOT NULL,                 -- AppUser the key acts as (role + audit)
    name         VARCHAR(100) NOT NULL,         -- human label, e.g. "Claude Desktop"
    key_hash     VARCHAR(64) NOT NULL,          -- SHA-256 hex of the full key
    key_prefix   VARCHAR(16) NOT NULL,          -- first chars for display (kat_xxxxxxxx)
    last_used_at TIMESTAMPTZ,
    expires_at   TIMESTAMPTZ,                   -- NULL = never expires
    revoked_at   TIMESTAMPTZ,
    is_active    BOOLEAN NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by   UUID,
    is_deleted   BOOLEAN NOT NULL DEFAULT false
);

CREATE UNIQUE INDEX uq_api_key_hash ON api_key (key_hash);
CREATE INDEX idx_api_key_org ON api_key (org_id) WHERE is_deleted = false;
