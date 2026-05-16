CREATE TABLE org_ai_settings (
    org_id       UUID PRIMARY KEY,
    provider     VARCHAR(20)  NOT NULL DEFAULT 'CLAUDE',
    model_name   VARCHAR(100) NOT NULL DEFAULT 'claude-sonnet-4-20250514',
    base_url     VARCHAR(255),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_by   UUID,
    CONSTRAINT org_ai_settings_provider_check CHECK (provider IN ('CLAUDE','OLLAMA'))
);
