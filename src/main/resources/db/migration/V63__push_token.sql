-- V62: Push notification device token registry
-- Stores FCM / APNS / Web-Push registration tokens per user device.
-- Actual FCM dispatch is a stub until Firebase Admin SDK is integrated.

CREATE TABLE push_token (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID        NOT NULL,
    user_id      UUID        NOT NULL,
    device_token TEXT        NOT NULL,
    platform     VARCHAR(10) NOT NULL DEFAULT 'ANDROID',   -- ANDROID | IOS | WEB
    is_active    BOOLEAN     NOT NULL DEFAULT true,
    is_deleted   BOOLEAN     NOT NULL DEFAULT false,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by   UUID,

    CONSTRAINT uk_push_token_org_device UNIQUE (org_id, device_token)
);

CREATE INDEX idx_push_token_org_user
    ON push_token(org_id, user_id)
    WHERE NOT is_deleted;

CREATE INDEX idx_push_token_org_active
    ON push_token(org_id, is_active)
    WHERE NOT is_deleted;
