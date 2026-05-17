CREATE TABLE ai_model_run (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES organisation(id),
    task_type VARCHAR(80) NOT NULL,
    model_name VARCHAR(80) NOT NULL,
    model_version VARCHAR(50),
    provider VARCHAR(50),
    input_hash VARCHAR(128),
    input_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    output JSONB NOT NULL DEFAULT '{}'::jsonb,
    confidence NUMERIC(4, 3),
    latency_ms INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_model_run_org_task
    ON ai_model_run(org_id, task_type, created_at DESC);

CREATE TABLE ai_usage_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES organisation(id),
    feature VARCHAR(80) NOT NULL,
    provider VARCHAR(40),
    model VARCHAR(80),
    input_tokens INT,
    output_tokens INT,
    estimated_cost_usd NUMERIC(12, 6),
    entity_type VARCHAR(50),
    entity_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_usage_log_org_feature
    ON ai_usage_log(org_id, feature, created_at DESC);

CREATE TABLE ai_model_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_type VARCHAR(80) NOT NULL,
    model_name VARCHAR(80) NOT NULL,
    model_version VARCHAR(50),
    model_type VARCHAR(50) NOT NULL,
    model_uri TEXT,
    endpoint_url TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    accuracy NUMERIC(5, 4),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_model_registry_task_status
    ON ai_model_registry(task_type, status);

INSERT INTO ai_model_registry (
    task_type,
    model_name,
    model_version,
    model_type,
    status,
    accuracy
)
VALUES
    ('INVOICE_REVIEW', 'deterministic_rules', '1', 'RULE_ENGINE', 'ACTIVE', 1.0000),
    ('STOCK_REVIEW', 'deterministic_rules', '1', 'RULE_ENGINE', 'ACTIVE', 1.0000),
    ('PAYMENT_REVIEW', 'deterministic_rules', '1', 'RULE_ENGINE', 'ACTIVE', 1.0000)
ON CONFLICT DO NOTHING;
