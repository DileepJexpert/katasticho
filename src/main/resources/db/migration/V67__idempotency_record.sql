-- V67: Idempotency records for external command APIs.
-- Service callers (e.g. the Katixo hospital service) send an Idempotency-Key
-- header on commands that create invoices/receipts/payments. A retried request
-- with the same key replays the original response instead of double-creating.
CREATE TABLE idempotency_record (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID         NOT NULL,
    idempotency_key VARCHAR(200) NOT NULL,
    request_method  VARCHAR(10)  NOT NULL,
    request_path    VARCHAR(300) NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'IN_PROGRESS',
    response_status INTEGER,
    response_body   TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    CONSTRAINT uq_idempotency_org_key UNIQUE (org_id, idempotency_key)
);

CREATE INDEX idx_idempotency_expiry ON idempotency_record(expires_at);
