-- Add ADMIN role to app_user and user_invitation role constraints.
-- ADMIN sits between OWNER and ACCOUNTANT: full operational access,
-- cannot transfer ownership or manage billing.

ALTER TABLE app_user
    DROP CONSTRAINT IF EXISTS app_user_role_check;

ALTER TABLE app_user
    ADD CONSTRAINT app_user_role_check
        CHECK (role IN ('OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR', 'VIEWER'));

ALTER TABLE user_invitation
    DROP CONSTRAINT IF EXISTS user_invitation_role_check;

ALTER TABLE user_invitation
    ADD CONSTRAINT user_invitation_role_check
        CHECK (role IN ('OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR', 'VIEWER'));
