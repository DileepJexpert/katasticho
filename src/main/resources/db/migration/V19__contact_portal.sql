-- ============================================================================
-- V19: Customer/Vendor self-service portal — external login accounts.
--
-- External parties (a Contact that is a CUSTOMER or VENDOR) get their own
-- email+password login to a self-service portal, separate from the app's
-- AppUser/JWT. Admin invites a contact -> the contact accepts the invite and
-- sets a password -> they log in to see their own invoices/outstanding/ledger
-- (customer) or POs/bills/payment status (vendor).
-- ============================================================================

CREATE TABLE public.portal_user (
    id                  uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id              uuid NOT NULL,
    contact_id          uuid NOT NULL,
    kind                character varying(20) NOT NULL,          -- CUSTOMER | VENDOR
    email               character varying(255) NOT NULL,
    full_name           character varying(255),
    password_hash       character varying(255),                  -- null until invite accepted
    status              character varying(20) DEFAULT 'INVITED' NOT NULL, -- INVITED|ACTIVE|SUSPENDED
    invite_token_hash   character varying(255),
    invite_expires_at   timestamp with time zone,
    last_login_at       timestamp with time zone,
    token_version       integer DEFAULT 0 NOT NULL,
    is_deleted          boolean DEFAULT false NOT NULL,
    created_at          timestamp with time zone DEFAULT now() NOT NULL,
    updated_at          timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT portal_user_pkey PRIMARY KEY (id)
);

-- One portal account per email (a person logs into one org's portal).
CREATE UNIQUE INDEX uq_portal_user_email
    ON public.portal_user (lower(email)) WHERE is_deleted = false;

-- One portal account per contact.
CREATE UNIQUE INDEX uq_portal_user_contact
    ON public.portal_user (org_id, contact_id) WHERE is_deleted = false;

CREATE INDEX idx_portal_user_org ON public.portal_user (org_id) WHERE is_deleted = false;
CREATE INDEX idx_portal_user_invite ON public.portal_user (invite_token_hash) WHERE is_deleted = false;
