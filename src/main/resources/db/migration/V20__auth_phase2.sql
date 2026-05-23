-- Add new columns to app_user
ALTER TABLE app_user
  ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS login_method VARCHAR(10) NOT NULL DEFAULT 'PHONE';

-- Set login_method for existing users
UPDATE app_user SET login_method = 'EMAIL' WHERE email IS NOT NULL AND phone IS NULL;
UPDATE app_user SET login_method = 'BOTH'  WHERE email IS NOT NULL AND phone IS NOT NULL;
-- Mark existing users as email_verified (they were already in the system)
UPDATE app_user SET email_verified = true WHERE email IS NOT NULL;

-- Add SUSPENDED to organisation approval_status constraint
ALTER TABLE organisation DROP CONSTRAINT IF EXISTS organisation_approval_status_check;
ALTER TABLE organisation ADD CONSTRAINT organisation_approval_status_check
    CHECK (approval_status IN ('PENDING','APPROVED','REJECTED','SUSPENDED'));
ALTER TABLE organisation ADD COLUMN IF NOT EXISTS suspended_reason TEXT;

-- Rename approval_note to rejection_reason if it exists; or add rejection_reason
-- V19 added approval_note, spec wants rejection_reason for rejected orgs
-- We'll keep both for now; add rejection_reason as a separate column
ALTER TABLE organisation ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- password_reset_token table
CREATE TABLE IF NOT EXISTS password_reset_token (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES app_user(id),
  token_hash      VARCHAR(128) NOT NULL,
  delivery_method VARCHAR(10) NOT NULL DEFAULT 'EMAIL',
  delivered_to    VARCHAR(255) NOT NULL,
  expires_at      TIMESTAMPTZ NOT NULL,
  used            BOOLEAN NOT NULL DEFAULT false,
  used_at         TIMESTAMPTZ,
  ip_address      VARCHAR(45),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_prt_user_used ON password_reset_token(user_id, used);

-- email_verification_token table
CREATE TABLE IF NOT EXISTS email_verification_token (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES app_user(id),
  token_hash  VARCHAR(128) NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  used        BOOLEAN NOT NULL DEFAULT false,
  used_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_evt_user_used ON email_verification_token(user_id, used);

-- platform_admin table (completely separate from app_user)
CREATE TABLE IF NOT EXISTS platform_admin (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name           VARCHAR(255) NOT NULL,
  email               VARCHAR(255) UNIQUE NOT NULL,
  password_hash       VARCHAR(255) NOT NULL,
  role                VARCHAR(30) NOT NULL DEFAULT 'PLATFORM_ADMIN',
  token_version       INTEGER NOT NULL DEFAULT 0,
  is_active           BOOLEAN NOT NULL DEFAULT true,
  failed_login_count  INTEGER NOT NULL DEFAULT 0,
  locked_until        TIMESTAMPTZ,
  last_login_at       TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- platform_admin_audit table
CREATE TABLE IF NOT EXISTS platform_admin_audit (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform_admin_id   UUID NOT NULL REFERENCES platform_admin(id),
  action_type         VARCHAR(50) NOT NULL,
  target_type         VARCHAR(20),
  target_id           UUID,
  target_name         VARCHAR(255),
  reason              TEXT,
  ip_address          VARCHAR(45),
  performed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pa_audit_admin  ON platform_admin_audit(platform_admin_id);
CREATE INDEX IF NOT EXISTS idx_pa_audit_target ON platform_admin_audit(target_type, target_id);
