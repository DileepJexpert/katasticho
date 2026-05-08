CREATE TABLE IF NOT EXISTS ai_suggestion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    entity_line_id UUID,
    suggestion_type VARCHAR(50) NOT NULL,
    suggested_action VARCHAR(80),
    suggested_value JSONB NOT NULL DEFAULT '{}',
    reasoning TEXT,
    confidence NUMERIC(4, 3),
    agent_name VARCHAR(50),
    model_name VARCHAR(80),
    model_version VARCHAR(50),
    prompt_version VARCHAR(50),
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    reviewed_by UUID REFERENCES app_user(id),
    reviewed_at TIMESTAMP,
    review_action VARCHAR(50),
    reviewed_value JSONB,
    correction_reason TEXT,
    priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    priority_score NUMERIC(8, 3) NOT NULL DEFAULT 0,
    due_by TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_suggestion_inbox
    ON ai_suggestion (org_id, status, priority_score DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_suggestion_entity
    ON ai_suggestion (org_id, entity_type, entity_id);

CREATE TABLE IF NOT EXISTS domain_event (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    event_type VARCHAR(80) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    before_state JSONB,
    after_state JSONB,
    actor_type VARCHAR(30) NOT NULL,
    actor_id VARCHAR(100),
    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMP,
    processing_error TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_domain_event_pending
    ON domain_event (org_id, processed, created_at);

CREATE INDEX IF NOT EXISTS idx_domain_event_entity
    ON domain_event (org_id, entity_type, entity_id);

CREATE TABLE IF NOT EXISTS ai_pattern (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    pattern_type VARCHAR(50) NOT NULL,
    pattern_key JSONB NOT NULL,
    predicted_result JSONB NOT NULL,
    confidence NUMERIC(4, 3) NOT NULL DEFAULT 0.500,
    match_count INT NOT NULL DEFAULT 0,
    accepted_count INT NOT NULL DEFAULT 0,
    rejected_count INT NOT NULL DEFAULT 0,
    corrected_count INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    last_matched_at TIMESTAMP,
    last_corrected_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_pattern_lookup
    ON ai_pattern (org_id, pattern_type, status);

CREATE TABLE IF NOT EXISTS ai_training_example (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES organisation(id),
    source_suggestion_id UUID REFERENCES ai_suggestion(id),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    input_snapshot JSONB NOT NULL,
    ai_output JSONB,
    human_output JSONB NOT NULL,
    correction_type VARCHAR(30),
    correction_reason TEXT,
    created_by UUID REFERENCES app_user(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_training_example_task
    ON ai_training_example (org_id, task_type, created_at DESC);
