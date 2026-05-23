ALTER TABLE organisation
    ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) NOT NULL DEFAULT 'APPROVED',
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_by UUID,
    ADD COLUMN IF NOT EXISTS approval_note VARCHAR(255);

ALTER TABLE organisation
    DROP CONSTRAINT IF EXISTS organisation_approval_status_check;

ALTER TABLE organisation
    ADD CONSTRAINT organisation_approval_status_check
        CHECK (approval_status IN ('PENDING','APPROVED','REJECTED'));

UPDATE organisation
SET approval_status = 'APPROVED'
WHERE approval_status IS NULL;

ALTER TABLE app_user
    DROP CONSTRAINT IF EXISTS app_user_role_check;

ALTER TABLE app_user
    ADD CONSTRAINT app_user_role_check
        CHECK (role IN ('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER',
                        'CA_EXTERNAL','CA_PARTNER','CA_STAFF','PLATFORM_ADMIN'));

ALTER TABLE user_invitation
    DROP CONSTRAINT IF EXISTS user_invitation_role_check;

ALTER TABLE user_invitation
    ADD CONSTRAINT user_invitation_role_check
        CHECK (role IN ('OWNER','ADMIN','ACCOUNTANT','OPERATOR','VIEWER',
                        'CA_EXTERNAL','CA_PARTNER','CA_STAFF','PLATFORM_ADMIN'));

CREATE INDEX IF NOT EXISTS idx_org_approval_status
    ON organisation(approval_status, created_at DESC)
    WHERE is_deleted = false;
