-- ============================================================
-- V3: Cross-cutting systems — F6
--
-- Four tables used by EVERY module going forward:
--   entity_comment   — comments on any entity
--   entity_attachment — file attachments on any entity
--   email_template   — org-customisable email templates
--   notification     — in-app + multi-channel notifications
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Comments
-- ─────────────────────────────────────────────────────────────
CREATE TABLE entity_comment (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID          NOT NULL REFERENCES organisation(id),
    entity_type  VARCHAR(30)   NOT NULL,   -- INVOICE, BILL, CONTACT, EXPENSE …
    entity_id    UUID          NOT NULL,
    comment_text VARCHAR(2000) NOT NULL,
    is_system    BOOLEAN       NOT NULL DEFAULT FALSE,  -- auto-generated on status change
    is_deleted   BOOLEAN       NOT NULL DEFAULT FALSE,
    created_by   UUID REFERENCES app_user(id),
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_entity_comment_entity ON entity_comment(org_id, entity_type, entity_id)
    WHERE NOT is_deleted;
CREATE INDEX idx_entity_comment_user   ON entity_comment(created_by) WHERE created_by IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 2. Attachments
-- ─────────────────────────────────────────────────────────────
CREATE TABLE entity_attachment (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID         NOT NULL REFERENCES organisation(id),
    entity_type  VARCHAR(30)  NOT NULL,
    entity_id    UUID         NOT NULL,
    file_name    VARCHAR(255) NOT NULL,
    file_type    VARCHAR(100),               -- MIME type
    file_size    BIGINT,                     -- bytes
    file_url     VARCHAR(1000) NOT NULL,     -- local path or S3/R2 URL
    is_deleted   BOOLEAN      NOT NULL DEFAULT FALSE,
    uploaded_by  UUID REFERENCES app_user(id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_entity_attachment_entity ON entity_attachment(org_id, entity_type, entity_id)
    WHERE NOT is_deleted;


-- ─────────────────────────────────────────────────────────────
-- 3. Email templates
-- ─────────────────────────────────────────────────────────────
CREATE TABLE email_template (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID         NOT NULL REFERENCES organisation(id),
    template_type VARCHAR(30)  NOT NULL,  -- INVOICE_SENT, PAYMENT_RECEIVED …
    subject       VARCHAR(255) NOT NULL,
    body_html     TEXT         NOT NULL,
    is_default    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    UUID,
    CONSTRAINT uq_email_template_org_type UNIQUE (org_id, template_type)
);

CREATE INDEX idx_email_template_org ON email_template(org_id);


-- ─────────────────────────────────────────────────────────────
-- 4. Notifications
-- ─────────────────────────────────────────────────────────────
CREATE TABLE notification (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id      UUID        NOT NULL REFERENCES organisation(id),
    user_id     UUID REFERENCES app_user(id),  -- NULL = all users in org
    title       VARCHAR(255) NOT NULL,
    message     TEXT,
    severity    VARCHAR(10)  NOT NULL DEFAULT 'INFO'
                CHECK (severity IN ('INFO','WARNING','CRITICAL')),
    entity_type VARCHAR(30),
    entity_id   UUID,
    channel     VARCHAR(20)  NOT NULL DEFAULT 'IN_APP'
                CHECK (channel IN ('IN_APP','EMAIL','WHATSAPP','SMS','PUSH')),
    is_read     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_notification_user    ON notification(org_id, user_id, is_read)
    WHERE user_id IS NOT NULL;
CREATE INDEX idx_notification_org     ON notification(org_id, created_at DESC);
CREATE INDEX idx_notification_entity  ON notification(entity_type, entity_id)
    WHERE entity_type IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- 5. Seed system-wide default email templates
--    org_id = nil UUID — copied per org at signup.
--    Seeded here so the seed data travels with the migration.
-- ─────────────────────────────────────────────────────────────
-- (No org_id seed rows here — templates are created per-org at
--  organisation signup via OrganisationService.seedEmailTemplates())
