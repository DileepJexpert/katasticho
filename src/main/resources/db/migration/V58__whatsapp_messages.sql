-- WhatsApp document send log. One row per attempt to send a document
-- (invoice / receipt / reminder / statement) over the WhatsApp Business API.
-- Settings live in org_settings (whatsapp.* keys); only the send history is
-- a real table so the UI can show what went out and any provider errors.

CREATE TABLE whatsapp_message (
    id                  UUID PRIMARY KEY,
    org_id              UUID NOT NULL,
    recipient           VARCHAR(20) NOT NULL,      -- E.164 without '+', e.g. 919876543210
    doc_type            VARCHAR(20) NOT NULL,      -- INVOICE / RECEIPT / REMINDER / STATEMENT
    doc_id              UUID,                       -- invoice/receipt/contact id (nullable)
    template_name       VARCHAR(120),
    status              VARCHAR(20) NOT NULL,      -- SENT / FAILED / SKIPPED
    provider            VARCHAR(20),               -- META / CUSTOM
    provider_message_id VARCHAR(120),
    error_message       TEXT,
    sent_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_whatsapp_message_org ON whatsapp_message(org_id, created_at DESC);
CREATE INDEX idx_whatsapp_message_doc ON whatsapp_message(org_id, doc_type, doc_id);
