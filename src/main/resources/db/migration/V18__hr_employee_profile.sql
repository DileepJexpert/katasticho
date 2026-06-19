-- ============================================================================
-- V18: HR portal — Employee profile depth. Module 2 of Core HR.
--
-- Self-service personal details that complement the payroll Employee master
-- (which already holds designation/department/DOJ/bank/statutory ids). One row
-- per app user; editable by the employee or HR.
-- ============================================================================

CREATE TABLE public.hr_employee_profile (
    id                         uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id                     uuid NOT NULL,
    user_id                    uuid NOT NULL,
    date_of_birth              date,
    gender                     character varying(20),
    blood_group                character varying(8),
    marital_status             character varying(20),
    personal_email             character varying(255),
    personal_phone             character varying(20),
    current_address            text,
    emergency_contact_name     character varying(120),
    emergency_contact_phone    character varying(20),
    emergency_contact_relation character varying(40),
    is_deleted                 boolean DEFAULT false NOT NULL,
    created_at                 timestamp with time zone DEFAULT now() NOT NULL,
    updated_at                 timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_employee_profile_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_hr_employee_profile_user
    ON public.hr_employee_profile (org_id, user_id) WHERE is_deleted = false;
